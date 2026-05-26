const assert = require("node:assert/strict");
const test = require("node:test");

const { questionPrompt, SYSTEM_INSTRUCTION } = require("../src/lexibot/prompt");

test("requests Bahasa Melayu output for Malay questions", () => {
  const prompt = questionPrompt("Bolehkah deposit sewa ditahan?", "ms");
  assert.match(prompt, /Required answer language: Bahasa Melayu/);
});

test("requests Chinese output for Chinese questions", () => {
  const prompt = questionPrompt("房东可以扣留押金吗？", "zh");
  assert.match(prompt, /Required answer language: Chinese/);
});

test("requires user-facing fields to follow the requested language", () => {
  assert.match(SYSTEM_INSTRUCTION, /user-facing answer field values/);
});
