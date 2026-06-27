const {
  createClient,
  getStoreDisplayName,
  writeState,
} = require("./config");

async function findStoreByDisplayName(ai, displayName) {
  const stores = await ai.fileSearchStores.list();
  for await (const store of stores) {
    if (store.displayName === displayName) {
      return store;
    }
  }
  return null;
}

async function run() {
  const ai = createClient();
  const displayName = getStoreDisplayName();
  let store = await findStoreByDisplayName(ai, displayName);

  if (store) {
    console.log(`Reusing existing File Search store: ${store.name}`);
  } else {
    store = await ai.fileSearchStores.create({
      config: {
        displayName,
        embeddingModel: "models/gemini-embedding-2",
      },
    });
    console.log(`Created File Search store: ${store.name}`);
  }

  writeState({
    fileSearchStoreName: store.name,
    fileSearchStoreDisplayName: displayName,
    embeddingModel: "models/gemini-embedding-2",
  });
  console.log("Saved non-secret local store configuration.");
}

run().catch((error) => {
  console.error(`Store setup failed: ${error.message}`);
  process.exitCode = 1;
});
