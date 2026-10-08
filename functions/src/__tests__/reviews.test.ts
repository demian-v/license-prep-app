/**
 * Instructors plan v2 §11 (P8) — reviews. The rating maths, then the
 * callables against the emulator: who may review (a completed lesson, paid
 * plan or not), insert / edit / delete keeping ratingSum/Count/Avg exact,
 * masking, the opaque id and reports, the review push on completion, and
 * account deletion taking a student's reviews out of the numbers.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { ratingAvgOf, ratingTotals } from '../reviews';
import { runMarkBookingsCompleted } from '../bookings';
import { collectUserDataForDeletion } from '../account-deletion';
import { setPushTransport } from '../push';

describe('rating maths (plan v2 §11)', () => {
  it('insert adds, edit moves the sum, removal takes it out', () => {
    expect(ratingTotals(0, 0, null, 5)).toEqual({ ratingSum: 5, ratingCount: 1, ratingAvg: 5 });
    expect(ratingTotals(14, 3, null, 4)).toEqual({ ratingSum: 18, ratingCount: 4, ratingAvg: 4.5 });
    expect(ratingTotals(14, 3, 5, 2)).toEqual({ ratingSum: 11, ratingCount: 3, ratingAvg: 3.7 });
    expect(ratingTotals(14, 3, 4, null)).toEqual({ ratingSum: 10, ratingCount: 2, ratingAvg: 5 });
    expect(ratingTotals(4, 1, 4, null)).toEqual({ ratingSum: 0, ratingCount: 0, ratingAvg: 0 });
  });

  it('rounds the average to one decimal', () => {
    expect(ratingAvgOf(14, 3)).toBe(4.7);
    expect(ratingAvgOf(13, 3)).toBe(4.3);
    expect(ratingAvgOf(0, 0)).toBe(0);
  });
});

const db = () => admin.firestore();
const STUDENT = 'rv-student';
const OTHER = 'rv-student2';
const LAPSED = 'rv-lapsed';
const TRIAL = 'rv-trial';
const SCHOOL = 'rv-i1';
const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' }, auth_time: Math.floor(Date.now() / 1000) } } });
const call = (fn: any) => (data: unknown, uid: string) => testEnv.wrap(fn)(data as any, ctx(uid) as any);
const submit = call(fns.submitReview);
const remove = call(fns.deleteReview);
const report = call(fns.reportReview);
const list = call(fns.getInstructorReviews);
const inDays = (d: number) => admin.firestore.Timestamp.fromMillis(Date.now() + d * 864e5);
const school = () => db().collection('instructors').doc(SCHOOL);
const review = (uid: string) => school().collection('reviews').doc(uid);
const numbers = async () => {
  const d = (await school().get()).data()!;
  return { ratingSum: d.ratingSum, ratingCount: d.ratingCount, ratingAvg: d.ratingAvg };
};

let pushes: { token: string; title?: string; body?: string; route?: string }[] = [];

async function lesson(id: string, studentUid: string, status: string, over: Record<string, unknown> = {}) {
  await db().collection('bookings').doc(id).set({
    studentUid, instructorUid: SCHOOL, instructorName: 'Lakeview Driving School', studentDisplayName: 'Anna K.',
    status, startAt: inDays(-1), durationMinutes: 60, timezone: 'America/Chicago', ...over,
  });
}

async function wipe() {
  await db().recursiveDelete(school());
  const snap = await db().collection('bookings').where('instructorUid', '==', SCHOOL).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
  const reports = await db().collection('reports').where('contentType', '==', 'review').get();
  await Promise.all(reports.docs.filter((d) => d.get('entity.instructorUid') === SCHOOL).map((d) => d.ref.delete()));
}

beforeAll(async () => {
  for (const [id, uid, planType, days] of [
    ['rv-paid', STUDENT, 'monthly', 20], ['rv-paid2', OTHER, 'monthly', 20], ['rv-trial', TRIAL, 'trial', 2],
  ] as const) {
    await db().collection('subscriptions').doc(id).set({ userId: uid, isActive: true, planType, nextBillingDate: inDays(days) });
  }
  // ZR is a fixture-only state code, so seeded data never mixes in.
  await db().collection('config').doc('instructors').set({ launchStates: ['ZR'] });
  await db().collection('users').doc(STUDENT).set({ name: 'Anna Kowalska', language: 'ru' });
  await db().collection('users').doc(OTHER).set({ name: 'Ben Ortiz', language: 'en' });
  await db().collection('users').doc(LAPSED).set({ name: 'Lena', language: 'en' });
  await db().collection('users').doc(STUDENT).collection('fcmTokens').doc('t').set({ token: 'tok-s', platform: 'ios' });
});

beforeEach(async () => {
  await wipe();
  pushes = [];
  setPushTransport({
    async send(messages) {
      pushes.push(...messages.map((m) => ({ token: m.token, ...m.notification, route: m.data?.route })));
      return messages.map(() => null);
    },
  });
  // Two reviews already there (as the seed writes them): sum 9, count 2.
  await school().set({
    kind: 'school', name: 'Lakeview Driving School', state: 'ZR', listed: true, status: 'active', stage: 2,
    ratingSum: 9, ratingCount: 2, ratingAvg: 4.5,
  });
  await review('seed-a').set({ reviewId: 'opaque-a', studentDisplayName: 'Jake M.', rating: 5, comment: 'Great', createdAt: inDays(-3) });
  await review('seed-b').set({ reviewId: 'opaque-b', studentDisplayName: 'Sofia R.', rating: 4, comment: 'Good', createdAt: inDays(-2) });
  await lesson('rv-done', STUDENT, 'completed');
});

afterAll(async () => {
  await wipe();
  setPushTransport(null);
  testEnv.cleanup();
});

describe('submitReview', () => {
  it('a completed lesson: writes the review and adds it to the numbers', async () => {
    expect(await submit({ bookingId: 'rv-done', rating: 3, comment: '  Calm teacher.  ' }, STUDENT))
      .toEqual({ edited: false, comment: 'Calm teacher.' });
    expect(await numbers()).toEqual({ ratingSum: 12, ratingCount: 3, ratingAvg: 4 });
    const r = (await review(STUDENT).get()).data()!;
    expect(r).toMatchObject({ studentDisplayName: 'Anna K.', rating: 3, comment: 'Calm teacher.', lastBookingId: 'rv-done' });
    expect(r.reviewId).toMatch(/^[A-Za-z0-9]{20}$/);
    expect(r.createdAt.toMillis()).toBe(r.updatedAt.toMillis());
  });

  it('an edit moves the sum by the difference and keeps the count, id and date', async () => {
    await submit({ bookingId: 'rv-done', rating: 2 }, STUDENT);
    const first = (await review(STUDENT).get()).data()!;
    await lesson('rv-done-2', STUDENT, 'payout_released');
    expect(await submit({ bookingId: 'rv-done-2', rating: 5, comment: 'Better now' }, STUDENT))
      .toMatchObject({ edited: true });
    expect(await numbers()).toEqual({ ratingSum: 14, ratingCount: 3, ratingAvg: 4.7 });
    const r = (await review(STUDENT).get()).data()!;
    expect(r).toMatchObject({ rating: 5, comment: 'Better now', lastBookingId: 'rv-done-2', reviewId: first.reviewId });
    expect(r.createdAt.toMillis()).toBe(first.createdAt.toMillis());
  });

  it('masks contact details in the comment', async () => {
    const res: any = await submit({ bookingId: 'rv-done', rating: 5, comment: 'Call me 312 555 0123 or anna@mail.com' }, STUDENT);
    expect(res.comment).toBe('Call me ••• or •••');
    expect((await review(STUDENT).get()).get('comment')).toBe('Call me ••• or •••');
  });

  it('a student whose plan has lapsed may still review a lesson they took', async () => {
    await lesson('rv-lapsed', LAPSED, 'completed');
    await submit({ bookingId: 'rv-lapsed', rating: 4 }, LAPSED);
    expect(await numbers()).toEqual({ ratingSum: 13, ratingCount: 3, ratingAvg: 4.3 });
  });

  it('refuses a lesson that is not over, not completed, or not the caller\'s', async () => {
    for (const status of ['confirmed', 'pending_payment', 'refunded', 'late_cancelled', 'expired', 'disputed']) {
      await lesson(`rv-${status}`, STUDENT, status);
      await expect(submit({ bookingId: `rv-${status}`, rating: 5 }, STUDENT))
        .rejects.toMatchObject({ code: 'failed-precondition', message: 'not-reviewable' });
    }
    await expect(submit({ bookingId: 'rv-done', rating: 5 }, OTHER)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(submit({ bookingId: 'nope', rating: 5 }, STUDENT)).rejects.toMatchObject({ code: 'permission-denied' });
    expect(await numbers()).toEqual({ ratingSum: 9, ratingCount: 2, ratingAvg: 4.5 });
  });

  it('validates the rating and the comment', async () => {
    for (const rating of [0, 6, 4.5, '5', null]) {
      await expect(submit({ bookingId: 'rv-done', rating }, STUDENT)).rejects.toMatchObject({ code: 'invalid-argument' });
    }
    await expect(submit({ bookingId: 'rv-done', rating: 5, comment: 'x'.repeat(501) }, STUDENT))
      .rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(submit({ bookingId: 'rv-done', rating: 5, comment: 42 }, STUDENT))
      .rejects.toMatchObject({ code: 'invalid-argument' });
    expect(await submit({ bookingId: 'rv-done', rating: 5, comment: 'x'.repeat(500) }, STUDENT)).toMatchObject({ edited: false });
  });

  it('refuses anonymous sessions, and an instructor who deleted their account', async () => {
    await expect(testEnv.wrap(fns.submitReview as any)({ bookingId: 'rv-done', rating: 5 } as any,
      { auth: { uid: STUDENT, token: { firebase: { sign_in_provider: 'anonymous' } } } } as any))
      .rejects.toMatchObject({ code: 'permission-denied' });
    await db().recursiveDelete(school());
    await expect(submit({ bookingId: 'rv-done', rating: 5 }, STUDENT)).rejects.toMatchObject({ code: 'not-found' });
  });
});

describe('deleteReview', () => {
  it('removes the caller\'s review and takes it out of the numbers', async () => {
    await submit({ bookingId: 'rv-done', rating: 1 }, STUDENT);
    expect(await remove({ instructorUid: SCHOOL }, STUDENT)).toEqual({ removed: true });
    expect((await review(STUDENT).get()).exists).toBe(false);
    expect(await numbers()).toEqual({ ratingSum: 9, ratingCount: 2, ratingAvg: 4.5 });
    // Nothing left to remove; the others' reviews are untouched.
    expect(await remove({ instructorUid: SCHOOL }, STUDENT)).toEqual({ removed: false });
    expect((await school().collection('reviews').get()).size).toBe(2);
  });

  it('the last review gone leaves 0 / 0 / 0', async () => {
    await review('seed-a').delete();
    await review('seed-b').delete();
    await school().update({ ratingSum: 0, ratingCount: 0, ratingAvg: 0 });
    await submit({ bookingId: 'rv-done', rating: 4 }, STUDENT);
    expect(await numbers()).toEqual({ ratingSum: 4, ratingCount: 1, ratingAvg: 4 });
    await remove({ instructorUid: SCHOOL }, STUDENT);
    expect(await numbers()).toEqual({ ratingSum: 0, ratingCount: 0, ratingAvg: 0 });
  });
});

describe('getInstructorReviews', () => {
  it('sends the opaque id, never the author\'s uid or booking', async () => {
    await submit({ bookingId: 'rv-done', rating: 3, comment: 'Ok' }, STUDENT);
    const res: any = await list({ id: SCHOOL }, OTHER);
    const anna = res.reviews.find((r: any) => r.name === 'Anna K.');
    expect(anna).toEqual({ id: (await review(STUDENT).get()).get('reviewId'), name: 'Anna K.', rating: 3, comment: 'Ok', createdAtMs: expect.any(Number), mine: false });
    expect(JSON.stringify(res)).not.toContain(STUDENT);
    expect(JSON.stringify(res)).not.toContain('rv-done');
  });

  it('marks the caller\'s own review, and only that one', async () => {
    await submit({ bookingId: 'rv-done', rating: 3 }, STUDENT);
    const res: any = await list({ id: SCHOOL }, STUDENT);
    expect(res.reviews.filter((r: any) => r.mine).map((r: any) => r.name)).toEqual(['Anna K.']);
    expect(JSON.stringify(res)).not.toContain(STUDENT);
  });
});

describe('reportReview', () => {
  it('a paid student reports a review: the report names it by its opaque id and keeps a copy', async () => {
    expect(await report({ instructorUid: SCHOOL, reviewId: 'opaque-a', reason: 'spam', language: 'ru', state: 'IL' }, OTHER))
      .toEqual({ reported: true });
    const snap = await db().collection('reports').where('userId', '==', OTHER).where('contentType', '==', 'review').get();
    expect(snap.size).toBe(1);
    expect(snap.docs[0].data()).toMatchObject({
      reason: 'spam', contentType: 'review', status: 'open', userId: OTHER, language: 'ru', state: 'IL',
      entity: { instructorUid: SCHOOL, reviewId: 'opaque-a' }, review: { rating: 5, comment: 'Great' },
    });
    // The author's uid never reaches the report the reporter can read back.
    expect(JSON.stringify(snap.docs[0].data())).not.toContain('seed-a');
  });

  it('the instructor reports a review on their own profile', async () => {
    await report({ instructorUid: SCHOOL, reviewId: 'opaque-b', reason: 'other', message: 'Never had a lesson with us' }, SCHOOL);
    const snap = await db().collection('reports').where('userId', '==', SCHOOL).where('contentType', '==', 'review').get();
    expect(snap.docs[0].data()).toMatchObject({ reason: 'other', message: 'Never had a lesson with us' });
  });

  it('refuses an unknown review, the reporter\'s own, a trial student and bad reasons', async () => {
    await expect(report({ instructorUid: SCHOOL, reviewId: 'nope', reason: 'spam' }, OTHER)).rejects.toMatchObject({ code: 'not-found' });
    await submit({ bookingId: 'rv-done', rating: 2 }, STUDENT);
    const own = (await review(STUDENT).get()).get('reviewId');
    await expect(report({ instructorUid: SCHOOL, reviewId: own, reason: 'spam' }, STUDENT))
      .rejects.toMatchObject({ code: 'failed-precondition', message: 'own-review' });
    await expect(report({ instructorUid: SCHOOL, reviewId: 'opaque-a', reason: 'spam' }, TRIAL)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(report({ instructorUid: SCHOOL, reviewId: 'opaque-a', reason: 'fake_profile' }, OTHER)).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(report({ instructorUid: SCHOOL, reviewId: 'opaque-a', reason: 'other', message: 'short' }, OTHER)).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});

describe('the review push on completion (plan v2 §12)', () => {
  it('asks the student once the lesson is completed, in their language, linking the lesson', async () => {
    await lesson('rv-ended', STUDENT, 'confirmed', { completeAfter: admin.firestore.Timestamp.fromMillis(Date.now() - 60e3) });
    await runMarkBookingsCompleted();
    expect((await db().collection('bookings').doc('rv-ended').get()).get('status')).toBe('completed');
    expect(pushes.filter((p) => p.route === 'booking/rv-ended'))
      .toEqual([{ token: 'tok-s', title: 'Как прошёл урок?', body: 'Оставьте отзыв: Lakeview Driving School', route: 'booking/rv-ended' }]);
    // A second run finds nothing to complete and sends nothing.
    await runMarkBookingsCompleted();
    expect(pushes.filter((p) => p.route === 'booking/rv-ended')).toHaveLength(1);
  });

  it('does not ask a student who already reviewed this school', async () => {
    await submit({ bookingId: 'rv-done', rating: 5 }, STUDENT);
    await lesson('rv-ended', STUDENT, 'confirmed', { completeAfter: admin.firestore.Timestamp.fromMillis(Date.now() - 60e3) });
    await runMarkBookingsCompleted();
    expect((await db().collection('bookings').doc('rv-ended').get()).get('status')).toBe('completed');
    expect(pushes.filter((p) => p.route === 'booking/rv-ended')).toEqual([]);
  });
});

describe('account deletion (plan v2 §17)', () => {
  it('finds the reviews a student wrote through their bookings', async () => {
    await submit({ bookingId: 'rv-done', rating: 2 }, STUDENT);
    const plan = await collectUserDataForDeletion(db(), STUDENT);
    const t = plan.filter((p) => p.action === 'unreview');
    expect(t).toHaveLength(1);
    expect(t[0].ref.path).toBe(`instructors/${SCHOOL}/reviews/${STUDENT}`);
  });

  it('deleteUserAccount removes them and adjusts the numbers; other reviews stay', async () => {
    await db().collection('users').doc('rv-gone').set({ name: 'Gone Student' });
    await lesson('rv-gone-lesson', 'rv-gone', 'completed');
    await submit({ bookingId: 'rv-gone-lesson', rating: 1 }, 'rv-gone');
    expect(await numbers()).toEqual({ ratingSum: 10, ratingCount: 3, ratingAvg: 3.3 });
    await call(fns.deleteUserAccount)({}, 'rv-gone');
    expect((await review('rv-gone').get()).exists).toBe(false);
    expect(await numbers()).toEqual({ ratingSum: 9, ratingCount: 2, ratingAvg: 4.5 });
    expect((await school().collection('reviews').get()).size).toBe(2);
    // The booking itself stays, anonymised.
    expect((await db().collection('bookings').doc('rv-gone-lesson').get()).get('studentUid')).toBe('deleted_rv-gone');
  });
});
