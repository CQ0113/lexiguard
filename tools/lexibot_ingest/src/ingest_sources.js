const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const {
  createClient,
  readState,
  requireStoreName,
  resolveManifestPath,
  toolDir,
  writeState,
} = require("./config");

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function customMetadata(source) {
  const metadata = [
    ["source_id", source.sourceId],
    ["version_id", source.versionId],
    ["title", source.title],
    ["source_url", source.sourceUrl],
    ["source_type", source.sourceType],
    ["authority_level", source.authorityLevel],
    ["jurisdiction", source.jurisdiction],
    ["review_status", source.reviewStatus],
    ["categories", (source.categories || []).join(",")],
  ];
  return metadata
    .filter(([, value]) => value)
    .map(([key, value]) => ({ key, stringValue: String(value) }));
}

async function waitForOperation(ai, operation) {
  let current = operation;
  while (!current.done) {
    await new Promise((resolve) => setTimeout(resolve, 5000));
    current = await ai.operations.get({ operation: current });
  }
  return current;
}

function loadApprovedSources(manifestPath) {
  if (!fs.existsSync(manifestPath)) {
    throw new Error(
      `Manifest not found: ${manifestPath}. Copy manifest.example.json to manifest.json first.`,
    );
  }
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const sources = Array.isArray(manifest.sources) ? manifest.sources : [];
  return sources.filter(
    (source) => source.reviewStatus === "approved" && source.status === "active",
  );
}

async function run() {
  const manifestPath = resolveManifestPath(process.argv[2]);
  const sources = loadApprovedSources(manifestPath);
  if (sources.length === 0) {
    throw new Error("There are no approved active source entries to index.");
  }

  const ai = createClient();
  const storeName = requireStoreName();
  const state = readState();
  const imports = { ...(state.imports || {}) };

  for (const source of sources) {
    const filePath = path.resolve(toolDir, source.localPath || "");
    if (!fs.existsSync(filePath)) {
      throw new Error(`Missing PDF for ${source.sourceId}: ${filePath}`);
    }

    const digest = sha256(filePath);
    if (!source.contentHash || digest !== source.contentHash.toLowerCase()) {
      throw new Error(
        `SHA-256 mismatch for ${source.sourceId}. Expected the manifest hash for the approved PDF.`,
      );
    }

    const receiptKey = `${source.sourceId}:${source.versionId}:${digest}`;
    if (imports[receiptKey]?.indexedAt) {
      console.log(`Skipping already indexed source: ${source.title}`);
      continue;
    }

    console.log(`Uploading approved source: ${source.title}`);
    const operation = await ai.fileSearchStores.uploadToFileSearchStore({
      file: filePath,
      fileSearchStoreName: storeName,
      config: {
        displayName: `${source.title} (${source.versionId})`,
        customMetadata: customMetadata(source),
      },
    });
    const completedOperation = await waitForOperation(ai, operation);
    const response = completedOperation.response || {};
    const geminiDocumentName =
      response.documentName || response.document?.name || response.name || null;

    imports[receiptKey] = {
      sourceId: source.sourceId,
      versionId: source.versionId,
      contentHash: digest,
      title: source.title,
      fileSearchStoreName: storeName,
      geminiDocumentName,
      indexedAt: new Date().toISOString(),
    };
    writeState({ imports });
    console.log(`Indexed approved source: ${source.title}`);
  }
}

run().catch((error) => {
  console.error(`Ingestion failed: ${error.message}`);
  process.exitCode = 1;
});
