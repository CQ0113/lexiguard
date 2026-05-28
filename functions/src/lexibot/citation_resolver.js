async function resolveApprovedCitations(db, citations) {
  const snapshot = await db
    .collection("legal_sources")
    .where("status", "==", "active")
    .get();
  const sources = await Promise.all(
    snapshot.docs.map(async (document) => {
      const source = document.data();
      if (!source.activeVersionId) return null;
      const version = await document.ref
        .collection("versions")
        .doc(source.activeVersionId)
        .get();
      if (!version.exists || version.data().reviewStatus !== "approved") {
        return null;
      }
      return {
        sourceId: document.id,
        title: source.title,
        versionId: source.activeVersionId,
        sourceUrl: version.data().sourceUrl || null,
      };
    }),
  );

  const approved = sources.filter(Boolean);
  const resolved = [];
  for (const citation of citations) {
    const title = String(citation.title || "").toLowerCase();
    const source = approved.find((candidate) =>
      title.includes(candidate.title.toLowerCase()),
    );
    if (
      source &&
      !resolved.some((entry) => entry.sourceId === source.sourceId)
    ) {
      resolved.push(source);
    }
  }
  return resolved;
}

module.exports = {
  resolveApprovedCitations,
};
