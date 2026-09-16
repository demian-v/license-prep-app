import * as admin from 'firebase-admin';

/**
 * Anonymise a departing user's trialDevices records (risk #26).
 *
 * `trialDevices/{hash}` stores `firstUserId` and `firstSubscriptionId`, so it
 * is personal data that account deletion must not leave behind (risk #13).
 *
 * But it is ALSO the device-level trial gate, and DELETING it would make
 * account deletion the easiest possible trial-farming tool: delete, re-register,
 * collect another free trial, repeat. So the record is kept and the user link
 * is stripped. The gate keeps working; the person is no longer identifiable
 * from it.
 *
 * Returns how many records were anonymised, so the caller can log it.
 */
export async function anonymizeTrialDevicesForUser(
  db: FirebaseFirestore.Firestore,
  batch: FirebaseFirestore.WriteBatch,
  userId: string,
): Promise<number> {
  const snap = await db.collection('trialDevices')
    .where('firstUserId', '==', userId)
    .get();

  for (const doc of snap.docs) {
    batch.update(doc.ref, {
      firstUserId: admin.firestore.FieldValue.delete(),
      firstSubscriptionId: admin.firestore.FieldValue.delete(),
      anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return snap.size;
}
