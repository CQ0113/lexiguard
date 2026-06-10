const assert = require("node:assert/strict");
const test = require("node:test");

const { resolveApprovedCitations } = require("../src/lexibot/citation_resolver");

function mockDb() {
  const source = {
    id: "distress_act_1951",
    data: () => ({
      status: "active",
      title: "Distress Act 1951",
      activeVersionId: "2026-05-26_download",
    }),
    ref: {
      collection: () => ({
        doc: () => ({
          get: async () => ({
            exists: true,
            data: () => ({
              reviewStatus: "approved",
              sourceUrl: "https://official.example/act255.pdf",
            }),
          }),
        }),
      }),
    },
  };
  return {
    collection: () => ({
      where: () => ({
        get: async () => ({ docs: [source] }),
      }),
    }),
  };
}

test("maps a Gemini document title to approved source metadata", async () => {
  const result = await resolveApprovedCitations(mockDb(), [
    { title: "Distress Act 1951 (2026-05-26_download)" },
  ]);

  assert.deepEqual(result, [
    {
      sourceId: "distress_act_1951",
      title: "Distress Act 1951",
      versionId: "2026-05-26_download",
      sourceUrl: "https://official.example/act255.pdf",
    },
  ]);
});

test("does not expose an unresolved grounding title", async () => {
  const result = await resolveApprovedCitations(mockDb(), [
    { title: "Unknown external document" },
  ]);
  assert.deepEqual(result, []);
});
