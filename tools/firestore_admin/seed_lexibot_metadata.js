#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const { parseArgs, requireFirebaseApp } = require('./manage_firestore');

const INGEST_DIR = path.resolve(__dirname, '..', 'lexibot_ingest');
const DEFAULT_MANIFEST = path.join(INGEST_DIR, 'manifest.json');
const DEFAULT_STORE_STATE = path.join(INGEST_DIR, '.lexibot.local.json');
const CONFIG_PATH = 'lexibot_config/tenancy_mvp';
const SCOPE = 'peninsular_malaysia_residential_tenancy';
const ANSWER_MODEL = 'gemini-3.5-flash';

function usage() {
  console.log(`
LexiBot Firestore Metadata Seeder

Commands:
  seed-pending       Create/update LexiBot config and pending legal-source metadata.
  verify             Read and print LexiBot config/source metadata status.

Optional flags:
  --manifest <path>       Defaults to ../lexibot_ingest/manifest.json
  --store-state <path>    Defaults to ../lexibot_ingest/.lexibot.local.json
  --project <projectId>
  --service-account <path/to/service-account.json>

This command does not approve or index legal sources. Pending source versions
must be reviewed and activated separately before File Search ingestion.
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
