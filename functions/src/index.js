const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
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

// The Secure Link Shortener
exports.generateSecureShareLink = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in to generate a sharing link.");
  }

  const { storagePath, expirationHours } = request.data;
  
  if (!storagePath || !expirationHours) {
    throw new HttpsError("invalid-argument", "Both storagePath and expirationHours are required.");
  }

  try {
    const bucket = getStorage().bucket();
    const file = bucket.file(storagePath);
    const expiresAt = Date.now() + (expirationHours * 60 * 60 * 1000);

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
      createdAt: FieldValue.serverTimestamp()
    });

    // IMPORTANT: Make sure this is your actual Cloud Function URL for the 'go' function!
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
    return res.status(400).send(htmlTemplate("Invalid Link", "The link you clicked is missing its secure code.", "❌"));
  }

  try {
    const db = getFirestore();
    const linkDoc = await db.collection("short_links").doc(code).get();

    if (!linkDoc.exists) {
      return res.status(404).send(htmlTemplate("Document Not Found", "This secure link does not exist. It may have been deleted.", "🔍"));
    }

    const data = linkDoc.data();

    if (Date.now() > data.expiresAt) {
      return res.status(410).send(htmlTemplate("Link Expired", "This secure document link has passed its time limit and is no longer accessible. Please ask the sender to generate a new link.", "⏳"));
    }

    res.redirect(302, data.longUrl);

  } catch (error) {
    logger.error("Redirect error:", error);
    res.status(500).send(htmlTemplate("Server Error", "Something went wrong on our end. Please try again later.", "⚠️"));
  }
});