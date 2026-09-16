/**
 * Risk #22 — apply a webhook's updates to EVERY subscription document that
 * shares the receipt, not just the first one Firestore happens to return.
 *
 * Both store webhooks used `.limit(1)` and `docs[0]`. When more than one
 * document carried the same originalTransactionId or purchase token — the
 * duplicate-on-re-subscribe case, or the receipt sharing of risk #5 — a
 * revocation reached exactly one of them and the rest stayed isActive forever.
 *
 * The updates are safe to fan out because they are derived from the
 * notification type and expiry alone, never from the matched document.
 *
 * Each document's user document is updated from that document's OWN userId.
 * With a shared receipt the matches can belong to different accounts, and
 * deactivating only the first account's user row is what left the others
 * entitled.
 */
export function applyToAllMatches(
  db: FirebaseFirestore.Firestore,
  batch: FirebaseFirestore.WriteBatch,
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  subUpdates: Record<string, any>,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  userUpdates: Record<string, any> | null,
): void {
  const seenUsers = new Set<string>();

  for (const doc of docs) {
    batch.update(doc.ref, subUpdates);

    const userId = doc.get('userId') as string | undefined;
    if (userUpdates && userId && !seenUsers.has(userId)) {
      seenUsers.add(userId);
      batch.set(db.collection('users').doc(userId), userUpdates, { merge: true });
    }
  }
}
