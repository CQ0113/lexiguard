const fs = require("fs");
const path = require("path");
const { GoogleGenAI } = require("@google/genai");
const dotenv = require("dotenv");

const toolDir = path.resolve(__dirname, "..");
const projectRoot = path.resolve(toolDir, "..", "..");
const statePath = path.join(toolDir, ".lexibot.local.json");

dotenv.config({ path: path.join(projectRoot, ".env") });

function requireApiKey() {
  const apiKey = String(process.env.GEMINI_API_KEY || "").trim();
  if (!apiKey || apiKey.includes("YOUR_")) {
    throw new Error("Set GEMINI_API_KEY in the ignored root .env file first.");
  }
  return apiKey;
}

function createClient() {
  return new GoogleGenAI({ apiKey: requireApiKey() });
}

function readState() {
  if (!fs.existsSync(statePath)) {
    return {};
  }
  return JSON.parse(fs.readFileSync(statePath, "utf8"));
}

function writeState(patch) {
  const state = {
    ...readState(),
    ...patch,
    updatedAt: new Date().toISOString(),
  };
  fs.writeFileSync(statePath, `${JSON.stringify(state, null, 2)}\n`);
  return state;
}

function getStoreDisplayName() {
  return (
    String(process.env.LEXIBOT_FILE_SEARCH_STORE_DISPLAY_NAME || "").trim() ||
    "lexiguard-tenancy-law-store"
  );
}

function requireStoreName() {
  const state = readState();
  const name =
    String(process.env.LEXIBOT_FILE_SEARCH_STORE_NAME || "").trim() ||
    String(state.fileSearchStoreName || "").trim();
  if (!name) {
    throw new Error("Create the File Search store first with npm run store:create.");
  }
  return name;
}

function getRagModel() {
  return String(process.env.LEXIBOT_RAG_MODEL || "").trim() || "gemini-3.5-flash";
}

function resolveManifestPath(argument) {
  const inputPath = argument || "manifest.json";
  return path.resolve(toolDir, inputPath);
}

module.exports = {
  createClient,
  getRagModel,
  getStoreDisplayName,
  projectRoot,
  readState,
  requireStoreName,
  resolveManifestPath,
  toolDir,
  writeState,
};
