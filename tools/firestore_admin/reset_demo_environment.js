#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const { parseArgs, requireFirebaseApp } = require('./manage_firestore');

const EXPECTED_PROJECT_ID = 'lexiguard-32c63';
const DEFAULT_PASSWORD = 'LexiDemo!2026';
const ADMIN_EMAIL = 'admin123@gmail.com';
const ADMIN_PASSWORD = 'admin123';

const RESET_COLLECTIONS = [
  'users',
  'lawyer_profiles',
  'verification_requests',
  'cases',
  'connection_requests',
  'chat_rooms',
  'notifications',
  'vault_documents',
  'lexibot_audit_logs',
];

const STORAGE_PREFIXES = ['vault/', 'case_attachments/', 'chat_attachments/'];

function usage() {
  console.log(`
LexiGuard Firebase Demo Reset

This talks to the real Firebase project. It deletes Auth users, app Firestore
data, and app-owned Storage files, then seeds clean demo clients/lawyers.

Dry run:
  node reset_demo_environment.js --dry-run

Execute:
  node reset_demo_environment.js --yes --confirm ${EXPECTED_PROJECT_ID}

Options:
  --project <projectId>
  --service-account <path/to/service-account.json>
  --skip-auth
  --skip-storage
`);
}

function assertResetAllowed(args, projectId) {
  if (args['dry-run']) return;
  if (!args.yes || args.confirm !== projectId) {
    throw new Error(
      `Refusing destructive reset. Re-run with --yes --confirm ${projectId}`
    );
  }
  if (projectId !== EXPECTED_PROJECT_ID) {
    throw new Error(
      `Project guard failed. Expected ${EXPECTED_PROJECT_ID}, got ${projectId}`
    );
  }
}

function backupDir() {
  const dir = path.resolve(__dirname, 'backups');
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function timestampLabel() {
  return new Date().toISOString().replace(/[:.]/g, '-');
}

function serializeValue(value) {
  if (value == null) return value;
  if (value instanceof admin.firestore.Timestamp) {
    return { __type: 'timestamp', iso: value.toDate().toISOString() };
  }
  if (value instanceof admin.firestore.GeoPoint) {
    return {
      __type: 'geopoint',
      latitude: value.latitude,
      longitude: value.longitude,
    };
  }
  if (value instanceof admin.firestore.DocumentReference) {
    return { __type: 'reference', path: value.path };
  }
  if (Buffer.isBuffer(value)) {
    return { __type: 'bytes', base64: value.toString('base64') };
  }
  if (Array.isArray(value)) return value.map(serializeValue);
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, serializeValue(item)])
    );
  }
  return value;
}

async function exportCollection(collectionRef) {
  const snapshot = await collectionRef.get();
  const docs = [];
  for (const doc of snapshot.docs) {
    const subcollections = {};
    const subRefs = await doc.ref.listCollections();
    for (const subRef of subRefs) {
      subcollections[subRef.id] = await exportCollection(subRef);
    }
    docs.push({
      id: doc.id,
      path: doc.ref.path,
      data: serializeValue(doc.data()),
      subcollections,
    });
  }
  return docs;
}

async function backupFirestore(db, projectId) {
  const data = {
    projectId,
    exportedAt: new Date().toISOString(),
    collections: {},
  };
  for (const collectionName of RESET_COLLECTIONS) {
    data.collections[collectionName] = await exportCollection(
      db.collection(collectionName)
    );
  }
  const outputPath = path.join(
    backupDir(),
    `reset-firestore-${timestampLabel()}.json`
  );
  fs.writeFileSync(outputPath, JSON.stringify(data, null, 2));
  console.log(`Firestore backup: ${outputPath}`);
  return outputPath;
}

async function listAuthUsers() {
  const users = [];
  let pageToken;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

async function backupAuthUsers() {
  const users = await listAuthUsers();
  const output = {
    exportedAt: new Date().toISOString(),
    count: users.length,
    users: users.map((user) => ({
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      disabled: user.disabled,
      emailVerified: user.emailVerified,
      customClaims: user.customClaims || {},
      providerData: user.providerData,
      metadata: {
        creationTime: user.metadata.creationTime,
        lastSignInTime: user.metadata.lastSignInTime,
        lastRefreshTime: user.metadata.lastRefreshTime,
      },
    })),
  };
  const outputPath = path.join(backupDir(), `reset-auth-${timestampLabel()}.json`);
  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
  console.log(`Auth backup: ${outputPath}`);
  return users;
}

async function deleteAuthUsers(users) {
  if (!users.length) {
    console.log('Auth already empty.');
    return;
  }
  for (let index = 0; index < users.length; index += 1000) {
    const batch = users.slice(index, index + 1000);
    const result = await admin.auth().deleteUsers(batch.map((user) => user.uid));
    if (result.failureCount > 0) {
      console.warn(
        `Auth batch deleted with ${result.failureCount} failure(s):`,
        result.errors
      );
    }
    console.log(`Deleted ${result.successCount} Auth users.`);
  }
}

async function deleteFirestoreData(db) {
  for (const collectionName of RESET_COLLECTIONS) {
    console.log(`Deleting Firestore collection recursively: ${collectionName}`);
    await db.recursiveDelete(db.collection(collectionName));
  }
}

async function deleteStorageData(projectId) {
  const bucket = admin.storage().bucket(`${projectId}.firebasestorage.app`);
  for (const prefix of STORAGE_PREFIXES) {
    const [files] = await bucket.getFiles({ prefix });
    if (!files.length) {
      console.log(`Storage prefix already empty: ${prefix}`);
      continue;
    }
    for (let index = 0; index < files.length; index += 100) {
      const batch = files.slice(index, index + 100);
      await Promise.all(
        batch.map((file) =>
          file.delete({ ignoreNotFound: true }).catch((error) => {
            console.warn(`Could not delete ${file.name}: ${error.message}`);
          })
        )
      );
    }
    console.log(`Deleted ${files.length} Storage file(s) under ${prefix}`);
  }
}

function date(value) {
  return admin.firestore.Timestamp.fromDate(new Date(value));
}

function now() {
  return admin.firestore.Timestamp.now();
}

function lawyerSnapshot(user) {
  return {
    name: user.name,
    firmName: user.firmName,
    specialization: user.specialization,
    yearsExperience: user.yearsExperience,
    rating: user.rating,
    practiceState: user.practiceState,
    practiceCity: user.practiceCity,
    languages: user.languages,
    hourlyRate: user.hourlyRate,
    barNumber: user.barNumber,
    jurisdiction: user.jurisdiction,
    verificationStatus: user.verificationStatus,
  };
}

function caseSnapshot(caseDoc) {
  return {
    title: caseDoc.title,
    category: caseDoc.category,
    location: caseDoc.location,
    budgetRange: caseDoc.budgetRange,
    urgency: caseDoc.urgency,
  };
}

function clientReveal(user) {
  return {
    name: user.name,
    email: user.email,
    phone: user.phone,
  };
}

async function ensureAuthUser(account) {
  const payload = {
    email: account.email,
    password: account.password,
    displayName: account.displayName || account.name,
    emailVerified: true,
    disabled: false,
  };
  const user = await admin.auth().createUser(payload);
  if (account.customClaims) {
    await admin.auth().setCustomUserClaims(user.uid, account.customClaims);
  }
  return user.uid;
}

function authAccounts() {
  return [
    {
      key: 'admin',
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
      name: 'LexiGuard Admin',
    },
    {
      key: 'client_chu',
      email: 'client.chu@lexiguard.dev',
      password: DEFAULT_PASSWORD,
      name: 'CHU CHENG QING',
      phone: '+60123450001',
      role: 'client',
    },
    {
      key: 'client_ahmad',
      email: 'client.ahmad@lexiguard.dev',
      password: DEFAULT_PASSWORD,
      name: 'Ahmad Razif',
      phone: '+60123450002',
      role: 'client',
    },
    {
      key: 'client_nurul',
      email: 'client.nurul@lexiguard.dev',
      password: DEFAULT_PASSWORD,
      name: 'Nurul Hana Binti Aziz',
      phone: '+60123450003',
      role: 'client',
    },
    {
      key: 'lawyer_aishah',
      email: 'lawyer.aishah@lexiguard.dev',
      password: DEFAULT_PASSWORD,
      name: 'Pn. Aishah binti Kamal',
      phone: '+60198765432',
      role: 'lawyer',
      barNumber: 'B/MY/09384',
      specialization: 'Property Law',
      hourlyRate: 350,
      rating: 4.8,
      yearsExperience: 8,
      barCouncilVerified: true,
      verificationStatus: 'auto_verified',
      verificationProvider: 'malaysian_bar',
      verificationBadgeVisible: true,
      legalFullName: 'Aishah binti Kamal',
      firmName: 'Kamal & Partners',
      jurisdiction: 'peninsular',
      practiceState: 'Selangor',
      practiceCity: 'Shah Alam',
      languages: ['English', 'Malay'],
    },
    {
      key: 'lawyer_kailesh',
      email: 'lawyer.kailesh@lexiguard.dev',
      password: DEFAULT_PASSWORD,
      name: 'A Kailesh A/L R Arumugam',
      phone: '+60198765433',
      role: 'lawyer',
      barNumber: 'B/MY/11842',
      specialization: 'General Practice',
      hourlyRate: 280,
      rating: 4.6,
      yearsExperience: 6,
      barCouncilVerified: true,
      verificationStatus: 'auto_verified',
      verificationProvider: 'malaysian_bar',
      verificationBadgeVisible: true,
      legalFullName: 'A Kailesh A/L R Arumugam',
      firmName: 'Arumugam Legal',
      jurisdiction: 'peninsular',
      practiceState: 'Selangor',
      practiceCity: 'Petaling Jaya',
      languages: ['English', 'Malay', 'Tamil'],
    },
    {
      key: 'lawyer_siti',
      email: 'lawyer.siti@lexiguard.dev',
      password: DEFAULT_PASSWORD,
      name: 'Siti Rahmah Binti Omar',
      phone: '+60128887766',
      role: 'lawyer',
      barNumber: 'SLS/2019/0421',
      specialization: 'Family Law',
      hourlyRate: 250,
      rating: 4.5,
      yearsExperience: 5,
      barCouncilVerified: false,
      verificationStatus: 'manual_review_required',
      verificationProvider: 'manual_review_sabah',
      verificationBadgeVisible: false,
      legalFullName: 'Siti Rahmah Binti Omar',
      firmName: 'Rahmah Legal Chambers',
      jurisdiction: 'sabah',
      practiceState: 'Sabah',
      practiceCity: 'Kota Kinabalu',
      languages: ['English', 'Malay'],
    },
    {
      key: 'reviewer',
      email: 'demo.reviewer@lexiguard.dev',
      password: DEFAULT_PASSWORD,
      name: 'Reviewer Demo',
      phone: '+60100000000',
      role: 'client',
      customClaims: { reviewer: true },
    },
  ];
}

async function seedAuthUsers() {
  const accounts = authAccounts();
  const byKey = {};
  for (const account of accounts) {
    const uid = await ensureAuthUser(account);
    byKey[account.key] = { ...account, uid };
  }
  return byKey;
}

function userDoc(account) {
  return {
    id: account.uid,
    name: account.name,
    email: account.email,
    phone: account.phone || '',
    role: account.role,
    avatarUrl: account.avatarUrl || null,
    createdAt: date('2026-06-01T00:00:00.000Z'),
    updatedAt: now(),
    ...(account.role === 'lawyer'
      ? {
          barNumber: account.barNumber,
          specialization: account.specialization,
          hourlyRate: account.hourlyRate,
          rating: account.rating,
          yearsExperience: account.yearsExperience,
          barCouncilVerified: account.barCouncilVerified,
          verificationStatus: account.verificationStatus,
          verificationProvider: account.verificationProvider,
          verificationBadgeVisible: account.verificationBadgeVisible,
          legalFullName: account.legalFullName,
          firmName: account.firmName,
          jurisdiction: account.jurisdiction,
          practiceState: account.practiceState,
          practiceCity: account.practiceCity,
          languages: account.languages,
          verifiedAt:
            account.verificationStatus === 'auto_verified'
              ? date('2026-06-01T00:00:00.000Z')
              : null,
          lastVerifiedAt:
            account.verificationStatus === 'auto_verified'
              ? date('2026-06-01T00:00:00.000Z')
              : null,
          nextReverifyAt:
            account.verificationStatus === 'auto_verified'
              ? date('2027-06-01T00:00:00.000Z')
              : null,
        }
      : {}),
  };
}

function lawyerProfileDoc(account) {
  return {
    uid: account.uid,
    legalFullName: account.legalFullName,
    firmName: account.firmName,
    jurisdiction: account.jurisdiction,
    practiceState: account.practiceState,
    practiceCity: account.practiceCity,
    barOrRollNumber: account.barNumber,
    verificationStatus: account.verificationStatus,
    verificationProvider: account.verificationProvider,
    verificationBadgeVisible: account.verificationBadgeVisible,
    createdAt: date('2026-06-01T00:00:00.000Z'),
    updatedAt: now(),
  };
}

function buildSeedData(accounts) {
  const clientChu = accounts.client_chu;
  const clientAhmad = accounts.client_ahmad;
  const clientNurul = accounts.client_nurul;
  const lawyerAishah = accounts.lawyer_aishah;
  const lawyerKailesh = accounts.lawyer_kailesh;
  const lawyerSiti = accounts.lawyer_siti;

  const cases = {
    case_land_arguments: {
      id: 'case_land_arguments',
      clientId: clientChu.uid,
      lawyerId: lawyerAishah.uid,
      title: 'Land Arguments',
      description: "My landlord doesn't want to give back my deposit.",
      location: 'Johor Bahru, Johor',
      budgetRange: 'Flexible / Negotiable',
      category: 'property',
      status: 'active',
      urgency: 'low',
      progressPercent: 35,
      createdAt: date('2026-06-23T03:40:00.000Z'),
      interestedLawyerIds: [lawyerAishah.uid],
      attachments: [],
      lawyerRecommendations: [],
      recommendationStatus: 'completed',
    },
    case_rental_deposit: {
      id: 'case_rental_deposit',
      clientId: clientAhmad.uid,
      lawyerId: lawyerAishah.uid,
      title: 'Rental Deposit Dispute',
      description:
        'Landlord refuses to return the security deposit after handover despite no damage.',
      location: 'Petaling Jaya, Selangor',
      budgetRange: 'RM 200 - 400/hr',
      category: 'property',
      status: 'active',
      urgency: 'medium',
      progressPercent: 50,
      nextHearing: date('2026-07-15T02:00:00.000Z'),
      createdAt: date('2026-06-12T02:00:00.000Z'),
      interestedLawyerIds: [lawyerAishah.uid],
      attachments: [],
      lawyerRecommendations: [],
      recommendationStatus: 'completed',
    },
    case_employment_pending: {
      id: 'case_employment_pending',
      clientId: clientNurul.uid,
      lawyerId: null,
      title: 'Wrongful Termination',
      description:
        'Employer terminated me without notice after five years of service.',
      location: 'Kuala Lumpur',
      budgetRange: 'RM 200 - 400/hr',
      category: 'employment',
      status: 'pending',
      urgency: 'high',
      progressPercent: 0,
      createdAt: date('2026-06-20T08:30:00.000Z'),
      interestedLawyerIds: [],
      attachments: [],
      lawyerRecommendations: [
        {
          lawyerId: lawyerKailesh.uid,
          lawyerName: lawyerKailesh.name,
          specialization: lawyerKailesh.specialization,
          practiceState: lawyerKailesh.practiceState,
          practiceCity: lawyerKailesh.practiceCity,
          yearsExperience: lawyerKailesh.yearsExperience,
          languages: lawyerKailesh.languages,
          hourlyRate: lawyerKailesh.hourlyRate,
          matchPercentage: 87,
          matchReason: 'General litigation experience and nearby practice.',
        },
        {
          lawyerId: lawyerAishah.uid,
          lawyerName: lawyerAishah.name,
          specialization: lawyerAishah.specialization,
          practiceState: lawyerAishah.practiceState,
          practiceCity: lawyerAishah.practiceCity,
          yearsExperience: lawyerAishah.yearsExperience,
          languages: lawyerAishah.languages,
          hourlyRate: lawyerAishah.hourlyRate,
          matchPercentage: 72,
          matchReason: 'Strong documentation and civil dispute background.',
        },
      ],
      recommendationStatus: 'completed',
      recommendationGeneratedAt: date('2026-06-20T08:35:00.000Z'),
      recommendationModel: 'seeded-demo',
    },
    case_family_pending: {
      id: 'case_family_pending',
      clientId: clientChu.uid,
      lawyerId: null,
      title: 'Divorce and Custody Advice',
      description:
        'Need advice on amicable divorce filing and child custody arrangement.',
      location: 'Kota Kinabalu, Sabah',
      budgetRange: 'RM 100 - 200/hr',
      category: 'family',
      status: 'pending',
      urgency: 'low',
      progressPercent: 0,
      createdAt: date('2026-06-18T04:00:00.000Z'),
      interestedLawyerIds: [lawyerSiti.uid],
      attachments: [],
      lawyerRecommendations: [],
      recommendationStatus: 'not_requested',
    },
  };

  const approvedAt = date('2026-06-23T03:48:00.000Z');
  const requestLandId = `${cases.case_land_arguments.id}_${lawyerAishah.uid}`;
  const requestRentalId = `${cases.case_rental_deposit.id}_${lawyerAishah.uid}`;
  const pendingRequestId = `${cases.case_family_pending.id}_${lawyerSiti.uid}`;

  return {
    users: Object.values(accounts)
      .filter((account) => account.role === 'client' || account.role === 'lawyer')
      .map((account) => ({ id: account.uid, data: userDoc(account) })),
    lawyer_profiles: [lawyerAishah, lawyerKailesh, lawyerSiti].map(
      (account) => ({ id: account.uid, data: lawyerProfileDoc(account) })
    ),
    verification_requests: [
      {
        id: lawyerSiti.uid,
        data: {
          uid: lawyerSiti.uid,
          queueStatus: 'queued',
          queueReason: 'east_malaysia_manual_review_only',
          requestType: 'lawyer_registration',
          legalFullName: lawyerSiti.legalFullName,
          firmName: lawyerSiti.firmName,
          jurisdiction: lawyerSiti.jurisdiction,
          practiceState: lawyerSiti.practiceState,
          practiceCity: lawyerSiti.practiceCity,
          barOrRollNumber: lawyerSiti.barNumber,
          verificationStatus: lawyerSiti.verificationStatus,
          verificationProvider: lawyerSiti.verificationProvider,
          createdAt: date('2026-06-01T00:00:00.000Z'),
          updatedAt: now(),
        },
      },
    ],
    cases: Object.values(cases).map((caseDoc) => ({
      id: caseDoc.id,
      data: caseDoc,
    })),
    connection_requests: [
      {
        id: requestLandId,
        data: {
          id: requestLandId,
          caseId: cases.case_land_arguments.id,
          clientId: clientChu.uid,
          lawyerId: lawyerAishah.uid,
          message: 'The client has requested you for this case.',
          status: 'approved',
          initiatedByRole: 'client',
          requestDirection: 'client_to_lawyer',
          createdAt: date('2026-06-23T03:42:00.000Z'),
          updatedAt: approvedAt,
          respondedAt: approvedAt,
          declineReason: null,
          clientReveal: clientReveal(clientChu),
          lawyerSnapshot: lawyerSnapshot(lawyerAishah),
          caseSnapshot: caseSnapshot(cases.case_land_arguments),
        },
      },
      {
        id: requestRentalId,
        data: {
          id: requestRentalId,
          caseId: cases.case_rental_deposit.id,
          clientId: clientAhmad.uid,
          lawyerId: lawyerAishah.uid,
          message:
            'I can assist with the deposit dispute and prepare the demand letter.',
          status: 'approved',
          initiatedByRole: 'lawyer',
          requestDirection: 'lawyer_to_client',
          createdAt: date('2026-06-12T06:00:00.000Z'),
          updatedAt: date('2026-06-12T07:00:00.000Z'),
          respondedAt: date('2026-06-12T07:00:00.000Z'),
          declineReason: null,
          clientReveal: clientReveal(clientAhmad),
          lawyerSnapshot: lawyerSnapshot(lawyerAishah),
          caseSnapshot: caseSnapshot(cases.case_rental_deposit),
        },
      },
      {
        id: pendingRequestId,
        data: {
          id: pendingRequestId,
          caseId: cases.case_family_pending.id,
          clientId: clientChu.uid,
          lawyerId: lawyerSiti.uid,
          message:
            'I can review the custody documents and advise on Sabah court process.',
          status: 'pending',
          initiatedByRole: 'lawyer',
          requestDirection: 'lawyer_to_client',
          createdAt: date('2026-06-18T06:00:00.000Z'),
          updatedAt: date('2026-06-18T06:00:00.000Z'),
          respondedAt: null,
          declineReason: null,
          clientReveal: null,
          lawyerSnapshot: lawyerSnapshot(lawyerSiti),
          caseSnapshot: caseSnapshot(cases.case_family_pending),
        },
      },
    ],
    chat_rooms: [
      {
        id: requestLandId,
        data: {
          id: requestLandId,
          caseId: cases.case_land_arguments.id,
          clientId: clientChu.uid,
          lawyerId: lawyerAishah.uid,
          participants: [clientChu.uid, lawyerAishah.uid],
          clientName: clientChu.name,
          lawyerName: lawyerAishah.name,
          caseTitle: cases.case_land_arguments.title,
          lastMessageText: 'Hi, I can help review your deposit documents.',
          lastMessageType: 'text',
          lastSenderId: lawyerAishah.uid,
          lastMessageAt: date('2026-06-23T04:05:00.000Z'),
          createdAt: approvedAt,
          unreadCounts: { [clientChu.uid]: 1, [lawyerAishah.uid]: 0 },
        },
        messages: [
          {
            id: 'seed_m1',
            data: {
              id: 'seed_m1',
              roomId: requestLandId,
              senderId: clientChu.uid,
              senderRole: 'client',
              type: 'text',
              text: 'Nihao, I need help with my landlord.',
              createdAt: date('2026-06-23T04:00:00.000Z'),
            },
          },
          {
            id: 'seed_m2',
            data: {
              id: 'seed_m2',
              roomId: requestLandId,
              senderId: lawyerAishah.uid,
              senderRole: 'lawyer',
              type: 'text',
              text: 'Hi, I can help review your deposit documents.',
              createdAt: date('2026-06-23T04:05:00.000Z'),
            },
          },
        ],
      },
      {
        id: requestRentalId,
        data: {
          id: requestRentalId,
          caseId: cases.case_rental_deposit.id,
          clientId: clientAhmad.uid,
          lawyerId: lawyerAishah.uid,
          participants: [clientAhmad.uid, lawyerAishah.uid],
          clientName: clientAhmad.name,
          lawyerName: lawyerAishah.name,
          caseTitle: cases.case_rental_deposit.title,
          lastMessageText: 'Please upload the tenancy agreement when ready.',
          lastMessageType: 'text',
          lastSenderId: lawyerAishah.uid,
          lastMessageAt: date('2026-06-12T07:20:00.000Z'),
          createdAt: date('2026-06-12T07:00:00.000Z'),
          unreadCounts: { [clientAhmad.uid]: 1, [lawyerAishah.uid]: 0 },
        },
        messages: [
          {
            id: 'seed_m1',
            data: {
              id: 'seed_m1',
              roomId: requestRentalId,
              senderId: lawyerAishah.uid,
              senderRole: 'lawyer',
              type: 'text',
              text: 'Please upload the tenancy agreement when ready.',
              createdAt: date('2026-06-12T07:20:00.000Z'),
            },
          },
        ],
      },
    ],
    notifications: [
      {
        id: `notif_${clientChu.uid}_connected`,
        data: {
          userId: clientChu.uid,
          title: 'Lawyer connected',
          body: `${lawyerAishah.name} accepted your Land Arguments case.`,
          type: 'connection',
          read: false,
          createdAt: approvedAt,
        },
      },
    ],
  };
}

async function seedFirestoreData(db, accounts) {
  const seedData = buildSeedData(accounts);
  for (const [collectionName, docs] of Object.entries(seedData)) {
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
    if (count > 0) await batch.commit();

    if (collectionName === 'chat_rooms') {
      for (const room of docs) {
        if (!room.messages) continue;
        let messageBatch = db.batch();
        for (const message of room.messages) {
          messageBatch.set(
            db
              .collection('chat_rooms')
              .doc(room.id)
              .collection('messages')
              .doc(message.id),
            message.data,
            { merge: false }
          );
        }
        await messageBatch.commit();
      }
    }

    console.log(`Seeded ${docs.length} doc(s) into ${collectionName}`);
  }
}

async function summarize(db) {
  const counts = {};
  for (const collectionName of RESET_COLLECTIONS) {
    const snapshot = await db.collection(collectionName).count().get();
    counts[collectionName] = snapshot.data().count;
  }
  const authCount = (await listAuthUsers()).length;
  console.log('\nCurrent app data counts:');
  console.table({ auth_users: authCount, ...counts });
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || args._[0] === 'help') {
    usage();
    return;
  }

  const { db, projectId } = requireFirebaseApp(args);
  console.log(`Using project: ${projectId}`);
  assertResetAllowed(args, projectId);

  if (args['dry-run']) {
    await summarize(db);
    console.log('\nDry run only. No data was changed.');
    console.log(
      `To execute: node reset_demo_environment.js --yes --confirm ${projectId}`
    );
    return;
  }

  console.log('Creating backups before reset...');
  const existingAuthUsers = args['skip-auth']
    ? []
    : await backupAuthUsers();
  await backupFirestore(db, projectId);

  if (!args['skip-auth']) {
    await deleteAuthUsers(existingAuthUsers);
  } else {
    console.log('Skipping Auth deletion.');
  }

  await deleteFirestoreData(db);

  if (!args['skip-storage']) {
    await deleteStorageData(projectId);
  } else {
    console.log('Skipping Storage deletion.');
  }

  console.log('\nSeeding clean demo accounts and data...');
  const accounts = await seedAuthUsers();
  await seedFirestoreData(db, accounts);

  console.log('\nSeed accounts:');
  console.table(
    Object.values(accounts).map((account) => ({
      role: account.key === 'admin' ? 'admin' : account.role,
      email: account.email,
      password:
        account.key === 'admin' ? ADMIN_PASSWORD : DEFAULT_PASSWORD,
      uid: account.uid,
    }))
  );

  await summarize(db);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
