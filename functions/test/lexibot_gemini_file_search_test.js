const assert = require("node:assert/strict");
const test = require("node:test");

const { parseJsonObject } = require("../src/lexibot/gemini_file_search");

test("parses raw JSON answer text", () => {
  assert.deepEqual(parseJsonObject('{"shortAnswer":"Yes"}'), {
    shortAnswer: "Yes",
  });
});

test("parses fenced JSON answer text", () => {
  assert.deepEqual(
    parseJsonObject('```json\n{"shortAnswer":"Yes"}\n```'),
    { shortAnswer: "Yes" },
  );
});

test("returns null for non-JSON answer text", () => {
  assert.equal(parseJsonObject("No structured answer."), null);
});
