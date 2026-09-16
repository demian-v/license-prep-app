import * as admin from 'firebase-admin';

/**
 * Account deletion (risks #13 and #14).
 *
 * privacy_policy.md promises "your account and all associated data" and "all
 * personal data is deleted within 30 days". The implementation deleted the
 * users document and savedQuestions — 2 of at least 8 places holding user
 * data. Everything else survived indefinitely, which made the policy a
 * statement the code could not deliver.
 *
 * The same policy carves out "Subscription Data: Retained as required for
 * billing and tax purposes". Those records are therefore ANONYMISED rather
 * than deleted: the financial facts stay, the link to the person goes. That
 * honours both promises instead of choosing between them.
 */

export type DeletionAction = 'delete' | 'anonymize';

export interface DeletionTarget {
  collection: string;
  ref: FirebaseFirestore.DocumentReference;
  action: DeletionAction;
}

/** Fields that tie a retained billing record to a person. */
const PERSONAL_LINK_FIELDS = ['userId', 'email', 'deviceIdHash'];

/**
 * Enumerate everything belonging to a user, and how each should be handled.
 *
 * Kept separate from the deleting so the enumeration is testable on its own: a
 * silent omission here is exactly how this became "2 of at least 8".
 */
export async function collectUserDataForDeletion(
  db: FirebaseFirestore.Firestore,
  userId: string,
): Promise<DeletionTarget[]> {
  const targets: DeletionTarget[] = [];

  // Documents keyed directly by uid.
  for (const collection of ['users', 'savedQuestions', 'progress']) {
    const ref = db.collection(collection).doc(userId);
    if ((await ref.get()).exists) targets.push({ collection, ref, action: 'delete' });
  }

  // Subcollections. A parent delete does NOT remove these — they would have
  // outlived the account silently.
  const sessions = await db.collection('users').doc(userId).collection('sessions').get();
  for (const doc of sessions.docs) {
    targets.push({ collection: 'users/sessions', ref: doc.ref, action: 'delete' });
  }

  // The user's personal report counter (counters/user_{uid}_reports).
  const counterRef = db.collection('counters').doc(`user_${userId}_reports`);
  if ((await counterRef.get()).exists) {
    targets.push({ collection: 'counters', ref: counterRef, action: 'delete' });
  }

  // Reports the user filed, found by field rather than by id pattern so a
  // legacy or fallback id shape cannot be missed.
  const reports = await db.collection('reports').where('userId', '==', userId).get();
  for (const doc of reports.docs) {
    targets.push({ collection: 'reports', ref: doc.ref, action: 'delete' });
  }

  // Billing records: retained, de-linked.
  for (const collection of ['subscriptions', 'subscriptionLogs']) {
    const snap = await db.collection(collection).where('userId', '==', userId).get();
    for (const doc of snap.docs) {
      targets.push({ collection, ref: doc.ref, action: 'anonymize' });
    }
  }

  return targets;
}

/**
 * Apply a deletion plan in chunks.
 *
 * Firestore batches cap at 500 writes, and a user with a long history can
 * exceed that. The previous single batch would simply have failed.
 */
export async function applyDeletionPlan(
  db: FirebaseFirestore.Firestore,
  targets: DeletionTarget[],
  anonymousId: string,
): Promise<{ deleted: number; anonymized: number }> {
  const CHUNK = 400;
  let deleted = 0;
  let anonymized = 0;

  for (let i = 0; i < targets.length; i += CHUNK) {
    const batch = db.batch();
    for (const target of targets.slice(i, i + CHUNK)) {
      if (target.action === 'delete') {
        batch.delete(target.ref);
        deleted++;
      } else {
        const update: Record<string, unknown> = {
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        // Replace rather than remove: these documents are still queried by
        // userId, and a missing field would make them unreachable rather than
        // anonymous.
        update.userId = anonymousId;
        for (const field of PERSONAL_LINK_FIELDS.filter((f) => f !== 'userId')) {
          update[field] = admin.firestore.FieldValue.delete();
        }
        batch.set(target.ref, update, { merge: true });
        anonymized++;
      }
    }
    await batch.commit();
  }

  return { deleted, anonymized };
}

/**
 * How recently the caller must have signed in to delete their account.
 *
 * `admin.auth().deleteUser()` bypasses Firebase's own `requires-recent-login`
 * entirely, so nothing enforced this before: a stolen or borrowed unlocked
 * phone could destroy an account hours after the real user last authenticated.
 */
export const REAUTH_MAX_AGE_SECONDS = 10 * 60;

export function assertRecentLogin(authTimeSeconds: unknown): void {
  if (typeof authTimeSeconds !== 'number') {
    // No auth_time claim: refuse rather than assume. Deletion is irreversible.
    throw new Error('missing-auth-time');
  }
  const ageSeconds = Math.floor(Date.now() / 1000) - authTimeSeconds;
  if (ageSeconds > REAUTH_MAX_AGE_SECONDS) {
    throw new Error('recent-login-required');
  }
}
