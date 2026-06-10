/**
 * rag_helpers.js — Shared RAG utilities for LexiBot.
 *
 * Extracted from lexibot.js so they can be unit-tested independently and
 * re-used by corpus_seed.js.
 *
 * All exports use CommonJS (require/module.exports) to match the existing
 * functions/ style.
 */

"use strict";

// ---------------------------------------------------------------------------
// cosine(a, b) — cosine similarity between two numeric arrays.
// Returns 0 if either vector has zero magnitude or lengths differ.
// ---------------------------------------------------------------------------
function cosine(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) {
    return 0;
  }
  let dot = 0;
  let magA = 0;
  let magB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    magA += a[i] * a[i];
    magB += b[i] * b[i];
  }
  const denom = Math.sqrt(magA) * Math.sqrt(magB);
  return denom === 0 ? 0 : dot / denom;
}

// ---------------------------------------------------------------------------
// topK(corpus, queryVec, k) — returns the top-k corpus items most similar
// to queryVec, sorted highest similarity first.
// Each corpus item must have an `.embedding` field (array of numbers).
// Each returned item has a `.score` field appended (does not mutate original).
// ---------------------------------------------------------------------------
function topK(corpus, queryVec, k) {
  if (!Array.isArray(corpus) || corpus.length === 0) {
    return [];
  }
  const cap = Math.min(k, corpus.length);
  return corpus
    .map((item) => ({
      ...item,
      score: cosine(Array.isArray(item.embedding) ? item.embedding : [], queryVec),
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, cap);
}

// ---------------------------------------------------------------------------
// embedText(ai, modelName, text) — calls the @google/genai embedding API.
// Handles multiple response shapes with fallback paths.
// Throws clearly if no usable vector is found.
// ---------------------------------------------------------------------------
async function embedText(ai, modelName, text) {
  const result = await ai.models.embedContent({
    model: modelName,
    contents: text,
  });

  const vec =
    result.embeddings?.[0]?.values ??
    result.embedding?.values ??
    result.values;

  if (!Array.isArray(vec) || vec.length === 0) {
    const preview = JSON.stringify(result || {}).slice(0, 300);
    throw new Error(
      `embedText: could not extract embedding vector from response. ` +
        `Model: ${modelName}. Response keys: ${Object.keys(result || {}).join(", ")}. ` +
        `Preview: ${preview}`
    );
  }

  return vec;
}

// ---------------------------------------------------------------------------
// chunkText(text, maxChars, overlap) — splits text into overlapping chunks.
//
// Strategy:
//   1. Find sentence boundaries (., !, ? followed by whitespace or end-of-string).
//   2. Accumulate sentences into chunks up to maxChars characters.
//   3. When a new chunk would exceed maxChars, start a new chunk with the last
//      `overlap` characters of the previous chunk prepended.
//   4. Returns string[].
// ---------------------------------------------------------------------------
function chunkText(text, maxChars = 800, overlap = 100) {
  if (!text || typeof text !== "string") {
    return [];
  }

  // Split on sentence-ending punctuation followed by whitespace or end-of-string.
  // Keep the delimiter attached to the sentence it ends.
  const sentenceRe = /(?<=[.!?])(?=\s|$)/g;
  const sentences = text.split(sentenceRe).map((s) => s.trim()).filter(Boolean);

  const chunks = [];
  let current = "";

  for (const sentence of sentences) {
    const candidate = current ? current + " " + sentence : sentence;

    if (candidate.length <= maxChars) {
      current = candidate;
    } else {
      // Flush current chunk
      if (current) {
        chunks.push(current);
        // Start next chunk with overlap from the end of the previous chunk
        const tail = current.slice(-overlap);
        current = tail ? tail + " " + sentence : sentence;
      } else {
        // A single sentence exceeds maxChars — force-split it character-wise
        let remaining = sentence;
        while (remaining.length > maxChars) {
          chunks.push(remaining.slice(0, maxChars));
          const tailSlice = remaining.slice(maxChars - overlap, maxChars);
          remaining = tailSlice + remaining.slice(maxChars);
        }
        current = remaining;
      }
    }
  }

  if (current.trim()) {
    chunks.push(current.trim());
  }

  return chunks;
}

module.exports = {
  cosine,
  topK,
  embedText,
  chunkText,
};
