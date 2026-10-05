import { FieldValue } from 'firebase-admin/firestore';

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

export type DeletionAction = 'delete' | 'anonymize' | 'redact';

export interface DeletionTarget {
  collection: string;
  ref: FirebaseFirestore.DocumentReference;
  action: DeletionAction;
  /** For 'redact': the fields to write, merged into the document. */
  fields?: Record<string, unknown>;
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

  // Documents keyed directly by uid. The instructor profile and its private
  // companion (phone, contact email, licence numbers) go with the account
  // (instructors plan v2 §17); onInstructorWrite recounts the state's listing
  // count when instructors/{uid} disappears.
  for (const collection of ['users', 'savedQuestions', 'progress', 'instructors', 'instructorPrivate', 'favorites']) {
    const ref = db.collection(collection).doc(userId);
    if ((await ref.get()).exists) targets.push({ collection, ref, action: 'delete' });
  }

  // Subcollections. A parent delete does NOT remove these — they would have
  // outlived the account silently.
  const sessions = await db.collection('users').doc(userId).collection('sessions').get();
  for (const doc of sessions.docs) {
    targets.push({ collection: 'users/sessions', ref: doc.ref, action: 'delete' });
  }

  // Push tokens, and the reviews students left ON this instructor (one doc
  // per student, under the profile being deleted).
  for (const [collection, sub] of [
    ['users/fcmTokens', db.collection('users').doc(userId).collection('fcmTokens')],
    ['instructors/reviews', db.collection('instructors').doc(userId).collection('reviews')],
  ] as const) {
    for (const doc of (await sub.get()).docs) targets.push({ collection, ref: doc.ref, action: 'delete' });
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

  // Conversations (plan v2 §17): anonymised, not deleted — the other side
  // keeps the thread and sees «Удалённый пользователь». The deleted side's
  // name and photo go, and so does its uid from participantUids, so nobody
  // reads the thread as them again. Messages stay: they are the other
  // person's record too. Once both sides are gone, nobody can read it, so
  // the thread and its messages are deleted.
  const threads = await db.collection('conversations').where('participantUids', 'array-contains', userId).get();
  for (const doc of threads.docs) {
    const others = (doc.get('participantUids') as string[]).filter((u) => u !== userId);
    if (others.length === 0) {
      for (const m of (await doc.ref.collection('messages').get()).docs) {
        targets.push({ collection: 'conversations/messages', ref: m.ref, action: 'delete' });
      }
      targets.push({ collection: 'conversations', ref: doc.ref, action: 'delete' });
      continue;
    }
    const side = doc.get('studentUid') === userId ? 'student' : 'instructor';
    targets.push({
      collection: 'conversations',
      ref: doc.ref,
      action: 'redact',
      fields: side === 'student'
        ? { participantUids: others, studentDeleted: true, studentDisplayName: null, studentUnread: 0 }
        : { participantUids: others, instructorDeleted: true, instructorName: null, instructorPhotoPath: null, instructorUnread: 0 },
    });
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
      } else if (target.action === 'redact') {
        batch.set(target.ref, { ...target.fields, anonymizedAt: FieldValue.serverTimestamp() }, { merge: true });
        anonymized++;
      } else {
        const update: Record<string, unknown> = {
          anonymizedAt: FieldValue.serverTimestamp(),
        };
        // Replace rather than remove: these documents are still queried by
        // userId, and a missing field would make them unreachable rather than
        // anonymous.
        update.userId = anonymousId;
        for (const field of PERSONAL_LINK_FIELDS.filter((f) => f !== 'userId')) {
          update[field] = FieldValue.delete();
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

/**
 * Storage an instructor leaves behind (instructors plan v2 §17): the pending
 * uploads, the published photos and any licence images. Deleted by prefix, so
 * every version goes, not only the one photoPath names.
 */
export const USER_STORAGE_PREFIXES = (userId: string) => [
  `instructorUploads/${userId}/`,
  `instructorPhotos/${userId}/`,
  `instructorLicenses/${userId}/`,
];

export async function deleteUserStorage(
  bucket: { deleteFiles(options: { prefix: string; force?: boolean }): Promise<unknown> },
  userId: string,
): Promise<void> {
  for (const prefix of USER_STORAGE_PREFIXES(userId)) {
    await bucket.deleteFiles({ prefix, force: true });
  }
}
