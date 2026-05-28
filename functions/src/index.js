const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const {
  lookupMalaysianBarCandidates,
} = require("./verification/malaysian_bar_adapter");
const {
  buildVerificationDecision,
} = require("./verification/verification_decision");

initializeApp();

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
