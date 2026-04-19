const HONORIFICS = new Set([
  "pn",
  "en",
  "encik",
  "puan",
  "mr",
  "mrs",
  "ms",
  "dr",
  "dato",
  "datuk",
  "datin",
  "hj",
  "haji",
  "hajah",
]);

function normalizeText(value) {
  const cleaned = String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (!cleaned) {
    return "";
  }

  return cleaned
    .split(" ")
    .filter((token) => token && !HONORIFICS.has(token))
    .join(" ");
}

function tokenize(value) {
  const normalized = normalizeText(value);
  if (!normalized) {
    return [];
  }

  return normalized.split(" ").filter(Boolean);
}

function tokenSimilarity(a, b) {
  const left = new Set(tokenize(a));
  const right = new Set(tokenize(b));

  if (!left.size || !right.size) {
    return 0;
  }

  let intersection = 0;
  for (const token of left) {
    if (right.has(token)) {
      intersection += 1;
    }
  }

  const union = new Set([...left, ...right]).size;
  if (!union) {
    return 0;
  }

  return intersection / union;
}

function startsWithSameLeadToken(a, b) {
  const left = tokenize(a);
  const right = tokenize(b);
  return left.length > 0 && right.length > 0 && left[0] === right[0];
}

function scoreName(candidate, profile) {
  const profileName = normalizeText(profile.legalFullName);
  const candidateName = normalizeText(candidate.name);

  if (!profileName || !candidateName) {
    return 0;
  }

  if (profileName === candidateName) {
    return 1;
  }

  let score = tokenSimilarity(profileName, candidateName);
  if (startsWithSameLeadToken(profileName, candidateName)) {
    score += 0.08;
  }

  return Math.min(score, 1);
}

function scoreFirm(candidate, profile) {
  if (!profile.firmName) {
    return 0.5;
  }

  const firmScore = tokenSimilarity(profile.firmName, candidate.firm);
  if (firmScore > 0) {
    return firmScore;
  }

  const candidateFirm = normalizeText(candidate.firm);
  const profileFirm = normalizeText(profile.firmName);

  if (!candidateFirm || !profileFirm) {
    return 0;
  }

  return candidateFirm.includes(profileFirm) ||
    profileFirm.includes(candidateFirm)
    ? 0.75
    : 0;
}

function normalizeState(value) {
  return normalizeText(value).replace(/^wilayah persekutuan\s+/, "");
}

function scoreState(candidate, profile) {
  if (!profile.practiceState) {
    return 0.5;
  }

  const profileState = normalizeState(profile.practiceState);
  const candidateState = normalizeState(candidate.state);

  if (!profileState || !candidateState) {
    return 0;
  }

  if (profileState === candidateState) {
    return 1;
  }

  return candidateState.includes(profileState) ||
    profileState.includes(candidateState)
    ? 0.8
    : 0;
}

function isCandidateInactive(candidate) {
  const statusText = normalizeText(
    candidate.statusText || candidate.status || "",
  );

  if (!statusText) {
    return false;
  }

  if (candidate.isActive === true) {
    return false;
  }

  return /(suspend|struck|inactive|ceased|expired|terminated|disbar|revoked)/.test(
    statusText,
  );
}

function scoreCandidate(candidate, profile) {
  const nameScore = scoreName(candidate, profile);
  const firmScore = scoreFirm(candidate, profile);
  const stateScore = scoreState(candidate, profile);

  const totalScore = nameScore * 0.55 + firmScore * 0.25 + stateScore * 0.2;

  return {
    candidate,
    nameScore,
    firmScore,
    stateScore,
    totalScore,
    inactive: isCandidateInactive(candidate),
  };
}

function buildVerificationDecision({ profile, adapterResult }) {
  if (profile.jurisdiction && profile.jurisdiction !== "peninsular") {
    return {
      verificationStatus: "manual_review_required",
      verificationProvider: "manual_review",
      verificationBadgeVisible: false,
      queueStatus: "queued",
      reason: "east_malaysia_manual_review_only",
      matchedCandidate: null,
      confidenceScore: 0,
    };
  }

  if (adapterResult?.adapterStatus === "request_failed") {
    return {
      verificationStatus: "manual_review_required",
      verificationProvider: "malaysian_bar",
      verificationBadgeVisible: false,
      queueStatus: "queued",
      reason: "source_request_failed",
      matchedCandidate: null,
      confidenceScore: 0,
    };
  }

  const candidates = Array.isArray(adapterResult?.candidates)
    ? adapterResult.candidates
    : [];

  if (!candidates.length) {
    return {
      verificationStatus: "manual_review_required",
      verificationProvider: "malaysian_bar",
      verificationBadgeVisible: false,
      queueStatus: "queued",
      reason: adapterResult?.adapterStatus || "no_candidate_found",
      matchedCandidate: null,
      confidenceScore: 0,
    };
  }

  const ranked = candidates
    .map((candidate) => scoreCandidate(candidate, profile))
    .sort((a, b) => b.totalScore - a.totalScore);

  const best = ranked[0];
  const bestNameScore = best?.nameScore || 0;

  if (best && best.inactive && bestNameScore >= 0.9) {
    return {
      verificationStatus: "rejected",
      verificationProvider: "malaysian_bar",
      verificationBadgeVisible: false,
      queueStatus: "resolved",
      reason: "listed_inactive_or_suspended",
      matchedCandidate: {
        ...best.candidate,
        confidenceScore: Number(best.totalScore.toFixed(4)),
      },
      confidenceScore: Number(best.totalScore.toFixed(4)),
    };
  }

  if (best && best.totalScore >= 0.85 && !best.inactive) {
    return {
      verificationStatus: "auto_verified",
      verificationProvider: "malaysian_bar",
      verificationBadgeVisible: true,
      queueStatus: "resolved",
      reason: "strong_match",
      matchedCandidate: {
        ...best.candidate,
        confidenceScore: Number(best.totalScore.toFixed(4)),
      },
      confidenceScore: Number(best.totalScore.toFixed(4)),
    };
  }

  return {
    verificationStatus: "manual_review_required",
    verificationProvider: "malaysian_bar",
    verificationBadgeVisible: false,
    queueStatus: "queued",
    reason:
      best && best.totalScore >= 0.6
        ? "ambiguous_match"
        : "low_confidence_match",
    matchedCandidate: best
      ? {
          ...best.candidate,
          confidenceScore: Number(best.totalScore.toFixed(4)),
        }
      : null,
    confidenceScore: Number((best?.totalScore || 0).toFixed(4)),
  };
}

module.exports = {
  buildVerificationDecision,
};
