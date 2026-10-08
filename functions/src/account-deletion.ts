import { FieldValue } from 'firebase-admin/firestore';
import { removeReview } from './reviews';

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

export type DeletionAction = 'delete' | 'anonymize' | 'redact' | 'unreview';

export interface DeletionTarget {
  collection: string;
  ref: FirebaseFirestore.DocumentReference;
  action: DeletionAction;
  /** For 'redact': the fields to write, merged into the document. */
  fields?: Record<string, unknown>;
}

/** What a deleted user's uid becomes in the records that are kept. */
export const anonymousIdFor = (userId: string) => `deleted_${userId.slice(0, 8)}`;

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

  // Bookings (plan v2 §17): financial records, so anonymised, never deleted —
  // the amounts and ids stay, the deleted side's uid becomes the same
  // `deleted_…` id the billing records get and its name goes. The other side
  // still reads the booking. deleteUserAccount has already refused while a
  // lesson is upcoming (§9.4).
  const hadLessonsWith = new Set<string>();
  for (const side of ['student', 'instructor'] as const) {
    const snap = await db.collection('bookings').where(`${side}Uid`, '==', userId).get();
    for (const doc of snap.docs) {
      if (side === 'student') hadLessonsWith.add(doc.get('instructorUid'));
      targets.push({
        collection: 'bookings',
        ref: doc.ref,
        action: 'redact',
        fields: side === 'student'
          ? { studentUid: anonymousIdFor(userId), studentDeleted: true, studentDisplayName: null }
          : { instructorUid: anonymousIdFor(userId), instructorDeleted: true, instructorName: null },
      });
    }
  }

  // Reviews the user wrote (plan v2 §17): deleted, and taken out of that
  // instructor's numbers. A review needs a completed lesson, so the user's
  // own bookings name every instructor they can have reviewed — no
  // collection-group index needed (risk #15). Read here, before the bookings
  // above are anonymised.
  for (const instructorUid of hadLessonsWith) {
    const ref = db.collection('instructors').doc(instructorUid).collection('reviews').doc(userId);
    if ((await ref.get()).exists) targets.push({ collection: 'instructors/reviews (written)', ref, action: 'unreview' });
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

  // A written review changes its instructor's numbers, so each one is its
  // own transaction rather than a batched delete. Done first: a rerun after
  // a failure finds only the ones still left.
  for (const target of targets.filter((t) => t.action === 'unreview')) {
    if (await removeReview(db, target.ref.parent.parent!.id, target.ref.id)) deleted++;
  }

  const batched = targets.filter((t) => t.action !== 'unreview');
  for (let i = 0; i < batched.length; i += CHUNK) {
    const batch = db.batch();
    for (const target of batched.slice(i, i + CHUNK)) {
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
