#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const { parseArgs, requireFirebaseApp } = require('./manage_firestore');

const DEFAULT_FIXTURE = path.resolve(__dirname, 'demo_accounts.json');

function usage() {
  console.log(`
LexiGuard Demo Accounts Seeder

Commands:
  setup            Create or refresh the demo accounts defined in demo_accounts.json.
  teardown --yes   Delete the demo accounts (Auth + Firestore docs).
  set-reviewer <email>
                   Grant {reviewer: true} custom claim to the given Auth user.

Optional flags:
  --service-account <path/to/service-account.json>
  --project <projectId>
  --fixture <path/to/demo_accounts.json>   (defaults to ./demo_accounts.json)

Per-account password overrides (env vars):
  LEXIGUARD_DEMO_PASSWORD_LAWYER_PENINSULAR
  LEXIGUARD_DEMO_PASSWORD_LAWYER_SABAH
  LEXIGUARD_DEMO_PASSWORD_REVIEWER

Examples:
  node seed_demo_users.js setup
  node seed_demo_users.js teardown --yes
  node seed_demo_users.js set-reviewer demo.reviewer@lexiguard.dev
`);
}

function loadFixture(args) {
  const fixturePath = args.fixture
    ? path.resolve(process.cwd(), args.fixture)
    : DEFAULT_FIXTURE;

  if (!fs.existsSync(fixturePath)) {
    throw new Error(`Demo fixture not found: ${fixturePath}`);
  }

  const raw = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
  if (!Array.isArray(raw.accounts)) {
    throw new Error(
      `Demo fixture must contain an "accounts" array. Got: ${typeof raw.accounts}`
    );
  }
  return raw.accounts;
}

function resolvePassword(account) {
  const envKey = `LEXIGUARD_DEMO_PASSWORD_${account.key.toUpperCase()}`;
  return process.env[envKey] || account.password;
}

async function ensureAuthUser(account) {
  const password = resolvePassword(account);
  if (!password) {
    throw new Error(`No password resolved for account ${account.key}.`);
  }

  try {
    const existing = await admin.auth().getUserByEmail(account.email);
    // Refresh password + displayName each setup so the documented credentials work.
    await admin.auth().updateUser(existing.uid, {
      password,
      displayName: account.displayName,
    });
    return { uid: existing.uid, created: false };
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
    const created = await admin.auth().createUser({
      email: account.email,
      password,
      displayName: account.displayName,
    });
    return { uid: created.uid, created: true };
  }
}

async function applyCustomClaims(uid, customClaims) {
  if (!customClaims || Object.keys(customClaims).length === 0) {
    // Clear any prior claims so toggling between accounts is predictable.
    await admin.auth().setCustomUserClaims(uid, {});
    return;
  }
  await admin.auth().setCustomUserClaims(uid, customClaims);
}

async function writeUserDoc(db, uid, account) {
  const now = new Date().toISOString();
  const payload = {
    id: uid,
    email: account.email,
    role: account.role,
    createdAt: now,
    updatedAt: now,
    ...(account.profile || {}),
  };

  await db.collection('users').doc(uid).set(payload, { merge: true });
}

async function writeLawyerProfileDoc(db, uid, account) {
  if (account.role !== 'lawyer') return;

  const now = new Date().toISOString();
  const profile = account.profile || {};
  const payload = {
    uid,
    legalFullName: profile.legalFullName,
    firmName: profile.firmName,
    jurisdiction: profile.jurisdiction,
    practiceState: profile.practiceState,
    practiceCity: profile.practiceCity,
    barOrRollNumber: profile.barNumber,
    verificationStatus: profile.verificationStatus,
    verificationProvider: profile.verificationProvider,
    verificationBadgeVisible: profile.verificationBadgeVisible,
    createdAt: now,
    updatedAt: now,
  };

  await db.collection('lawyer_profiles').doc(uid).set(payload, { merge: true });
}

async function writeVerificationRequestDoc(db, uid, account) {
  if (!account.verificationRequest) return;

  const now = new Date().toISOString();
  const profile = account.profile || {};
  const payload = {
    uid,
    queueStatus: account.verificationRequest.queueStatus,
    queueReason: account.verificationRequest.queueReason,
    requestType: account.verificationRequest.requestType || 'lawyer_registration',
    legalFullName: profile.legalFullName,
    firmName: profile.firmName,
    jurisdiction: profile.jurisdiction,
    practiceState: profile.practiceState,
    practiceCity: profile.practiceCity,
    barOrRollNumber: profile.barNumber,
    verificationStatus: profile.verificationStatus,
    verificationProvider: profile.verificationProvider,
    createdAt: now,
    updatedAt: now,
  };

  await db
    .collection('verification_requests')
    .doc(uid)
    .set(payload, { merge: true });
}

async function setupAccounts(db, accounts) {
  const summary = [];
  for (const account of accounts) {
    const { uid, created } = await ensureAuthUser(account);
    await applyCustomClaims(uid, account.customClaims);
    await writeUserDoc(db, uid, account);
    await writeLawyerProfileDoc(db, uid, account);
    await writeVerificationRequestDoc(db, uid, account);

    summary.push({
      key: account.key,
      email: account.email,
      uid,
      created,
      role: account.role,
      customClaims: account.customClaims || {},
    });
  }

  console.log('Demo accounts ready:');
  console.table(summary);
  console.log(
    '\nReviewer custom claims propagate on next ID-token refresh. ' +
      'Sign out + sign back in (or call user.getIdToken(true)) before opening the Reviewer Console.'
  );
}

async function teardownAccounts(db, accounts) {
  for (const account of accounts) {
    try {
      const existing = await admin.auth().getUserByEmail(account.email);
      await admin.auth().deleteUser(existing.uid);
      await Promise.all([
        db.collection('users').doc(existing.uid).delete().catch(() => {}),
        db.collection('lawyer_profiles').doc(existing.uid).delete().catch(() => {}),
        db
          .collection('verification_requests')
          .doc(existing.uid)
          .delete()
          .catch(() => {}),
      ]);
      console.log(`Removed ${account.email} (${existing.uid})`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log(`Skip ${account.email} — not found`);
        continue;
      }
      throw error;
    }
  }
}

async function setReviewer(email) {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { reviewer: true });
  console.log(
    `Granted reviewer claim to ${email} (${user.uid}). ` +
      `User must refresh their ID token to see the change.`
  );
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0];

  if (!command || command === 'help' || command === '--help') {
    usage();
    return;
  }

  const { db, projectId } = requireFirebaseApp(args);
  console.log(`Using project: ${projectId}`);

  switch (command) {
    case 'setup': {
      const accounts = loadFixture(args);
      await setupAccounts(db, accounts);
      break;
    }

    case 'teardown': {
      if (!args.yes) {
        throw new Error(
          'Refusing destructive action without --yes. Usage: teardown --yes'
        );
      }
      const accounts = loadFixture(args);
      await teardownAccounts(db, accounts);
      break;
    }

    case 'set-reviewer': {
      const email = args._[1];
      if (!email) {
        throw new Error('Usage: set-reviewer <email>');
      }
      await setReviewer(email);
      break;
    }

    default:
      throw new Error(`Unknown command: ${command}`);
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
