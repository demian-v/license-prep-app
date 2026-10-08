import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { listedInstructor } from './instructors';
import { maskContacts, studentDisplayName } from './chat';

/**
 * Reviews (instructors plan v2 §11, P8).
 *
 * instructors/{uid}/reviews/{studentUid} — one review per student per
 * instructor — is written only here (firestore.rules: the instructor and the
 * review's author read, nobody writes), and so are the public numbers
 * `ratingSum`, `ratingCount`, `ratingAvg`, always in the same transaction as
 * the review, so they cannot drift.
 *
 * Owner decisions (2026-10-07):
 * - A student may review once they had a completed lesson with that
 *   instructor, paid plan or not: the lesson happened.
 * - A review can be edited and deleted by its author.
 * - The comment is masked like a chat message, so a review shown to every
 *   paid student cannot carry a phone number past the chat masking.
 * - A review has an opaque `reviewId` (random, kept on edits). Students get
 *   it from getInstructorReviews instead of the doc id, which is the author's
 *   uid, and a report names the review by it through reportReview.
 */

export const MAX_COMMENT_LENGTH = 500;
const MAX_REPORT_MESSAGE_LENGTH = 1000;
const REVIEWABLE = new Set(['completed', 'payout_released']);
const REPORT_REASONS = new Set(['harassment', 'inappropriate', 'spam', 'other']);
const ID = /^[A-Za-z0-9_-]{1,128}$/;

/** One decimal, as the app shows it; 0 with no reviews (as the seed writes it). */
export function ratingAvgOf(sum: number, count: number): number {
  return count > 0 ? Math.round((sum / count) * 10) / 10 : 0;
}

/**
 * The instructor's numbers after one review changes (plan v2 §11): `from`
 * null is a new review, `to` null a removed one.
 */
export function ratingTotals(sum: number, count: number, from: number | null, to: number | null) {
  const ratingSum = sum - (from ?? 0) + (to ?? 0);
  const ratingCount = count - (from === null ? 0 : 1) + (to === null ? 0 : 1);
  return { ratingSum, ratingCount, ratingAvg: ratingAvgOf(ratingSum, ratingCount) };
}

function signedIn(context: any): string {
  if (!context?.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  if (context.auth.token?.firebase?.sign_in_provider === 'anonymous') {
    throw new functions.https.HttpsError('permission-denied', 'Anonymous sessions cannot review.');
  }
  return context.auth.uid;
}

function id(v: unknown, name: string): string {
  if (typeof v !== 'string' || !ID.test(v)) {
    throw new functions.https.HttpsError('invalid-argument', `Invalid or missing field: ${name}`);
  }
  return v;
}

const reviewRef = (instructorUid: string, studentUid: string) =>
  admin.firestore().collection('instructors').doc(instructorUid).collection('reviews').doc(studentUid);

/**
 * Writes or edits the caller's review of the instructor they had `bookingId`
 * with. The booking must be theirs and over (`completed`, or
 * `payout_released` from P9); it becomes the review's `lastBookingId`.
 */
export const submitReview = functions.https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const bookingId = id(data?.bookingId, 'bookingId');
  const rating = data?.rating;
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: rating');
  }
  if (data?.comment != null && typeof data.comment !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid field: comment');
  }
  const raw: string = (data?.comment ?? '').trim();
  if (raw.length > MAX_COMMENT_LENGTH) {
    throw new functions.https.HttpsError('invalid-argument', `A comment is at most ${MAX_COMMENT_LENGTH} characters.`);
  }
  const { text: comment } = maskContacts(raw);

  const db = admin.firestore();
  const booking = await db.collection('bookings').doc(bookingId).get();
  if (!booking.exists || booking.get('studentUid') !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Not your booking.');
  }
  if (!REVIEWABLE.has(booking.get('status'))) {
    throw new functions.https.HttpsError('failed-precondition', 'not-reviewable');
  }
  const instructorRef = db.collection('instructors').doc(booking.get('instructorUid'));
  const ref = reviewRef(instructorRef.id, uid);
  const student = await db.collection('users').doc(uid).get();

  const edited = await db.runTransaction(async (tx) => {
    const [instructor, old] = await Promise.all([tx.get(instructorRef), tx.get(ref)]);
    if (!instructor.exists) throw new functions.https.HttpsError('not-found', 'This profile is not available.');
    const now = Timestamp.now();
    tx.update(instructorRef, ratingTotals(
      instructor.get('ratingSum') ?? 0, instructor.get('ratingCount') ?? 0, old.exists ? old.get('rating') : null, rating,
    ));
    tx.set(ref, {
      reviewId: old.get('reviewId') ?? instructorRef.collection('reviews').doc().id,
      studentDisplayName: studentDisplayName(student.get('name')),
      rating,
      comment,
      lastBookingId: bookingId,
      createdAt: old.exists ? old.get('createdAt') : now,
      updatedAt: now,
    });
    return old.exists;
  });
  return { edited, comment };
});

/**
 * Removes one student's review of one instructor and takes it out of the
 * numbers, in one transaction. False when there was none. Used by
 * deleteReview and by account deletion (plan v2 §17).
 */
export async function removeReview(db: FirebaseFirestore.Firestore, instructorUid: string, studentUid: string): Promise<boolean> {
  const instructorRef = db.collection('instructors').doc(instructorUid);
  const ref = instructorRef.collection('reviews').doc(studentUid);
  return db.runTransaction(async (tx) => {
    const [instructor, old] = await Promise.all([tx.get(instructorRef), tx.get(ref)]);
    if (!old.exists) return false;
    tx.delete(ref);
    if (instructor.exists) {
      tx.update(instructorRef, ratingTotals(instructor.get('ratingSum') ?? 0, instructor.get('ratingCount') ?? 0, old.get('rating'), null));
    }
    return true;
  });
}

/** The caller deletes their own review of `instructorUid`. */
export const deleteReview = functions.https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const instructorUid = id(data?.instructorUid, 'instructorUid');
  return { removed: await removeReview(admin.firestore(), instructorUid, uid) };
});

/**
 * Reports one review (plan v2 §7: `contentType: 'review'`). A paid student
 * who can see the profile, or the instructor the review is about. The report
 * names the review by its opaque id and keeps a copy of what it said, so an
 * edit after the report doesn't erase the evidence; the author's uid stays on
 * the server.
 */
export const reportReview = functions.https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const instructorUid = id(data?.instructorUid, 'instructorUid');
  const reviewId = id(data?.reviewId, 'reviewId');
  const reason = data?.reason;
  if (typeof reason !== 'string' || !REPORT_REASONS.has(reason)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: reason');
  }
  const message = typeof data?.message === 'string' ? data.message.trim() : '';
  if ((reason === 'other' && message.length < 10) || message.length > MAX_REPORT_MESSAGE_LENGTH) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid field: message');
  }
  // The same gates as reading the reviews, unless it is the instructor's own profile.
  if (uid !== instructorUid) await listedInstructor({ id: instructorUid }, context);

  const db = admin.firestore();
  const found = await db.collection('instructors').doc(instructorUid).collection('reviews')
    .where('reviewId', '==', reviewId).limit(1).get();
  if (found.empty) throw new functions.https.HttpsError('not-found', 'This review is not available.');
  const review = found.docs[0];
  if (review.id === uid) throw new functions.https.HttpsError('failed-precondition', 'own-review');

  const str = (v: unknown) => (typeof v === 'string' && v.length <= 32 ? v : null);
  await db.collection('reports').add({
    reason,
    contentType: 'review',
    entity: { instructorUid, reviewId },
    review: { rating: review.get('rating'), comment: review.get('comment') ?? '' },
    ...(message ? { message } : {}),
    userId: uid,
    status: 'open',
    // What the app's other reports carry (IssueReport.toMap), when given.
    ...Object.fromEntries(['language', 'state', 'appVersion', 'buildNumber', 'platform']
      .map((k) => [k, str(data?.[k])]).filter(([, v]) => v !== null)),
    createdAt: FieldValue.serverTimestamp(),
  });
  return { reported: true };
});
