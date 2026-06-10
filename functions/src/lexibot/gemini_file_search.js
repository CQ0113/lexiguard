const { GoogleGenAI } = require("@google/genai");

const {
  SYSTEM_INSTRUCTION,
  questionPrompt,
} = require("./prompt");

function metadataMap(customMetadata) {
  const metadata = {};
  for (const entry of customMetadata || []) {
    if (entry.key) {
      metadata[entry.key] = entry.stringValue || entry.numericValue || null;
    }
  }
  return metadata;
}

function extractCitations(groundingChunks) {
  const bySource = new Map();
  for (const chunk of groundingChunks) {
    const context = chunk.retrievedContext || {};
    const metadata = metadataMap(context.customMetadata);
    const key = metadata.source_id || context.title;
    if (!key || bySource.has(key)) continue;
    bySource.set(key, {
      title: metadata.title || context.title || "Approved source",
      sourceId: metadata.source_id || null,
      sourceUrl: metadata.source_url || null,
      versionId: metadata.version_id || null,
    });
  }
  return Array.from(bySource.values());
}

function parseJsonObject(text) {
  const raw = String(text || "").trim();
  if (!raw) return null;

  const withoutFence = raw
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  try {
    return JSON.parse(withoutFence);
  } catch (_error) {
    const start = withoutFence.indexOf("{");
    const end = withoutFence.lastIndexOf("}");
    if (start < 0 || end <= start) return null;

    try {
      return JSON.parse(withoutFence.slice(start, end + 1));
    } catch (_nestedError) {
      return null;
    }
  }
}

async function generateGroundedAnswer({
  apiKey,
  question,
  responseLanguage,
  model,
  fileSearchStoreName,
}) {
  const ai = new GoogleGenAI({ apiKey });
  const response = await ai.models.generateContent({
    model,
    contents: questionPrompt(question, responseLanguage),
    config: {
      systemInstruction: SYSTEM_INSTRUCTION,
      tools: [
        {
          fileSearch: {
            fileSearchStoreNames: [fileSearchStoreName],
          },
        },
      ],
    },
  });

  const groundingChunks =
    response.candidates?.[0]?.groundingMetadata?.groundingChunks || [];
  const citations = extractCitations(groundingChunks);
  if (groundingChunks.length === 0 || citations.length === 0) {
    return {
      status: "insufficient_sources",
      citations: [],
      groundingChunkCount: 0,
      answer: null,
    };
  }

  const answer = parseJsonObject(response.text);
  if (!answer) {
    return {
      status: "insufficient_sources",
      citations,
      groundingChunkCount: groundingChunks.length,
      answer: null,
    };
  }

  return {
    status: "answered",
    citations,
    groundingChunkCount: groundingChunks.length,
    answer,
  };
}

module.exports = {
  extractCitations,
  generateGroundedAnswer,
  parseJsonObject,
};
