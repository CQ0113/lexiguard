const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const {
  lookupMalaysianBarCandidates,
} = require("./verification/malaysian_bar_adapter");
const {
  buildVerificationDecision,
} = require("./verification/verification_decision");
const { assessQuestion, escalationResponse } = require("./lexibot/safety");
const { generateGroundedAnswer } = require("./lexibot/gemini_file_search");
const { resolveApprovedCitations } = require("./lexibot/citation_resolver");
const { writeAuditLog } = require("./lexibot/audit_log");

initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");

function validateStartPayload(data) {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "Payload is required.");
  }

  const uid = String(data.uid || "").trim();
  const legalFullName = String(data.legalFullName || "").trim();

  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }

  if (!legalFullName) {
    throw new HttpsError("invalid-argument", "legalFullName is required.");
  }

  return {
    uid,
    legalFullName,
    barOrRollNumber: String(data.barOrRollNumber || "").trim() || null,
    firmName: String(data.firmName || "").trim() || null,
    jurisdiction: String(data.jurisdiction || "peninsular").trim(),
    practiceState: String(data.practiceState || "").trim() || null,
    practiceCity: String(data.practiceCity || "").trim() || null,
  };
}

exports.startVerification = onCall({ invoker: 'public' }, async (request) => {
  const db = getFirestore();
  const profile = validateStartPayload(request.data);

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  if (request.auth.uid !== profile.uid) {
    throw new HttpsError(
      "permission-denied",
      "You can only start verification for your own profile.",
    );
  }

  const adapterResult =
    profile.jurisdiction === "peninsular"
      ? await lookupMalaysianBarCandidates({
          legalFullName: profile.legalFullName,
          practiceState: profile.practiceState,
        })
      : {
          source: "malaysian_bar",
          adapterStatus: "skipped_non_peninsular",
          candidates: [],
        };

  const decision = buildVerificationDecision({
    profile,
    adapterResult,
  });

  const now = FieldValue.serverTimestamp();
  const userVerificationPatch = {
    verificationStatus: decision.verificationStatus,
    verificationProvider: decision.verificationProvider,
    verificationBadgeVisible: decision.verificationBadgeVisible,
    verificationConfidenceScore: decision.confidenceScore ?? 0,
    lastVerifiedAt: now,
    updatedAt: now,
  };

  await db
    .collection("users")
    .doc(profile.uid)
    .set(
      {
        ...userVerificationPatch,
        legalFullName: profile.legalFullName,
        firmName: profile.firmName,
        jurisdiction: profile.jurisdiction,
        practiceState: profile.practiceState,
        practiceCity: profile.practiceCity,
        barNumber: profile.barOrRollNumber,
        createdAt: now,
      },
      { merge: true },
    );

  await db
    .collection("lawyer_profiles")
    .doc(profile.uid)
    .set(
      {
        uid: profile.uid,
        legalFullName: profile.legalFullName,
        barOrRollNumber: profile.barOrRollNumber,
        firmName: profile.firmName,
        jurisdiction: profile.jurisdiction,
        practiceState: profile.practiceState,
        practiceCity: profile.practiceCity,
        matchedCandidate: decision.matchedCandidate,
        adapterStatus: adapterResult.adapterStatus,
        adapterError: adapterResult.errorMessage || null,
        verificationStatus: decision.verificationStatus,
        verificationProvider: decision.verificationProvider,
        verificationBadgeVisible: decision.verificationBadgeVisible,
        verificationConfidenceScore: decision.confidenceScore ?? 0,
        updatedAt: now,
        createdAt: now,
      },
      { merge: true },
    );

  await db
    .collection("verification_requests")
    .doc(profile.uid)
    .set(
      {
        uid: profile.uid,
        requestType: "lawyer_registration",
        queueStatus: decision.queueStatus,
        queueReason: decision.reason,
        source: "startVerification_callable",
        adapterStatus: adapterResult.adapterStatus,
        adapterError: adapterResult.errorMessage || null,
        verificationStatus: decision.verificationStatus,
        verificationProvider: decision.verificationProvider,
        verificationConfidenceScore: decision.confidenceScore ?? 0,
        legalFullName: profile.legalFullName,
        barOrRollNumber: profile.barOrRollNumber,
        firmName: profile.firmName,
        jurisdiction: profile.jurisdiction,
        practiceState: profile.practiceState,
        practiceCity: profile.practiceCity,
        updatedAt: now,
        createdAt: now,
      },
      { merge: true },
    );

  logger.info("Verification request processed", {
    uid: profile.uid,
    verificationStatus: decision.verificationStatus,
    queueStatus: decision.queueStatus,
    confidenceScore: decision.confidenceScore,
    adapterStatus: adapterResult.adapterStatus,
  });

  return {
    uid: profile.uid,
    verificationStatus: decision.verificationStatus,
    verificationProvider: decision.verificationProvider,
    verificationBadgeVisible: decision.verificationBadgeVisible,
    queueStatus: decision.queueStatus,
    adapterStatus: adapterResult.adapterStatus,
    confidenceScore: decision.confidenceScore,
    reason: decision.reason,
  };
});

exports.reviewVerificationRequest = onCall({ invoker: 'public' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const inEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  const hasReviewerClaim = request.auth.token?.reviewer === true;

  if (!inEmulator && !hasReviewerClaim) {
    throw new HttpsError(
      "permission-denied",
      "Reviewer role is required to process verification decisions.",
    );
  }

  const data = request.data || {};
  const uid = String(data.uid || "").trim();
  const action = String(data.action || "")
    .trim()
    .toLowerCase();
  const reviewerNote = String(data.reviewerNote || "").trim();

  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }

  if (!["approve", "reject"].includes(action)) {
    throw new HttpsError(
      "invalid-argument",
      "action must be either approve or reject.",
    );
  }

  const db = getFirestore();
  const now = FieldValue.serverTimestamp();

  const verificationStatus =
    action === "approve" ? "auto_verified" : "rejected";
  const verificationBadgeVisible = action === "approve";

  const patch = {
    verificationStatus,
    verificationProvider: "manual_reviewer",
    verificationBadgeVisible,
    updatedAt: now,
    lastVerifiedAt: now,
  };

  await db.collection("users").doc(uid).set(patch, { merge: true });
  await db.collection("lawyer_profiles").doc(uid).set(patch, { merge: true });

  await db
    .collection("verification_requests")
    .doc(uid)
    .set(
      {
        queueStatus: "resolved",
        resolvedAction: action,
        reviewerNote: reviewerNote || null,
        reviewedBy: request.auth.uid,
        reviewedAt: now,
        updatedAt: now,
      },
      { merge: true },
    );

  return {
    uid,
    queueStatus: "resolved",
    verificationStatus,
  };
});

exports.askLexiBot = onCall(
  {
    invoker: "public",
    secrets: [geminiApiKey],
    timeoutSeconds: 300,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const data = request.data || {};
    const question = String(data.question || "").trim();
    const conversationId = String(data.conversationId || "").trim() || null;
    if (!question) {
      throw new HttpsError("invalid-argument", "question is required.");
    }
    if (question.length > 2000) {
      throw new HttpsError(
        "invalid-argument",
        "question must not exceed 2000 characters.",
      );
    }

    const db = getFirestore();
    const configSnapshot = await db.doc("lexibot_config/tenancy_mvp").get();
    if (!configSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "LexiBot has not been configured yet.",
      );
    }
    const config = configSnapshot.data();
    const assessment = assessQuestion(question);

    if (assessment.scopeStatus !== "in_scope") {
      const result = escalationResponse(assessment);
      const auditId = await writeAuditLog(db, {
        uid: request.auth.uid,
        conversationId,
        question,
        assessment,
        result,
        config,
      });
      return { ...result, auditId };
    }

    if (config.enabled !== true) {
      throw new HttpsError(
        "failed-precondition",
        "LexiBot is not enabled for client questions yet.",
      );
    }
    if (!config.answerModel || !config.fileSearchStoreName) {
      throw new HttpsError(
        "failed-precondition",
        "LexiBot retrieval configuration is incomplete.",
      );
    }

    let grounded;
    try {
      grounded = await generateGroundedAnswer({
        apiKey: geminiApiKey.value(),
        question,
        model: config.answerModel,
        fileSearchStoreName: config.fileSearchStoreName,
      });
      if (grounded.status === "answered") {
        grounded.citations = await resolveApprovedCitations(db, grounded.citations);
        if (grounded.citations.length === 0) {
          grounded.status = "insufficient_sources";
          grounded.answer = null;
          grounded.groundingChunkCount = 0;
        }
      }
    } catch (error) {
      logger.error("LexiBot Gemini request failed", {
        uid: request.auth.uid,
        message: error.message,
      });
      throw new HttpsError("internal", "LexiBot could not answer right now.");
    }

    const result =
      grounded.status === "answered"
        ? {
            status: "answered",
            scopeStatus: assessment.scopeStatus,
            riskLevel: assessment.riskLevel,
            answer: grounded.answer,
            citations: grounded.citations,
            groundingChunkCount: grounded.groundingChunkCount,
          }
        : {
            status: "insufficient_sources",
            scopeStatus: assessment.scopeStatus,
            riskLevel: "medium",
            answer: {
              shortAnswer:
                "I cannot answer this reliably from the approved tenancy sources available.",
              whatTheSourceSays: "",
              whatThisMeans:
                "LexiBot did not retrieve enough approved evidence for a supported answer.",
              evidenceToKeep: [],
              whatYouCanDoNext: [
                "Speak with a qualified Malaysian lawyer about your circumstances.",
              ],
              sourcesUsed: [],
              needALawyer: "Yes, if you need guidance for your situation.",
            },
            citations: [],
            groundingChunkCount: 0,
          };

    const auditId = await writeAuditLog(db, {
      uid: request.auth.uid,
      conversationId,
      question,
      assessment,
      result,
      config,
    });
    logger.info("LexiBot request processed", {
      uid: request.auth.uid,
      answerStatus: result.status,
      groundingChunkCount: result.groundingChunkCount,
    });

    return { ...result, auditId };
  },
);
