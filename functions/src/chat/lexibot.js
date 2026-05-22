/**
 * LexiBot — RAG-backed Malaysian law assistant.
 *
 * Model name reference (verify current names before deploying):
 *   https://ai.google.dev/gemini-api/docs/models
 *
 * Required environment variables (set in functions/.env):
 *   GEMINI_API_KEY   — Google AI API key
 *   GEMINI_CHAT_MODEL  — e.g. "gemini-2.0-flash" (verify against docs above)
 *   GEMINI_EMBED_MODEL — e.g. "gemini-embedding-exp-03-07" (verify against docs above)
 */

"use strict";

require("dotenv").config();

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { GoogleGenAI } = require("@google/genai");
const { cosine, embedText: _embedText } = require("./rag_helpers");

// ---------------------------------------------------------------------------
// Env-var validation — deferred to first call so the module loads cleanly
// even when env is not yet configured (e.g. during `node -e "require(...)"`
// validation). The error surfaces on the first real invocation.
// ---------------------------------------------------------------------------
function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new HttpsError(
      "internal",
      `Server configuration error: missing environment variable ${name}. ` +
        "Set it in functions/.env before deploying."
    );
  }
  return value;
}

// ---------------------------------------------------------------------------
// Mock corpus — 3 chunks from real Malaysian statutes.
// embeddings are null here; they are computed on-the-fly per call.
// Step 8 will pre-embed and store in Firestore law_corpus instead.
// Source URLs point to the AGC Federal Legislation Portal (lom.agc.gov.my).
// ---------------------------------------------------------------------------
const MOCK_CORPUS = [
  {
    actName: "Contracts Act 1950",
    actNo: "Act 136",
    sectionNo: "s. 10",
    sectionTitle: "What agreements are contracts",
    chunkText:
      "All agreements are contracts if they are made by the free consent of parties competent to contract, for a lawful consideration and with a lawful object, and are not hereby expressly declared to be void. Nothing herein contained shall affect any law in force in Malaysia and not hereby expressly repealed, by which any contract is required to be made in writing or in the presence of witnesses, or any law relating to the registration of documents.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_136/Act%20136.pdf",
    embedding: null,
  },
  {
    actName: "Contracts Act 1950",
    actNo: "Act 136",
    sectionNo: "s. 14",
    sectionTitle: "Free consent defined",
    chunkText:
      "Consent is said to be free when it is not caused by coercion, as defined in section 15; or undue influence, as defined in section 16; or fraud, as defined in section 17; or misrepresentation, as defined in section 18; or mistake, subject to sections 21, 22, and 23. Consent is said to be so caused when it would not have been given but for the existence of such coercion, undue influence, fraud, misrepresentation, or mistake.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_136/Act%20136.pdf",
    embedding: null,
  },
  {
    actName: "Personal Data Protection Act 2010",
    actNo: "Act 709",
    sectionNo: "s. 5",
    sectionTitle: "General principle",
    chunkText:
      "A data user shall not process personal data about a data subject unless the data subject has given his consent to the processing of the personal data; or the processing of the personal data is necessary for the performance of a contract to which the data subject is a party; for the taking of steps at the request of the data subject with a view to entering into a contract; for compliance with any legal obligation to which the data user is the subject, other than an obligation imposed by a contract; in order to protect the vital interests of the data subject; for the administration of justice; for the exercise of any functions conferred on any person by or under any law; or for the purposes of legitimate interests pursued by the data user or by a third party or parties to whom the data is disclosed, except where such interests are overridden by the interests of the data subject.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_709/Act%20709.pdf",
    embedding: null,
  },
];

// cosine re-exported from rag_helpers for backward-compat unit-test exports below.

// ---------------------------------------------------------------------------
// buildPrompt(question, topChunks) — assemble the full prompt text.
// ---------------------------------------------------------------------------
function buildPrompt(question, topChunks) {
  const systemInstruction =
    "You are LexiBot, a legal research assistant for Malaysian law. " +
    "Provide concise, factual answers grounded in the provided statute excerpts. " +
    "Cite the act and section when relevant. " +
    "End with the disclaimer: " +
    "'This is general information, not formal legal advice. " +
    "Consult a qualified lawyer for advice on your specific situation.'";

  const contextBlock = topChunks
    .map(
      (c) =>
        `### ${c.actName} ${c.sectionNo} — ${c.sectionTitle}\n${c.chunkText}\nSource: ${c.sourceUrl}`
    )
    .join("\n\n");

  return `${systemInstruction}\n\n--- Statute Excerpts ---\n\n${contextBlock}\n\n--- User Question ---\n\n${question}`;
}

// ---------------------------------------------------------------------------
// rankByQuestion(question, corpus, ai) — embed question, compute cosine
// similarity for each corpus chunk, return sorted (highest first), top-K.
// ---------------------------------------------------------------------------
async function rankByQuestion(question, corpus, ai) {
  const embedModel = requireEnv("GEMINI_EMBED_MODEL");

  // Embed the question
  let qVec;
  try {
    qVec = await _embedText(ai, embedModel, question);
  } catch (err) {
    throw new HttpsError(
      "internal",
      "Failed to obtain a valid embedding vector for the question."
    );
  }

  // Embed any corpus chunks that don't have pre-computed embeddings
  const resolved = await Promise.all(
    corpus.map(async (chunk) => {
      let vec = chunk.embedding;
      if (!Array.isArray(vec) || vec.length === 0) {
        const cEmbedResult = await ai.models.embedContent({
          model: embedModel,
          contents: chunk.chunkText,
        });
        vec =
          cEmbedResult.embeddings?.[0]?.values ??
          cEmbedResult.embedding?.values ??
          cEmbedResult.values;
      }
      return { chunk, vec };
    })
  );

  const TOP_K = Math.min(5, resolved.length);

  return resolved
    .map(({ chunk, vec }) => ({ chunk, sim: cosine(qVec, vec) }))
    .sort((a, b) => b.sim - a.sim)
    .slice(0, TOP_K)
    .map(({ chunk }) => chunk);
}

// ---------------------------------------------------------------------------
// generateLegalChatResponse — HTTPS callable
// ---------------------------------------------------------------------------
exports.generateLegalChatResponse = onCall(
  { invoker: "public" },
  async (request) => {
    // 1. Auth check
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to use LexiBot."
      );
    }
    const uid = request.auth.uid;

    // 2. Validate input
    const data = request.data || {};
    const question = String(data.question || "").trim();
    const roomId = String(data.roomId || "").trim();
    const attachmentStoragePath = data.attachmentStoragePath
      ? String(data.attachmentStoragePath).trim()
      : null;

    if (!question) {
      throw new HttpsError("invalid-argument", "question is required.");
    }
    if (!roomId) {
      throw new HttpsError("invalid-argument", "roomId is required.");
    }

    // 3. Participant check
    const db = getFirestore();
    const roomRef = db.collection("chat_rooms").doc(roomId);
    const roomSnap = await roomRef.get();

    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Chat room not found.");
    }

    const roomData = roomSnap.data();
    const participants = Array.isArray(roomData.participants)
      ? roomData.participants
      : [];

    if (!participants.includes(uid)) {
      throw new HttpsError(
        "permission-denied",
        "You are not a participant in this chat room."
      );
    }

    // 4. Optional image — load via Admin Storage SDK
    let imagePart = null;
    if (attachmentStoragePath) {
      // Path traversal guard: must start with chat_attachments/{roomId}/
      const expectedPrefix = `chat_attachments/${roomId}/`;
      if (!attachmentStoragePath.startsWith(expectedPrefix)) {
        throw new HttpsError(
          "invalid-argument",
          "attachmentStoragePath does not match the expected room path."
        );
      }

      try {
        const bucket = getStorage().bucket();
        const [fileBuffer] = await bucket
          .file(attachmentStoragePath)
          .download();
        const base64 = fileBuffer.toString("base64");

        // Infer MIME type from extension (basic heuristic; covers common image types)
        const ext = attachmentStoragePath.split(".").pop().toLowerCase();
        const mimeMap = {
          jpg: "image/jpeg",
          jpeg: "image/jpeg",
          png: "image/png",
          gif: "image/gif",
          webp: "image/webp",
          pdf: "application/pdf",
        };
        const mimeType = mimeMap[ext] || "application/octet-stream";

        imagePart = { inlineData: { mimeType, data: base64 } };
      } catch (err) {
        throw new HttpsError(
          "internal",
          "Failed to load attachment from Storage: " + err.message
        );
      }
    }

    // 5. Initialise Gemini client — env vars validated lazily here
    const apiKey = requireEnv("GEMINI_API_KEY");
    const chatModel = requireEnv("GEMINI_CHAT_MODEL");

    const ai = new GoogleGenAI({ apiKey });

    // 6. Load corpus — prefer Firestore law_corpus; fall back to MOCK_CORPUS
    let corpus = MOCK_CORPUS;
    try {
      const snap = await db.collection("law_corpus").limit(200).get();
      if (!snap.empty) {
        corpus = snap.docs.map((doc) => {
          const d = doc.data();
          return {
            actName: d.actName,
            actNo: d.actNo,
            sectionNo: d.sectionNo,
            sectionTitle: d.sectionTitle,
            chunkText: d.chunkText,
            sourceUrl: d.sourceUrl,
            // embedding is stored as a plain JS array in Firestore
            embedding: Array.isArray(d.embedding) ? d.embedding : null,
          };
        });
      } else {
        console.warn("[lexibot] law_corpus empty — using mock corpus");
      }
    } catch (err) {
      console.warn(
        "[lexibot] Failed to load law_corpus from Firestore, using mock corpus:",
        err.message
      );
    }

    // 7. Rank corpus by similarity to the question
    let topChunks;
    try {
      topChunks = await rankByQuestion(question, corpus, ai);
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError(
        "internal",
        "Failed to compute corpus similarity: " + err.message
      );
    }

    // 7. Build prompt
    const promptText = buildPrompt(question, topChunks);

    // 8. Assemble content parts for Gemini
    const contentParts = [{ text: promptText }];
    if (imagePart) {
      contentParts.push(imagePart);
    }

    // 9. Generate response
    let answerText;
    try {
      const result = await ai.models.generateContent({
        model: chatModel,
        contents: [{ role: "user", parts: contentParts }],
      });
      answerText =
        result.response?.text?.() ??
        result.candidates?.[0]?.content?.parts?.[0]?.text ??
        result.text;

      if (typeof answerText !== "string" || !answerText.trim()) {
        throw new Error("Empty response from model.");
      }
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError(
        "internal",
        "LexiBot could not generate a response at this time. Please try again."
      );
    }

    // 10. Return answer + sources
    return {
      answer: answerText.trim(),
      sources: topChunks.map((c) => ({
        actName: c.actName,
        sectionNo: c.sectionNo,
        sourceUrl: c.sourceUrl,
      })),
    };
  }
);

// Export helpers for unit testing
// cosine is re-exported from rag_helpers to keep backward-compat test imports
exports._cosine = cosine;
exports._buildPrompt = buildPrompt;
exports._rankByQuestion = rankByQuestion;
exports._MOCK_CORPUS = MOCK_CORPUS;
