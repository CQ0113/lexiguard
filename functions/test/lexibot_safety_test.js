const assert = require("node:assert/strict");
const test = require("node:test");

const { assessQuestion } = require("../src/lexibot/safety");

test("allows an ordinary residential tenancy question", () => {
  assert.deepEqual(
    assessQuestion("Can my landlord retain my tenancy deposit?"),
    { scopeStatus: "in_scope", riskLevel: "low", reason: null },
  );
});

test("escalates lockouts before retrieval", () => {
  const result = assessQuestion("My landlord changed the locks today.");
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
