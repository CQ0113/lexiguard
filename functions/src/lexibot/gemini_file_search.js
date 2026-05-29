const { GoogleGenAI } = require("@google/genai");

const {
  RESPONSE_SCHEMA,
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

async function generateGroundedAnswer({
  apiKey,
  question,
  model,
  fileSearchStoreName,
}) {
  const ai = new GoogleGenAI({ apiKey });
  const response = await ai.models.generateContent({
    model,
    contents: questionPrompt(question),
    config: {
      systemInstruction: SYSTEM_INSTRUCTION,
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
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

  let answer;
  try {
    answer = JSON.parse(response.text || "{}");
  } catch (_error) {
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
};
