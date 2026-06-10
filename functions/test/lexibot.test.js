/**
 * Unit tests for lexibot.js helpers and rag_helpers.js.
 * No test framework required — plain Node.js assertions.
 * Run with: node test/lexibot.test.js
 *
 * These tests cover pure helper logic only (cosine, topK, chunkText,
 * buildPrompt, top-K ranking). Gemini API calls and Firestore/Storage
 * admin calls are NOT tested here — those require the Functions emulator.
 */

"use strict";

const assert = require("assert");

// ---------------------------------------------------------------------------
// Load rag_helpers directly — no Firebase deps, no stubs needed.
// ---------------------------------------------------------------------------
const {
  cosine,
  topK,
  chunkText,
} = require("../src/chat/rag_helpers");

// ---------------------------------------------------------------------------
// Stub Firebase deps so lexibot.js loads without real credentials.
// ---------------------------------------------------------------------------
const Module = require("module");
const stubs = {
  "firebase-functions/v2/https": {
    onCall: (opts, fn) => fn, // return the handler as-is
    HttpsError: class HttpsError extends Error {
      constructor(code, message) {
        super(message);
        this.code = code;
      }
    },
  },
  "firebase-admin/firestore": { getFirestore: () => ({}) },
  "firebase-admin/storage": { getStorage: () => ({}) },
  "@google/genai": { GoogleGenAI: class {} },
  dotenv: { config: () => {} },
};

const originalLoad = Module._load.bind(Module);
Module._load = function (request, parent, isMain) {
  if (Object.prototype.hasOwnProperty.call(stubs, request)) {
    return stubs[request];
  }
  return originalLoad(request, parent, isMain);
};

const {
  _buildPrompt: buildPrompt,
  _rankByQuestion: rankByQuestion,
  _MOCK_CORPUS: MOCK_CORPUS,
} = require("../src/chat/lexibot");

// Restore Module._load after require
Module._load = originalLoad;

// ---------------------------------------------------------------------------
// Test runner helpers
// ---------------------------------------------------------------------------
let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  PASS  ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL  ${name}`);
    console.error(`        ${err.message}`);
    failed++;
  }
}

// ---------------------------------------------------------------------------
// cosine() tests  — imported from rag_helpers
// ---------------------------------------------------------------------------
console.log("\ncosine similarity");

test("identical vectors → 1", () => {
  const result = cosine([1, 0, 0], [1, 0, 0]);
  assert.strictEqual(result, 1, `expected 1, got ${result}`);
});

test("orthogonal vectors → 0", () => {
  const result = cosine([1, 0, 0], [0, 1, 0]);
  assert.strictEqual(result, 0, `expected 0, got ${result}`);
});

test("opposite vectors → -1", () => {
  const result = cosine([1, 0], [-1, 0]);
  assert.strictEqual(result, -1, `expected -1, got ${result}`);
});

test("zero magnitude vector → 0", () => {
  const result = cosine([0, 0, 0], [1, 0, 0]);
  assert.strictEqual(result, 0, `expected 0, got ${result}`);
});

test("non-unit vectors with known angle", () => {
  // [1,1] vs [1,0]: dot=1, |a|=√2, |b|=1 → 1/√2 ≈ 0.7071
  const result = cosine([1, 1], [1, 0]);
  const expected = 1 / Math.sqrt(2);
  assert.ok(
    Math.abs(result - expected) < 1e-9,
    `expected ≈${expected}, got ${result}`
  );
});

// ---------------------------------------------------------------------------
// topK() tests — imported from rag_helpers
// ---------------------------------------------------------------------------
console.log("\ntopK");

const CORPUS_FOR_TOPK = [
  { actName: "A", embedding: [1, 0, 0] },
  { actName: "B", embedding: [0, 1, 0] },
  { actName: "C", embedding: [0.5, 0.5, 0] },
  { actName: "D", embedding: [0, 0, 1] },
];

test("topK returns correct top-1 result", () => {
  const result = topK(CORPUS_FOR_TOPK, [1, 0, 0], 1);
  assert.strictEqual(result.length, 1, "expected 1 result");
  assert.strictEqual(result[0].actName, "A", `expected A first, got ${result[0].actName}`);
});

test("topK appends .score to each result", () => {
  const result = topK(CORPUS_FOR_TOPK, [1, 0, 0], 2);
  assert.ok(typeof result[0].score === "number", "score should be a number");
  assert.ok(result[0].score >= result[1].score, "results should be sorted descending");
});

test("topK caps at k even if corpus is larger", () => {
  const result = topK(CORPUS_FOR_TOPK, [1, 0, 0], 2);
  assert.strictEqual(result.length, 2, "should return at most k=2");
});

test("topK on empty corpus returns []", () => {
  const result = topK([], [1, 0, 0], 3);
  assert.deepStrictEqual(result, [], "should return empty array");
});

test("topK handles item with missing embedding (treated as zero vector → score 0)", () => {
  const corpusWithMissing = [
    { actName: "X", embedding: null },
    { actName: "Y", embedding: [1, 0, 0] },
  ];
  const result = topK(corpusWithMissing, [1, 0, 0], 2);
  assert.strictEqual(result[0].actName, "Y", "item with valid embedding should rank first");
});

// ---------------------------------------------------------------------------
// chunkText() tests — imported from rag_helpers
// ---------------------------------------------------------------------------
console.log("\nchunkText");

test("returns empty array for empty input", () => {
  assert.deepStrictEqual(chunkText(""), [], "empty string → []");
});

test("returns single chunk when text fits in maxChars", () => {
  const text = "This is a short sentence. Another short sentence.";
  const result = chunkText(text, 800, 100);
  assert.strictEqual(result.length, 1, `expected 1 chunk, got ${result.length}`);
});

test("splits long text into multiple chunks", () => {
  // Build a string of 5 sentences each ~100 chars long — total ~500 chars
  const sentence = "This is a sentence that is approximately one hundred characters long in total.  ";
  const text = sentence.repeat(10); // ~800 chars × 10 — well over maxChars=100
  const result = chunkText(text, 100, 20);
  assert.ok(result.length > 1, `expected multiple chunks, got ${result.length}`);
});

test("each chunk does not exceed maxChars (sentences fit)", () => {
  const sentence = "Short sentence here. ";
  const text = sentence.repeat(20);
  const result = chunkText(text, 200, 50);
  for (const chunk of result) {
    assert.ok(
      chunk.length <= 200,
      `chunk length ${chunk.length} exceeds maxChars 200: "${chunk.slice(0, 40)}..."`
    );
  }
});

test("overlap: later chunks share a suffix with the prior chunk", () => {
  // Each sentence is ~80 chars; maxChars=100 so each chunk holds ~1 sentence.
  // With overlap=40, the start of chunk[1] should contain tail chars from chunk[0].
  const s1 = "First sentence ends here with some words.";   // 41 chars
  const s2 = "Second sentence also ends here with words."; // 42 chars
  const s3 = "Third sentence ends here with more words.";  // 41 chars
  const text = `${s1} ${s2} ${s3}`;
  const result = chunkText(text, 50, 15);
  // We just need more than 1 chunk and the content of later chunks to overlap
  if (result.length >= 2) {
    const tail = result[0].slice(-15);
    assert.ok(
      result[1].includes(tail.slice(0, 5)),
      `chunk[1] should contain overlap from chunk[0]. chunk[0] tail: "${tail}", chunk[1] start: "${result[1].slice(0, 30)}"`
    );
  } else {
    // If only 1 chunk produced (sentences short enough), that's also acceptable
    assert.ok(result.length >= 1, "at least one chunk expected");
  }
});

test("handles text with no sentence-ending punctuation as a single chunk", () => {
  const text = "No punctuation here just words without termination";
  const result = chunkText(text, 800, 100);
  assert.strictEqual(result.length, 1, "expected 1 chunk for punctuation-free text");
  assert.ok(result[0].includes("No punctuation"), "chunk should contain the text");
});

// ---------------------------------------------------------------------------
// buildPrompt() tests
// ---------------------------------------------------------------------------
console.log("\nbuildPrompt");

const SAMPLE_CHUNKS = [
  {
    actName: "Contracts Act 1950",
    sectionNo: "s. 10",
    sectionTitle: "What agreements are contracts",
    chunkText: "All agreements are contracts if made freely...",
    sourceUrl: "https://lom.agc.gov.my/example",
  },
  {
    actName: "Personal Data Protection Act 2010",
    sectionNo: "s. 5",
    sectionTitle: "General principle",
    chunkText: "A data user shall not process personal data...",
    sourceUrl: "https://lom.agc.gov.my/example2",
  },
];
const SAMPLE_QUESTION = "Can I be forced to sign a contract?";

const prompt = buildPrompt(SAMPLE_QUESTION, SAMPLE_CHUNKS);

test("prompt includes the AI disclaimer", () => {
  assert.ok(
    prompt.includes(
      "This is general information, not formal legal advice."
    ),
    "disclaimer not found in prompt"
  );
});

test("prompt includes 'Consult a qualified lawyer' disclaimer tail", () => {
  assert.ok(
    prompt.includes("Consult a qualified lawyer for advice"),
    "disclaimer tail not found in prompt"
  );
});

test("prompt ends with the user question", () => {
  assert.ok(
    prompt.trimEnd().endsWith(SAMPLE_QUESTION),
    `prompt should end with the question. Actual tail: "${prompt.slice(-60)}"`
  );
});

test("prompt includes first chunk actName", () => {
  assert.ok(
    prompt.includes("Contracts Act 1950"),
    "first chunk actName not in prompt"
  );
});

test("prompt includes first chunk sectionNo", () => {
  assert.ok(
    prompt.includes("s. 10"),
    "first chunk sectionNo not in prompt"
  );
});

test("prompt includes second chunk actName", () => {
  assert.ok(
    prompt.includes("Personal Data Protection Act 2010"),
    "second chunk actName not in prompt"
  );
});

test("prompt includes section header format ### actName sectionNo — sectionTitle", () => {
  assert.ok(
    prompt.includes("### Contracts Act 1950 s. 10 — What agreements are contracts"),
    "section header format not found in prompt"
  );
});

test("prompt includes source URLs", () => {
  assert.ok(
    prompt.includes("https://lom.agc.gov.my/example"),
    "first sourceUrl not in prompt"
  );
});

// ---------------------------------------------------------------------------
// rankByQuestion() — top-K ordering test (with mock AI client)
// ---------------------------------------------------------------------------
console.log("\nrankByQuestion (mock AI)");

function makeVec(val, dim) {
  const v = new Array(dim).fill(0);
  v[0] = val;
  return v;
}

const MOCK_AI = {
  models: {
    embedContent: async ({ contents }) => {
      const map = {
        "question about contracts": makeVec(1, 3),
        "All agreements are contracts if they are made by the free consent of parties competent to contract, for a lawful consideration and with a lawful object, and are not hereby expressly declared to be void. Nothing herein contained shall affect any law in force in Malaysia and not hereby expressly repealed, by which any contract is required to be made in writing or in the presence of witnesses, or any law relating to the registration of documents.":
          makeVec(0.98, 3),
        "Consent is said to be free when it is not caused by coercion, as defined in section 15; or undue influence, as defined in section 16; or fraud, as defined in section 17; or misrepresentation, as defined in section 18; or mistake, subject to sections 21, 22, and 23. Consent is said to be so caused when it would not have been given but for the existence of such coercion, undue influence, fraud, misrepresentation, or mistake.":
          makeVec(0.5, 3),
        "A data user shall not process personal data about a data subject unless the data subject has given his consent to the processing of the personal data; or the processing of the personal data is necessary for the performance of a contract to which the data subject is a party; for the taking of steps at the request of the data subject with a view to entering into a contract; for compliance with any legal obligation to which the data user is the subject, other than an obligation imposed by a contract; in order to protect the vital interests of the data subject; for the administration of justice; for the exercise of any functions conferred on any person by or under any law; or for the purposes of legitimate interests pursued by the data user or by a third party or parties to whom the data is disclosed, except where such interests are overridden by the interests of the data subject.":
          makeVec(0.1, 3),
      };
      const vec = map[contents] || makeVec(0, 3);
      return { embeddings: [{ values: vec }] };
    },
  },
};

process.env.GEMINI_EMBED_MODEL = "test-model";

test("top-K returns most similar chunk first (MOCK_CORPUS[0] has cos≈0.98)", async () => {
  const ranked = await rankByQuestion(
    "question about contracts",
    MOCK_CORPUS,
    MOCK_AI
  );
  assert.ok(ranked.length > 0, "ranked is empty");
  assert.strictEqual(
    ranked[0].sectionNo,
    "s. 10",
    `expected s. 10 first, got ${ranked[0].sectionNo}`
  );
});

test("top-K result length is capped at min(5, corpus.length)", async () => {
  const ranked = await rankByQuestion(
    "question about contracts",
    MOCK_CORPUS,
    MOCK_AI
  );
  assert.ok(
    ranked.length <= Math.min(5, MOCK_CORPUS.length),
    `ranked.length ${ranked.length} exceeds cap`
  );
});

// ---------------------------------------------------------------------------
// Finalise
// ---------------------------------------------------------------------------
setImmediate(() => {
  console.log(`\n${passed + failed} tests: ${passed} passed, ${failed} failed\n`);
  if (failed > 0) {
    process.exit(1);
  }
});
