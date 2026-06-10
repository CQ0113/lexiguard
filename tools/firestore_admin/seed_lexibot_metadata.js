#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const admin = require('firebase-admin');

const { parseArgs, requireFirebaseApp } = require('./manage_firestore');

const INGEST_DIR = path.resolve(__dirname, '..', 'lexibot_ingest');
const DEFAULT_MANIFEST = path.join(INGEST_DIR, 'manifest.json');
const DEFAULT_STORE_STATE = path.join(INGEST_DIR, '.lexibot.local.json');
const CONFIG_PATH = 'lexibot_config/tenancy_mvp';
const SCOPE = 'peninsular_malaysia_residential_tenancy';
const ANSWER_MODEL = 'gemini-2.5-flash';

function usage() {
  console.log(`
LexiBot Firestore Metadata Seeder

Commands:
  seed-pending       Create/update LexiBot config and pending legal-source metadata.
  approve-sources --yes
                     Archive locally reviewed PDFs in Storage and activate metadata.
  record-indexing --yes
                     Record Gemini indexing receipts against approved source versions.
  enable-ui-testing --yes
                     Enable normal LexiBot answers for authenticated frontend testing.
  disable --yes
                     Disable normal LexiBot answers after testing or before release.
  verify             Read and print LexiBot config/source metadata status.

Optional flags:
  --manifest <path>       Defaults to ../lexibot_ingest/manifest.json
  --store-state <path>    Defaults to ../lexibot_ingest/.lexibot.local.json
  --project <projectId>
  --service-account <path/to/service-account.json>

This command does not approve or index legal sources. Pending source versions
must be explicitly approved before File Search ingestion.
`);
}

function readJson(filePath, label) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`${label} not found: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function resolveInputPath(args, key, fallback) {
  return args[key] ? path.resolve(process.cwd(), args[key]) : fallback;
}

function validatePendingManifest(manifest) {
  if (!Array.isArray(manifest.sources) || manifest.sources.length === 0) {
    throw new Error('The LexiBot manifest must contain at least one source.');
  }

  for (const source of manifest.sources) {
    const required = [
      'sourceId',
      'versionId',
      'title',
      'sourceUrl',
      'sourceType',
      'authorityLevel',
      'jurisdiction',
      'contentHash',
    ];
    const missing = required.filter((field) => !source[field]);
    if (missing.length > 0) {
      throw new Error(
        `Manifest source '${source.sourceId || 'unknown'}' is missing: ${missing.join(', ')}.`
      );
    }

    if (source.reviewStatus !== 'pending' || source.status !== 'inactive') {
      throw new Error(
        `Source '${source.sourceId}' must remain pending/inactive for seed-pending.`
      );
    }
  }

  return manifest.sources;
}

function validateStoreState(storeState) {
  if (!storeState.fileSearchStoreName) {
    throw new Error(
      'The File Search store receipt has no fileSearchStoreName. Run the ingestion store:create command first.'
    );
  }
  return storeState;
}

function sha256(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function storagePathFor(source) {
  return `legal_sources/tenancy/${source.sourceId}/${source.versionId}/original.pdf`;
}

async function seedPendingMetadata(db, manifest, storeState) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const configRef = db.doc(CONFIG_PATH);
  const configSnapshot = await configRef.get();

  const configPayload = {
    scope: SCOPE,
    answerModel: ANSWER_MODEL,
    fileSearchStoreName: storeState.fileSearchStoreName,
    fileSearchStoreDisplayName: storeState.fileSearchStoreDisplayName,
    embeddingModel: storeState.embeddingModel,
    minimumCitationCount: 1,
    configuredAt: now,
    updatedAt: now,
  };

  if (!configSnapshot.exists) {
    configPayload.enabled = false;
    configPayload.configurationStatus = 'sources_pending_review';
    configPayload.createdAt = now;
  }

  await configRef.set(configPayload, { merge: true });
  console.log(`Configured ${CONFIG_PATH} (${configSnapshot.exists ? 'updated' : 'created'}).`);

  for (const source of manifest) {
    const sourceRef = db.collection('legal_sources').doc(source.sourceId);
    const versionRef = sourceRef.collection('versions').doc(source.versionId);
    const [sourceSnapshot, versionSnapshot] = await Promise.all([
      sourceRef.get(),
      versionRef.get(),
    ]);

    await sourceRef.set(
      {
        title: source.title,
        sourceType: source.sourceType,
        authorityLevel: source.authorityLevel,
        categories: source.categories || [],
        jurisdiction: source.jurisdiction,
        ...(sourceSnapshot.exists
          ? {}
          : {
              status: 'pending_review',
              activeVersionId: null,
              createdAt: now,
            }),
        updatedAt: now,
      },
      { merge: true }
    );

    if (versionSnapshot.exists) {
      const existingStatus = versionSnapshot.data().reviewStatus;
      console.log(
        `Skipped existing version ${source.sourceId}/${source.versionId} (reviewStatus=${existingStatus || 'unknown'}).`
      );
      continue;
    }

    await versionRef.create({
      sourceUrl: source.sourceUrl,
      sourceType: source.sourceType,
      authorityLevel: source.authorityLevel,
      categories: source.categories || [],
      jurisdiction: source.jurisdiction,
      contentHash: source.contentHash.toLowerCase(),
      downloadedAt: admin.firestore.Timestamp.fromDate(new Date('2026-05-26T00:00:00Z')),
      reviewStatus: 'pending',
      status: 'inactive',
      storagePath: null,
      geminiFileSearchStoreName: null,
      geminiDocumentName: null,
      indexedAt: null,
      createdAt: now,
      updatedAt: now,
    });
    console.log(`Created pending source version: ${source.sourceId}/${source.versionId}.`);
  }
}

async function approveSources(db, manifest, projectId) {
  const bucketName = `${projectId}.firebasestorage.app`;
  const bucket = admin.storage().bucket(bucketName);

  for (const source of manifest) {
    const localPath = path.resolve(INGEST_DIR, source.localPath || '');
    if (!fs.existsSync(localPath)) {
      throw new Error(`Missing PDF for approval: ${localPath}`);
    }

    const digest = sha256(localPath);
    if (digest !== String(source.contentHash).toLowerCase()) {
      throw new Error(`SHA-256 mismatch for ${source.sourceId}; approval aborted.`);
    }

    const sourceRef = db.collection('legal_sources').doc(source.sourceId);
    const versionRef = sourceRef.collection('versions').doc(source.versionId);
    const version = await versionRef.get();
    if (!version.exists) {
      throw new Error(
        `Missing pending metadata for ${source.sourceId}/${source.versionId}. Run seed-pending first.`
      );
    }
    if (version.data().contentHash !== digest) {
      throw new Error(`Firestore hash mismatch for ${source.sourceId}; approval aborted.`);
    }

    const storagePath = storagePathFor(source);
    await bucket.upload(localPath, {
      destination: storagePath,
      metadata: {
        contentType: 'application/pdf',
        metadata: {
          sourceId: source.sourceId,
          versionId: source.versionId,
          contentHash: digest,
          reviewStatus: 'approved',
        },
      },
    });

    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();
    batch.set(
      versionRef,
      {
        storageBucket: bucketName,
        storagePath,
        reviewStatus: 'approved',
        status: 'active',
        reviewedAt: now,
        reviewedBy: 'manual_user_approval_2026-05-26',
        updatedAt: now,
      },
      { merge: true }
    );
    batch.set(
      sourceRef,
      {
        status: 'active',
        activeVersionId: source.versionId,
        updatedAt: now,
      },
      { merge: true }
    );
    await batch.commit();
    console.log(`Archived and approved: ${source.title} -> ${storagePath}`);
  }

  await db.doc(CONFIG_PATH).set(
    {
      configurationStatus: 'sources_approved_pending_index',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function recordIndexing(db, manifest, storeState) {
  const receipts = storeState.imports || {};
  for (const source of manifest) {
    const receiptKey = `${source.sourceId}:${source.versionId}:${String(source.contentHash).toLowerCase()}`;
    const receipt = receipts[receiptKey];
    if (!receipt || !receipt.indexedAt) {
      throw new Error(`No completed Gemini indexing receipt for ${source.sourceId}.`);
    }

    const sourceRef = db.collection('legal_sources').doc(source.sourceId);
    const versionRef = sourceRef.collection('versions').doc(source.versionId);
    const version = await versionRef.get();
    if (!version.exists || version.data().reviewStatus !== 'approved') {
      throw new Error(`Refusing to record indexing for unapproved source ${source.sourceId}.`);
    }

    await versionRef.set(
      {
        indexedStatus: 'indexed',
        geminiFileSearchStoreName: receipt.fileSearchStoreName,
        geminiDocumentName: receipt.geminiDocumentName || null,
        indexedAt: admin.firestore.Timestamp.fromDate(new Date(receipt.indexedAt)),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    console.log(`Recorded indexed source: ${source.title}.`);
  }

  await db.doc(CONFIG_PATH).set(
    {
      configurationStatus: 'sources_indexed_pending_backend',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function verifyMetadata(db) {
  const config = await db.doc(CONFIG_PATH).get();
  if (!config.exists) {
    throw new Error(`Missing ${CONFIG_PATH}. Run seed-pending first.`);
  }

  const sources = await db.collection('legal_sources').get();
  const sourceSummaries = await Promise.all(
    sources.docs.map(async (source) => {
      const versions = await source.ref.collection('versions').get();
      return {
        id: source.id,
        reviewState: source.data().status,
        title: source.data().title,
        versions: versions.docs.map((version) => ({
          id: version.id,
          reviewStatus: version.data().reviewStatus,
          status: version.data().status,
          contentHash: version.data().contentHash,
          storagePath: version.data().storagePath,
          indexedStatus: version.data().indexedStatus,
          geminiDocumentName: version.data().geminiDocumentName,
        })),
      };
    })
  );

  console.log(
    JSON.stringify(
      {
        config: {
          path: CONFIG_PATH,
          ...config.data(),
        },
        sources: sourceSummaries,
      },
      null,
      2
    )
  );
}

async function setClientAnswering(db, enabled) {
  const configRef = db.doc(CONFIG_PATH);
  const config = await configRef.get();
  if (!config.exists) {
    throw new Error(`Missing ${CONFIG_PATH}. Run seed-pending first.`);
  }

  if (enabled) {
    const data = config.data();
    if (!data.answerModel || !data.fileSearchStoreName) {
      throw new Error('LexiBot cannot be enabled without an answer model and File Search store.');
    }

    const sources = await db.collection('legal_sources').where('status', '==', 'active').get();
    const indexedApprovedVersions = [];
    for (const source of sources.docs) {
      const versions = await source.ref
        .collection('versions')
        .where('status', '==', 'active')
        .where('reviewStatus', '==', 'approved')
        .get();
      indexedApprovedVersions.push(
        ...versions.docs.filter((version) => version.data().indexedStatus === 'indexed')
      );
    }
    if (indexedApprovedVersions.length === 0) {
      throw new Error('LexiBot cannot be enabled without an approved indexed source version.');
    }
  }

  const configurationStatus = enabled
    ? 'ui_testing_enabled'
    : 'ui_testing_disabled_pending_release';
  await configRef.set(
    {
      enabled,
      configurationStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(
    enabled
      ? 'LexiBot normal answers are ENABLED for authenticated frontend testing.'
      : 'LexiBot normal answers are DISABLED for clients.'
  );
  console.log(`Configuration status: ${configurationStatus}`);
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
    case 'seed-pending': {
      const manifestPath = resolveInputPath(args, 'manifest', DEFAULT_MANIFEST);
      const storeStatePath = resolveInputPath(
        args,
        'store-state',
        DEFAULT_STORE_STATE
      );
      const sources = validatePendingManifest(
        readJson(manifestPath, 'Pending source manifest')
      );
      const storeState = validateStoreState(
        readJson(storeStatePath, 'File Search store receipt')
      );
      await seedPendingMetadata(db, sources, storeState);
      break;
    }
    case 'approve-sources': {
      if (!args.yes) {
        throw new Error('Refusing approval without --yes. Usage: approve-sources --yes');
      }
      const manifestPath = resolveInputPath(args, 'manifest', DEFAULT_MANIFEST);
      const manifest = readJson(manifestPath, 'Pending source manifest');
      if (!Array.isArray(manifest.sources) || manifest.sources.length === 0) {
        throw new Error('The LexiBot manifest must contain sources to approve.');
      }
      await approveSources(db, manifest.sources, projectId);
      break;
    }
    case 'record-indexing': {
      if (!args.yes) {
        throw new Error('Refusing to record indexing without --yes.');
      }
      const manifestPath = resolveInputPath(args, 'manifest', DEFAULT_MANIFEST);
      const storeStatePath = resolveInputPath(args, 'store-state', DEFAULT_STORE_STATE);
      const manifest = readJson(manifestPath, 'Source manifest');
      const storeState = validateStoreState(
        readJson(storeStatePath, 'File Search store receipt')
      );
      await recordIndexing(db, manifest.sources || [], storeState);
      break;
    }
    case 'enable-ui-testing': {
      if (!args.yes) {
        throw new Error('Refusing to enable client answers without --yes.');
      }
      await setClientAnswering(db, true);
      break;
    }
    case 'disable': {
      if (!args.yes) {
        throw new Error('Refusing to change client availability without --yes.');
      }
      await setClientAnswering(db, false);
      break;
    }
    case 'verify':
      await verifyMetadata(db);
      break;
    default:
      throw new Error(`Unknown command: ${command}`);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exit(1);
  });
}
