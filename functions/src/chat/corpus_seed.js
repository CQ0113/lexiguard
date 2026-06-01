/**
 * corpus_seed.js — Seed the Firestore law_corpus collection from local .txt files.
 *
 * HTTPS callable: seedLawCorpus
 * Auth gate: caller must have custom claim `reviewer === true`
 * (same pattern as reviewVerificationRequest).
 *
 * Data directory: functions/data/acts/*.txt
 * File format:
 *   SOURCE: <url>
 *   ACT: <full act name>
 *   ACT_NO: <act number>
 *   LANGUAGE: English
 *   RETRIEVED: YYYY-MM
 *
 *   ## sXX — Section Title
 *   <section text>
 *
 * Run once per deploy to populate law_corpus.  Re-running is safe — existing
 * docs with a matching contentHash are skipped.
 */

"use strict";

require("dotenv").config();

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore } = require("firebase-admin/firestore");
const { GoogleGenAI } = require("@google/genai");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const { chunkText, embedText } = require("./rag_helpers");

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Slugify a string for use in Firestore doc IDs.
 * Lowercases, replaces non-alphanumeric runs with underscores, trims edges.
 */
function slugify(str) {
  return str
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "");
}

/**
 * Parse a .txt file into a header object + array of section objects.
 *
 * @param {string} raw  Full file contents.
 * @returns {{ header: object, sections: Array<{sectionNo, sectionTitle, text}> }}
 */
function parseActFile(raw) {
  // Split on double-newline-separated blocks but keep section delimiters.
  const lines = raw.split("\n");

  const header = {};
  const sections = [];
  let currentSection = null;
  let inHeader = true;

  for (const line of lines) {
    const headerMatch = line.match(/^([A-Z_]+):\s*(.*)$/);
    const sectionMatch = line.match(/^##\s+(s\w+)\s+[—-]\s+(.+)$/);

    if (inHeader && headerMatch) {
      header[headerMatch[1]] = headerMatch[2].trim();
      continue;
    }

    // Blank line after header keys signals end of header
    if (inHeader && line.trim() === "") {
      inHeader = false;
      continue;
    }

    if (sectionMatch) {
      inHeader = false;
      if (currentSection) {
        sections.push({
          ...currentSection,
          text: currentSection.text.trim(),
        });
      }
      currentSection = {
        sectionNo: sectionMatch[1].trim(),
        sectionTitle: sectionMatch[2].trim(),
        text: "",
      };
      continue;
    }

    if (currentSection) {
      currentSection.text += line + "\n";
    }
  }

  if (currentSection) {
    sections.push({ ...currentSection, text: currentSection.text.trim() });
  }

  return { header, sections };
}

// ---------------------------------------------------------------------------
// seedLawCorpus — HTTPS callable
// ---------------------------------------------------------------------------
exports.seedLawCorpus = onCall({ invoker: "public" }, async (request) => {
  // Auth gate — same pattern as reviewVerificationRequest
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const inEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  const hasReviewerClaim = request.auth?.token?.reviewer === true;

  if (!inEmulator && !hasReviewerClaim) {
    throw new HttpsError(
      "permission-denied",
      "Reviewer role is required to seed the law corpus."
    );
  }

  // Env vars
  const apiKey = process.env.GEMINI_API_KEY;
  const embedModel = process.env.GEMINI_EMBED_MODEL;

  if (!apiKey) {
    throw new HttpsError(
      "internal",
      "Server configuration error: missing GEMINI_API_KEY."
    );
  }
  if (!embedModel) {
    throw new HttpsError(
      "internal",
      "Server configuration error: missing GEMINI_EMBED_MODEL."
    );
  }

  const ai = new GoogleGenAI({ apiKey });
  const db = getFirestore();

  const actsDir = path.join(__dirname, "../../../data/acts");

  let txtFiles;
  try {
    txtFiles = fs
      .readdirSync(actsDir)
      .filter((f) => f.endsWith(".txt"))
      .map((f) => path.join(actsDir, f));
  } catch (err) {
    throw new HttpsError(
      "internal",
      `Failed to read acts directory (${actsDir}): ${err.message}`
    );
  }

  if (txtFiles.length === 0) {
    return { seeded: 0, skipped: 0, total: 0, errors: [] };
  }

  let seeded = 0;
  let skipped = 0;
  const errors = [];

  for (const filePath of txtFiles) {
    const raw = fs.readFileSync(filePath, "utf8");
    const { header, sections } = parseActFile(raw);

    const actName = header.ACT || path.basename(filePath, ".txt");
    const actNo = header.ACT_NO || "";
    const sourceUrl = header.SOURCE || "";
    const language = header.LANGUAGE || "English";
    const retrieved = header.RETRIEVED || "";
    const actSlug = slugify(actName);

    for (const section of sections) {
      // Skip TODO placeholder sections
      if (section.text.includes("[TODO:") || !section.text.trim()) {
        continue;
      }

      const chunks = chunkText(section.text, 800, 100);
      const sectionSlug = slugify(section.sectionNo);

      for (const chunk of chunks) {
        const contentHash = crypto
          .createHash("sha256")
          .update(chunk)
          .digest("hex")
          .slice(0, 16);

        const docId = `${actSlug}__${sectionSlug}__${contentHash}`;
        const docRef = db.collection("law_corpus").doc(docId);

        // Skip if already seeded with the same content
        let existing;
        try {
          existing = await docRef.get();
        } catch (err) {
          errors.push({ docId, error: `Firestore read failed: ${err.message}` });
          continue;
        }

        if (existing.exists && existing.data().contentHash === contentHash) {
          skipped++;
          continue;
        }

        // Embed the chunk
        let embedding;
        try {
          embedding = await embedText(ai, embedModel, chunk);
        } catch (err) {
          errors.push({ docId, error: `Embed failed: ${err.message}` });
          continue;
        }

        // Write to Firestore
        try {
          await docRef.set({
            actName,
            actNo,
            sectionNo: section.sectionNo,
            sectionTitle: section.sectionTitle,
            chunkText: chunk,
            contentHash,
            sourceUrl,
            language,
            retrieved,
            embedding,
            seededAt: new Date().toISOString(),
          });
          seeded++;
        } catch (err) {
          errors.push({ docId, error: `Firestore write failed: ${err.message}` });
        }
      }
    }
  }

  const total = seeded + skipped + errors.length;
  return { seeded, skipped, total, errors };
});
