const { FieldValue } = require("firebase-admin/firestore");

async function writeAuditLog(db, {
  uid,
  conversationId,
  question,
  assessment,
  result,
  config,
}) {
  const ref = db.collection("lexibot_audit_logs").doc();
  await ref.set({
    uid,
    conversationId: conversationId || null,
    question,
    scopeStatus: assessment.scopeStatus,
    riskLevel: assessment.riskLevel,
    answerStatus: result.status,
    model: config.answerModel || null,
    fileSearchStoreName: config.fileSearchStoreName || null,
    groundingChunkCount: result.groundingChunkCount || 0,
    citations: result.citations || [],
    answer: result.answer || null,
    createdAt: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

module.exports = {
  writeAuditLog,
};
