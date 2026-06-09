const RESPONSE_SCHEMA = {
  type: "object",
  required: [
    "shortAnswer",
    "whatTheSourceSays",
    "whatThisMeans",
    "evidenceToKeep",
    "whatYouCanDoNext",
    "sourcesUsed",
    "needALawyer",
  ],
  properties: {
    shortAnswer: { type: "string" },
    whatTheSourceSays: { type: "string" },
    whatThisMeans: { type: "string" },
    evidenceToKeep: { type: "array", items: { type: "string" } },
    whatYouCanDoNext: { type: "array", items: { type: "string" } },
    sourcesUsed: { type: "array", items: { type: "string" } },
    needALawyer: { type: "string" },
  },
};

const SYSTEM_INSTRUCTION = `
You are LexiBot, a Malaysian residential tenancy legal-information assistant.
This MVP covers only Peninsular Malaysia residential tenancy issues.

Answer only from retrieved approved Malaysian tenancy source documents.
Do not use unstated legal knowledge, general memory, or non-Malaysian law.
Do not claim to be a lawyer and do not provide personalised legal advice.
Do not tell a user to sign, admit liability, ignore deadlines, or commence proceedings.
If retrieved documents do not directly support an answer, state that the available
sources are insufficient and recommend speaking with a Malaysian lawyer.

function questionPrompt(question) {
Use simple language. Write all user-facing answer field values in the requested
answer language. Keep official statute/source titles in their original form.
The Sources Used field must name only retrieved sources.
`.trim();

const LANGUAGE_NAMES = {
  en: "English",
  ms: "Bahasa Melayu",
  zh: "Chinese",
};

function questionPrompt(question, responseLanguage = "en") {
  const answerLanguage = LANGUAGE_NAMES[responseLanguage] || LANGUAGE_NAMES.en;
  return [
    "Answer this client question using only retrieved approved sources:",
    question,
    "",
    `Required answer language: ${answerLanguage}.`,
    "Where the question depends on tenancy agreement terms, clearly say so.",
  ].join("\n");
}

module.exports = {
  RESPONSE_SCHEMA,
  SYSTEM_INSTRUCTION,
  questionPrompt,
};
