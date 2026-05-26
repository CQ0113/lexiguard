const URGENT_PATTERNS = [
  /\b(lock(?:ed)?\s*out|changed?\s+(?:the\s+)?locks?)\b/i,
  /\b(force(?:d)?\s+entry|broke?\s+in|belongings?\s+(?:removed|thrown))\b/i,
  /\b(threat(?:en|ened|s)?|violence|assault|danger|unsafe)\b/i,
  /\b(police|arrest(?:ed)?|criminal|crime)\b/i,
  /\b(court|summons|writ|hearing|deadline|tribunal|lawsuit|sue|suing)\b/i,
  /\b(file|start|commence)\s+(?:a\s+)?(?:claim|case|proceedings?)\b/i,
  /\b(cut|disconnect(?:ed)?|shut\s+off)\b.*\b(electricity|water|utilities?)\b/i,
];

const OUT_OF_SCOPE_PATTERNS = [
  /\b(sabah|sarawak)\b/i,
  /\b(syariah|shariah)\b/i,
  /\b(divorce|custody|inheritance|will|probate)\b/i,
  /\b(criminal|arrest(?:ed)?|police)\b/i,
];

const TENANCY_PATTERNS = [
  /\b(tenant|landlord|tenancy|rental|rent|rented|lease|premises)\b/i,
  /\b(security\s+deposit|utility\s+deposit|deposit|evict(?:ion)?|distress)\b/i,
  /\b(condo|minium|strata|management\s+body|joint\s+management)\b/i,
];

function normalizeTenancyTerms(question) {
  return String(question || "")
    .replace(/\b(teenant|tenent|tennant)\b/gi, "tenant")
    .replace(/\b(teenancy|tenency|tennacy)\b/gi, "tenancy")
    .trim();
}

function assessQuestion(question) {
  const text = normalizeTenancyTerms(question);

  if (URGENT_PATTERNS.some((pattern) => pattern.test(text))) {
    return {
      scopeStatus: "urgent_escalation",
      riskLevel: "high",
      reason: "The question may involve immediate safety, court, criminal, or deadline risk.",
    };
  }

  if (OUT_OF_SCOPE_PATTERNS.some((pattern) => pattern.test(text))) {
    return {
      scopeStatus: "out_of_scope",
      riskLevel: "high",
      reason: "This MVP only covers Peninsular Malaysia residential tenancy information.",
    };
  }

  if (!TENANCY_PATTERNS.some((pattern) => pattern.test(text))) {
    return {
      scopeStatus: "out_of_scope",
      riskLevel: "medium",
      reason: "This question does not appear to concern residential tenancy.",
    };
  }

  return {
    scopeStatus: "in_scope",
    riskLevel: "low",
    reason: null,
  };
}

function escalationResponse(assessment) {
  const urgent = assessment.scopeStatus === "urgent_escalation";
  return {
    status: assessment.scopeStatus,
    scopeStatus: assessment.scopeStatus,
    riskLevel: assessment.riskLevel,
    answer: {
      shortAnswer: urgent
        ? "This situation may need urgent help from a qualified Malaysian lawyer."
        : "LexiBot cannot answer this question within its tenancy-law MVP scope.",
      whatTheSourceSays: "",
      whatThisMeans: assessment.reason,
      evidenceToKeep: [],
      whatYouCanDoNext: urgent
        ? ["Contact a Malaysian lawyer or appropriate emergency/legal-aid service promptly."]
        : ["Speak with a qualified Malaysian lawyer for advice on this issue."],
      sourcesUsed: [],
      needALawyer: "Yes. LexiBot provides general legal information only.",
    },
    citations: [],
  };
}

module.exports = {
  assessQuestion,
  escalationResponse,
};
