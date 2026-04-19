#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DEFAULT_PROJECT_ID = 'lexiguard-32c63';
const DEFAULT_COLLECTIONS = ['users', 'lawyer_profiles'];

function parseArgs(argv) {
  const parsed = { _: [] };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];

    if (!token.startsWith('--')) {
      parsed._.push(token);
      continue;
    }

    const key = token.replace(/^--/, '');
    const next = argv[i + 1];

    if (!next || next.startsWith('--')) {
      parsed[key] = true;
      continue;
    }

    parsed[key] = next;
    i += 1;
  }

  return parsed;
}

function resolveServiceAccountPath(args) {
  if (args['service-account']) {
    return path.resolve(process.cwd(), args['service-account']);
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    return path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
  }

  return path.resolve(__dirname, 'service-account.json');
}

function resolveCollections(args) {
  if (!args.collections) {
    return DEFAULT_COLLECTIONS;
  }

  return String(args.collections)
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

function usage() {
  console.log(`
LexiGuard Firestore Admin Tool

Commands:
  fetch-user <uid>
  fetch-doc <collection> <docId>
  fetch-url <firebase-console-document-url>
  backup [--collections users,lawyer_profiles]
  flush [--collections users,lawyer_profiles] --yes
  seed [--seed-file ./seed_data.json]
  flush-and-seed [--seed-file ./seed_data.json] [--collections users,lawyer_profiles] --yes

Optional flags:
  --project <projectId>
  --service-account <path/to/service-account.json>

Environment variables (alternative to flags):
  FIREBASE_PROJECT_ID
  FIREBASE_SERVICE_ACCOUNT_PATH

Examples:
  node manage_firestore.js fetch-user Te3yhlORsacZPloz8E2k1hHuzmq1
  node manage_firestore.js fetch-doc users Te3yhlORsacZPloz8E2k1hHuzmq1
  node manage_firestore.js fetch-url https://console.firebase.google.com/.../data/~2Fusers~2FTe3yhlORsacZPloz8E2k1hHuzmq1
  node manage_firestore.js backup
  node manage_firestore.js flush --yes
  node manage_firestore.js flush-and-seed --seed-file ./seed_data.json --yes
`);
}

function parseConsoleUrlToPath(consoleUrl) {
  if (typeof consoleUrl !== 'string' || !consoleUrl.trim()) {
    throw new Error('Console URL is empty.');
  }

  let url;

  try {
    url = new URL(consoleUrl);
  } catch (_error) {
    throw new Error('Invalid URL. Paste the full Firebase Console document URL.');
  }

  const marker = '/data/';
  const index = url.pathname.indexOf(marker);
  if (index < 0) {
    throw new Error('URL does not look like a Firestore Data tab document URL.');
  }

  const encodedPath = decodeURIComponent(url.pathname.slice(index + marker.length));
  const rawPath = encodedPath.replace(/~2F/gi, '/').replace(/^\/+/, '');

  const segments = rawPath.split('/').filter(Boolean);
  if (segments.length < 2 || segments.length % 2 !== 0) {
    throw new Error(
      `Parsed document path is invalid: '${rawPath}'. Expected even number of path segments.`
    );
  }

  const collection = segments[segments.length - 2];
  const docId = segments[segments.length - 1];
  const documentPath = `${collection}/${docId}`;

  return { collection, docId, documentPath };
}

function requireFirebaseApp(args) {
  const serviceAccountPath = resolveServiceAccountPath(args);

  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(
      `Service account file not found at: ${serviceAccountPath}\n` +
        `Create one in Firebase Console > Project settings > Service accounts ` +
        `and save it as tools/firestore_admin/service-account.json ` +
        `or pass --service-account <path>.`
    );
  }

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  const projectId =
    args.project ||
    process.env.FIREBASE_PROJECT_ID ||
    serviceAccount.project_id ||
    DEFAULT_PROJECT_ID;

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
  }

  return { db: admin.firestore(), projectId };
}

async function fetchDoc(db, collection, docId) {
  const snap = await db.collection(collection).doc(docId).get();

  if (!snap.exists) {
    console.error(`Document not found: ${collection}/${docId}`);
    process.exitCode = 2;
    return;
  }

  console.log(
    JSON.stringify(
      {
        path: `${collection}/${docId}`,
        data: snap.data(),
      },
      null,
      2
    )
  );
}

async function backupCollections(db, collections, projectId) {
  const backup = {
    projectId: projectId,
    exportedAt: new Date().toISOString(),
    collections: {},
  };

  for (const collectionName of collections) {
    const snapshot = await db.collection(collectionName).get();
    backup.collections[collectionName] = snapshot.docs.map((doc) => ({
      id: doc.id,
      data: doc.data(),
    }));
  }

  const backupsDir = path.resolve(__dirname, 'backups');
  fs.mkdirSync(backupsDir, { recursive: true });

  const filename = `firestore-backup-${new Date()
    .toISOString()
    .replace(/[:.]/g, '-')}.json`;
  const outputPath = path.join(backupsDir, filename);

  fs.writeFileSync(outputPath, JSON.stringify(backup, null, 2));
  console.log(`Backup created: ${outputPath}`);

  return outputPath;
}

async function flushCollections(db, collections) {
  for (const collectionName of collections) {
    const snapshot = await db.collection(collectionName).get();

    if (snapshot.empty) {
      console.log(`Collection already empty: ${collectionName}`);
      continue;
    }

    console.log(`Deleting ${snapshot.size} docs from ${collectionName}...`);

    let batch = db.batch();
    let count = 0;

    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      count += 1;

      if (count % 400 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }

    await batch.commit();
    console.log(`Deleted ${snapshot.size} docs from ${collectionName}`);
  }
}

function normalizeSeedData(seedRaw) {
  const normalized = {};

  for (const [collection, docs] of Object.entries(seedRaw)) {
    if (!Array.isArray(docs)) {
      throw new Error(`Seed collection '${collection}' must be an array.`);
    }

    normalized[collection] = docs.map((doc) => {
      if (!doc.id || typeof doc.id !== 'string') {
        throw new Error(
          `Each seeded doc in collection '${collection}' must include a string 'id'.`
        );
      }

      const { id, ...data } = doc;
      return { id, data };
    });
  }

  return normalized;
}

async function seedCollections(db, seedFile) {
  if (!fs.existsSync(seedFile)) {
    throw new Error(`Seed file not found: ${seedFile}`);
  }

  const raw = JSON.parse(fs.readFileSync(seedFile, 'utf8'));
  const normalized = normalizeSeedData(raw);

  for (const [collectionName, docs] of Object.entries(normalized)) {
    if (!docs.length) {
      console.log(`No docs to seed for ${collectionName}`);
      continue;
    }

    console.log(`Seeding ${docs.length} docs into ${collectionName}...`);

    let batch = db.batch();
    let count = 0;

    for (const doc of docs) {
      const ref = db.collection(collectionName).doc(doc.id);
      batch.set(ref, doc.data, { merge: false });
      count += 1;

      if (count % 400 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }

    await batch.commit();
    console.log(`Seeded ${docs.length} docs into ${collectionName}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0];

  if (!command || command === 'help' || command === '--help') {
    usage();
    return;
  }

  const { db, projectId } = requireFirebaseApp(args);
  const collections = resolveCollections(args);

  console.log(`Using project: ${projectId}`);

  switch (command) {
    case 'fetch-user': {
      const uid = args._[1];
      if (!uid) {
        throw new Error('Missing uid. Usage: fetch-user <uid>');
      }
      await fetchDoc(db, 'users', uid);
      break;
    }

    case 'fetch-doc': {
      const collection = args._[1];
      const docId = args._[2];
      if (!collection || !docId) {
        throw new Error('Usage: fetch-doc <collection> <docId>');
      }
      await fetchDoc(db, collection, docId);
      break;
    }

    case 'fetch-url': {
      const consoleUrl = args._[1];
      if (!consoleUrl) {
        throw new Error('Usage: fetch-url <firebase-console-document-url>');
      }

      const parsed = parseConsoleUrlToPath(consoleUrl);
      console.log(`Resolved URL path to: ${parsed.documentPath}`);
      await fetchDoc(db, parsed.collection, parsed.docId);
      break;
    }

    case 'backup': {
      await backupCollections(db, collections, projectId);
      break;
    }

    case 'flush': {
      if (!args.yes) {
        throw new Error(
          'Refusing destructive action without --yes. Usage: flush --yes'
        );
      }

      await backupCollections(db, collections, projectId);
      await flushCollections(db, collections);
      break;
    }

    case 'seed': {
      const seedFile = path.resolve(
        process.cwd(),
        args['seed-file'] || './seed_data.json'
      );
      await seedCollections(db, seedFile);
      break;
    }

    case 'flush-and-seed': {
      if (!args.yes) {
        throw new Error(
          'Refusing destructive action without --yes. Usage: flush-and-seed --yes'
        );
      }

      const seedFile = path.resolve(
        process.cwd(),
        args['seed-file'] || './seed_data.json'
      );

      await backupCollections(db, collections, projectId);
      await flushCollections(db, collections);
      await seedCollections(db, seedFile);
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
