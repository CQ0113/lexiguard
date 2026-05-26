const {
  createClient,
  getRagModel,
  requireStoreName,
} = require("./config");

async function run() {
  const question =
    process.argv.slice(2).join(" ").trim() ||
    "What do the indexed sources say about unpaid rent or rent distress?";
  const storeName = requireStoreName();
  const model = getRagModel();
  const ai = createClient();

  const response = await ai.models.generateContent({
    model,
    contents: question,
    config: {
      tools: [
        {
          fileSearch: {
            fileSearchStoreNames: [storeName],
          },
        },
      ],
    },
  });

  const grounding =
    response.candidates?.[0]?.groundingMetadata?.groundingChunks || [];
  console.log(`Model: ${model}`);
  console.log(`File Search store: ${storeName}`);
  console.log(`Grounding chunks: ${grounding.length}`);
  if (grounding.length === 0) {
    console.error(
      "UNSAFE RESPONSE DISCARDED: File Search supplied no grounding chunks.",
    );
    process.exitCode = 2;
    return;
  }
  console.log(response.text || "No answer text returned.");
}

run().catch((error) => {
  console.error(`Retrieval verification failed: ${error.message}`);
  process.exitCode = 1;
});
