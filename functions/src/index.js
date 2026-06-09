const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");

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

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth;
}

function readCaseId(data) {
  const caseId = String(data?.caseId || "").trim();
  if (!caseId) {
    throw new HttpsError("invalid-argument", "caseId is required.");
  }
  return caseId;
}

function normalizeReason(value, maxLength) {
  const trimmed = String(value || "").trim();
  if (!trimmed) return null;
  if (trimmed.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `reason must be ${maxLength} characters or less.`,
    );
  }
  return trimmed;
}

exports.startVerification = onCall({ invoker: "public" }, async (request) => {
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

exports.reviewVerificationRequest = onCall(
  { invoker: "public" },
  async (request) => {
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
  },
);

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
        grounded.citations = await resolveApprovedCitations(
          db,
          grounded.citations,
        );
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

// The Secure Link Shortener
exports.generateSecureShareLink = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in to generate a sharing link.",
    );
  }

  const { storagePath, expirationHours } = request.data || {};

  if (!storagePath || !expirationHours) {
    throw new HttpsError(
      "invalid-argument",
      "Both storagePath and expirationHours are required.",
    );
  }

  try {
    const bucket = getStorage().bucket();
    const file = bucket.file(storagePath);
    const expiresAt = Date.now() + expirationHours * 60 * 60 * 1000;

    const [longUrl] = await file.getSignedUrl({
      version: "v4",
      action: "read",
      expires: expiresAt,
    });

    const shortCode = Math.random().toString(36).substring(2, 8);
    const db = getFirestore();

    await db.collection("short_links").doc(shortCode).set({
      longUrl: longUrl,
      expiresAt: expiresAt,
      createdAt: FieldValue.serverTimestamp(),
    });

    // IMPORTANT: Make sure this is your actual Cloud Function URL for the 'go'
    // function!
    const cleanUrl = `https://go-oi4h7xebta-uc.a.run.app/?id=${shortCode}`;

    return {
      success: true,
      url: cleanUrl,
      expiresAt: expiresAt,
    };
  } catch (error) {
    logger.error("Error generating signed URL:", error);
    throw new HttpsError("internal", "Failed to generate secure link.");
  }
});

// The Public Redirect Traffic Cop
exports.go = onRequest(async (req, res) => {
  const code = req.query.id;

  const htmlTemplate = (title, message, icon) => `
    <!DOCTYPE html>
    <html>
    <head>
      <title>${title} | LexiGuard</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F1F5F9; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .container { background-color: white; padding: 40px; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); text-align: center; max-width: 400px; width: 90%; border: 1px solid #E2E8F0; }
        .icon { font-size: 48px; margin-bottom: 16px; }
        h2 { color: #0B2447; font-size: 22px; margin-top: 0; margin-bottom: 8px; }
        p { color: #64748B; font-size: 15px; line-height: 1.5; margin: 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="icon">${icon}</div>
        <h2>${title}</h2>
        <p>${message}</p>
      </div>
    </body>
    </html>
  `;

  if (!code) {
    return res
      .status(400)
      .send(
        htmlTemplate(
          "Invalid Link",
          "The link you clicked is missing its secure code.",
          "X",
        ),
      );
  }

  try {
    const db = getFirestore();
    const linkDoc = await db.collection("short_links").doc(code).get();

    if (!linkDoc.exists) {
      return res
        .status(404)
        .send(
          htmlTemplate(
            "Document Not Found",
            "This secure link does not exist. It may have been deleted.",
            "?",
          ),
        );
    }

    const data = linkDoc.data();

    if (Date.now() > data.expiresAt) {
      return res
        .status(410)
        .send(
          htmlTemplate(
            "Link Expired",
            "This secure document link has passed its time limit and is no longer accessible. Please ask the sender to generate a new link.",
            "!",
          ),
        );
    }

    res.redirect(302, data.longUrl);
  } catch (error) {
    logger.error("Redirect error:", error);
    res
      .status(500)
      .send(
        htmlTemplate(
          "Server Error",
          "Something went wrong on our end. Please try again later.",
          "!",
        ),
      );
  }
});

exports.withdrawCase = onCall({ invoker: "public" }, async (request) => {
  const auth = requireAuth(request);
  const caseId = readCaseId(request.data);
  const db = getFirestore();

  const pendingSnap = await db
    .collection("connection_requests")
    .where("caseId", "==", caseId)
    .where("status", "==", "pending")
    .get();

  const pendingRefs = pendingSnap.docs.map((doc) => doc.ref);
  const notifiedLawyerIds = pendingSnap.docs
    .map((doc) => doc.data()?.lawyerId)
    .filter(Boolean);

  const now = FieldValue.serverTimestamp();
  const caseRef = db.collection("cases").doc(caseId);

  await db.runTransaction(async (tx) => {
    const caseSnap = await tx.get(caseRef);
    if (!caseSnap.exists) {
      throw new HttpsError("not-found", "Case not found.");
    }

    const caseData = caseSnap.data();
    if (caseData?.clientId !== auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "Only the case owner can withdraw this case.",
      );
    }

    if (caseData?.status !== "pending" || caseData?.lawyerId) {
      throw new HttpsError(
        "failed-precondition",
        "Case cannot be withdrawn after acceptance.",
      );
    }

    const pendingSnaps = [];
    for (const ref of pendingRefs) {
      pendingSnaps.push(await tx.get(ref));
    }

    tx.update(caseRef, {
      status: "withdrawn",
      withdrawnAt: now,
      withdrawnBy: auth.uid,
      updatedAt: now,
      interestedLawyerIds: [],
    });

    const historyRef = caseRef.collection("history").doc();
    const autoDeclinedCount = pendingSnaps.filter(
      (snap) => snap.exists && snap.data()?.status === "pending",
    ).length;

    tx.set(historyRef, {
      eventType: "case_withdrawn",
      actorId: auth.uid,
      actorRole: "client",
      previousStatus: caseData?.status ?? null,
      newStatus: "withdrawn",
      autoDeclinedCount,
      createdAt: now,
    });

    for (const snap of pendingSnaps) {
      if (!snap.exists) continue;
      const requestData = snap.data();
      if (requestData?.status !== "pending") continue;

      tx.update(snap.ref, {
        status: "declined",
        respondedAt: now,
        updatedAt: now,
        declineReason: "case_withdrawn",
      });

      const lawyerId = requestData?.lawyerId;
      if (lawyerId) {
        const notificationRef = db.collection("notifications").doc();
        tx.set(notificationRef, {
          userId: lawyerId,
          caseId,
          type: "case_withdrawn",
          title: "Case withdrawn",
          body: "The client withdrew the case before selecting a lawyer.",
          reason: null,
          createdAt: now,
          readAt: null,
          actorId: auth.uid,
          actorRole: "client",
        });
      }
    }
  });

  return {
    caseId,
    status: "withdrawn",
    notifiedLawyerCount: notifiedLawyerIds.length,
  };
});

exports.closeCase = onCall({ invoker: "public" }, async (request) => {
  const auth = requireAuth(request);
  const caseId = readCaseId(request.data);
  const reason = normalizeReason(request.data?.reason, 200);
  const db = getFirestore();
  const now = FieldValue.serverTimestamp();
  const caseRef = db.collection("cases").doc(caseId);

  await db.runTransaction(async (tx) => {
    const caseSnap = await tx.get(caseRef);
    if (!caseSnap.exists) {
      throw new HttpsError("not-found", "Case not found.");
    }

    const caseData = caseSnap.data();
    if (caseData?.clientId !== auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "Only the case owner can close this case.",
      );
    }

    if (caseData?.status !== "active" || !caseData?.lawyerId) {
      throw new HttpsError(
        "failed-precondition",
        "Case can only be closed after acceptance.",
      );
    }

    const caseUpdate = {
      status: "closed",
      closedAt: now,
      closedBy: auth.uid,
      updatedAt: now,
      ...(reason ? { closeReason: reason } : {}),
    };

    tx.update(caseRef, caseUpdate);

    const historyRef = caseRef.collection("history").doc();
    tx.set(historyRef, {
      eventType: "case_closed",
      actorId: auth.uid,
      actorRole: "client",
      previousStatus: caseData?.status ?? null,
      newStatus: "closed",
      reason: reason,
      createdAt: now,
    });

    const lawyerId = caseData?.lawyerId;
    if (lawyerId) {
      const notificationRef = db.collection("notifications").doc();
      tx.set(notificationRef, {
        userId: lawyerId,
        caseId,
        type: "case_closed",
        title: "Case closed",
        body: reason
          ? "The client closed the case and left a reason."
          : "The client marked the case as closed.",
        reason: reason,
        createdAt: now,
        readAt: null,
        actorId: auth.uid,
        actorRole: "client",
      });
    }
  });

  return { caseId, status: "closed" };
});