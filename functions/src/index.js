const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");

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

exports.startVerification = onCall(async (request) => {
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

exports.reviewVerificationRequest = onCall(async (request) => {
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

// Standard HTTP Callable Function (Requires proper IAM permissions, which you now have!)
exports.generateSecureShareLink = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated", 
      "You must be logged in to generate a sharing link."
    );
  }

  const { storagePath, expirationHours } = request.data;
  
  if (!storagePath || !expirationHours) {
    throw new HttpsError(
      "invalid-argument", 
      "Both storagePath and expirationHours are required."
    );
  }

  try {
    const bucket = getStorage().bucket();
    const file = bucket.file(storagePath);
    const expiresAt = Date.now() + (expirationHours * 60 * 60 * 1000);

    const [url] = await file.getSignedUrl({
      version: "v4",
      action: "read",
      expires: expiresAt,
    });

    return {
      success: true,
      url: url,
      expiresAt: expiresAt,
    };
  } catch (error) {
    logger.error("Error generating signed URL:", error);
    throw new HttpsError(
      "internal", 
      "Failed to generate secure link."
    );
  }
});