const assert = require("node:assert/strict");
const test = require("node:test");

const {
  assessQuestion,
  escalationResponse,
  insufficientSourcesResponse,
} = require("../src/lexibot/safety");

test("allows an ordinary residential tenancy question", () => {
  assert.deepEqual(
    assessQuestion("Can my landlord retain my tenancy deposit?"),
    { scopeStatus: "in_scope", riskLevel: "low", reason: null, responseLanguage: "en" },
  );
});

test("allows common misspellings in a tenancy-agreement question", () => {
  assert.deepEqual(
    assessQuestion("what document shld i prepare for the teenancy agreement?"),
    { scopeStatus: "in_scope", riskLevel: "low", reason: null, responseLanguage: "en" },
  );
});

test("allows a landlord unpaid-rent question with a tenant typo", () => {
  assert.deepEqual(
    assessQuestion("My teenant dont want to pay me"),
    { scopeStatus: "in_scope", riskLevel: "low", reason: null, responseLanguage: "en" },
  );
});

test("allows a Bahasa Melayu residential tenancy question", () => {
  assert.deepEqual(
    assessQuestion("Tuan rumah enggan pulangkan deposit sewa saya."),
    { scopeStatus: "in_scope", riskLevel: "low", reason: null, responseLanguage: "ms" },
  );
});

test("allows a Chinese residential tenancy question", () => {
  assert.deepEqual(
    assessQuestion("房东不肯退还我的租房押金。"),
    { scopeStatus: "in_scope", riskLevel: "low", reason: null, responseLanguage: "zh" },
  );
});

test("escalates lockouts before retrieval", () => {
  const result = assessQuestion("My landlord changed the locks today.");
  assert.equal(result.scopeStatus, "urgent_escalation");
  assert.equal(result.riskLevel, "high");
});

test("escalates a Bahasa Melayu lockout and localizes its response", () => {
  const result = assessQuestion("Tuan rumah menukar kunci rumah sewa saya.");
  assert.equal(result.scopeStatus, "urgent_escalation");
  assert.equal(result.responseLanguage, "ms");
  assert.match(escalationResponse(result).answer.shortAnswer, /peguam Malaysia/);
});

test("escalates a Chinese court document and localizes its response", () => {
  const result = assessQuestion("我收到房屋租赁案件的法院传票。");
  assert.equal(result.scopeStatus, "urgent_escalation");
  assert.equal(result.responseLanguage, "zh");
  assert.match(escalationResponse(result).answer.shortAnswer, /马来西亚律师/);
});

test("escalates requests to sue a tenant", () => {
  const result = assessQuestion("My teenant dont want to pay me, how can i sue them?");
  assert.equal(result.scopeStatus, "urgent_escalation");
  assert.equal(result.riskLevel, "high");
});

test("rejects Sabah questions from the Peninsular MVP", () => {
  const result = assessQuestion("My rented apartment is in Sabah.");
  assert.equal(result.scopeStatus, "out_of_scope");
  assert.equal(result.riskLevel, "high");
});

test("rejects unrelated Malaysian law questions", () => {
  const result = assessQuestion("Can I make a will for my family?");
  assert.equal(result.scopeStatus, "out_of_scope");
});

test("uses detected language for insufficient-source responses", () => {
  const assessment = assessQuestion("Penyewa saya tidak membayar sewa.");
  const response = insufficientSourcesResponse(assessment);
  assert.equal(response.responseLanguage, "ms");
  assert.match(response.answer.shortAnswer, /sumber penyewaan/);
});
