/**
 * Instructors plan v2 §18a (P10a) — the admin dashboard's callables, against
 * the emulator with a fake Stripe client (no request leaves jest): every one
 * refuses non-admins; hiding a review takes it out of the numbers and the
 * lists and puts it back; reports, suspension and licence review are
 * reversible; the expiry cron; no-show and lost-dispute money paths look for
 * a transfer by `transfer_group` before paying (risk register, P9); the
 * three-school-cancellations alert; the board's reads.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { runExpireInstructorLicenses, noteSchoolCancellation } from '../admin';
import { runReleaseInstructorPayouts } from '../payments';
import { setStripeClient } from '../stripe-client';
import { setPushTransport } from '../push';
import { computeListing } from '../instructors';

const db = () => admin.firestore();
const ADMIN = 'adm-admin';
const PLAIN = 'adm-plain';
const STUDENT = 'adm-student';
const OTHER = 'adm-student2';
const SCHOOL = 'adm-school';
const ACCT = 'acct_test_adm_school';
const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' }, auth_time: Math.floor(Date.now() / 1000) } } });
const call = (fn: any) => (data: unknown, uid = ADMIN) => testEnv.wrap(fn)(data as any, ctx(uid) as any) as Promise<any>;
const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const inDays = (d: number) => ts(Date.now() + d * 864e5);
const school = () => db().collection('instructors').doc(SCHOOL);
const booking = (id: string) => db().collection('bookings').doc(id);

const ADMIN_CALLABLES = [
  'adminGetQueue', 'adminListInstructors', 'adminGetBookings', 'adminSetReportStatus', 'adminHideReview',
  'adminSetInstructorStatus', 'adminReviewLicense', 'adminSetInReview', 'adminResolveNoShow', 'adminResolveLostDispute',
  'adminGetLicenseImage',
] as const;

// ── Fake Stripe ──────────────────────────────────────────────────────────────

let calls: Record<string, any[]> = {};
/** What transfers.list returns for a transfer_group. */
let existing: Record<string, { id: string; reversed: boolean }[]> = {};
const record = (name: string, c: unknown) => (calls[name] ??= []).push(c);
const fake = {
  transfers: {
    async list(params: any) {
      record('transfers.list', params);
      return { data: existing[params.transfer_group] ?? [] };
    },
    async create(params: any, options: any) {
      record('transfers.create', { params, options });
      return { id: `tr_new_${params.metadata.bookingId}` };
    },
    async createReversal(id: string, params: any, options: any) {
      record('transfers.createReversal', { id, params, options });
      return { id: 'trr_test' };
    },
  },
  refunds: {
    async create(params: any, options: any) {
      record('refunds.create', { params, options });
      return { id: 're_test' };
    },
  },
};

let pushes: { token: string; title?: string; route?: string }[] = [];

async function wipe() {
  await db().recursiveDelete(school());
  await db().collection('instructorPrivate').doc(SCHOOL).delete();
  for (const field of ['instructorUid', 'studentUid']) {
    const snap = await db().collection('bookings').where(field, '==', field === 'studentUid' ? STUDENT : SCHOOL).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
  const reports = await db().collection('reports').where('userId', 'in', [STUDENT, OTHER, 'system']).get();
  await Promise.all(reports.docs.map((d) => d.ref.delete()));
}

async function seedSchool(over: Record<string, unknown> = {}) {
  await school().set({
    kind: 'school', name: 'Admin Test Driving School', state: 'ZQ', city: 'Springfield', languages: ['en'],
    hourlyRateCents: 6500, lessonDurations: [60], status: 'active', listed: true, stage: 0,
    idCheck: 'none', licenseCheck: 'pending', schoolLicenseNumber: 'IL-12345', licenseState: 'ZQ', licenseExpiresAt: null,
    ratingSum: 9, ratingCount: 2, ratingAvg: 4.5, updatedAt: ts(Date.now()), createdAt: ts(Date.now()), ...over,
  });
  await db().collection('instructorPrivate').doc(SCHOOL).set({ stripeAccountId: ACCT, licenseNumber: null });
}

async function seedReview(studentUid: string, reviewId: string, rating: number, comment = 'Great lesson') {
  await school().collection('reviews').doc(studentUid).set({
    reviewId, studentDisplayName: 'Anna K.', rating, comment, lastBookingId: `${reviewId}-b`,
    createdAt: ts(Date.now()), updatedAt: ts(Date.now()),
  });
}

/** A lesson the student reported as not given, paid through Stripe. */
async function disputed(id: string, over: Record<string, unknown> = {}) {
  await booking(id).set({
    studentUid: STUDENT, instructorUid: SCHOOL, instructorName: 'Admin Test Driving School', studentDisplayName: 'Anna K.',
    status: 'disputed', startAt: inDays(-1), durationMinutes: 60, timezone: 'America/Chicago',
    lessonCents: 6500, platformFeeCents: 1625, totalCents: 8125, paymentProvider: 'stripe',
    stripePaymentIntentId: `pi_${id}`, stripeChargeId: `ch_${id}`, payoutReleaseAt: inDays(1),
    noShowReason: 'instructor_no_show', noShowReportedAt: ts(Date.now()), createdAt: inDays(-3), ...over,
  });
}

beforeAll(async () => {
  await db().collection('admins').doc(ADMIN).set({ note: 'test fixture' });
  await db().collection('admins').doc(PLAIN).delete();
  await db().collection('subscriptions').doc('adm-paid').set({ userId: STUDENT, isActive: true, planType: 'monthly', nextBillingDate: inDays(20) });
  await db().collection('config').doc('instructors').set({ launchStates: ['ZQ'] }, { merge: true });
  await db().collection('users').doc(STUDENT).set({ name: 'Anna Kowalska', language: 'en' });
  await db().collection('users').doc(SCHOOL).set({ language: 'ru' });
  await db().collection('users').doc(SCHOOL).collection('fcmTokens').doc('t').set({ token: 'tok-school', platform: 'ios' });
  await db().collection('users').doc(STUDENT).collection('fcmTokens').doc('t').set({ token: 'tok-student', platform: 'ios' });
});

beforeEach(async () => {
  await wipe();
  calls = {};
  existing = {};
  pushes = [];
  setStripeClient(fake);
  setPushTransport({
    async send(messages) {
      pushes.push(...messages.map((m) => ({ token: m.token, title: m.notification?.title, route: m.data?.route })));
      return messages.map(() => null);
    },
  });
});

afterAll(async () => {
  await wipe();
  setStripeClient(null);
  setPushTransport(null);
  testEnv.cleanup();
});

describe('every admin callable refuses non-admins', () => {
  it.each(ADMIN_CALLABLES)('%s: unauthenticated', async (name) => {
    await expect(testEnv.wrap((fns as any)[name])({} as any, {} as any)).rejects.toMatchObject({ code: 'unauthenticated' });
  });
  it.each(ADMIN_CALLABLES)('%s: a signed-in non-admin', async (name) => {
    await expect(call((fns as any)[name])({}, PLAIN)).rejects.toMatchObject({ code: 'permission-denied' });
  });
  it('the reads serve an admin', async () => {
    await expect(call(fns.adminGetQueue)({})).resolves.toHaveProperty('items');
    await expect(call(fns.adminListInstructors)({})).resolves.toHaveProperty('instructors');
    await expect(call(fns.adminGetBookings)({ days: 7 })).resolves.toMatchObject({ days: 7 });
  });
});

describe('adminHideReview — hide, never delete (§18a)', () => {
  beforeEach(async () => {
    await seedSchool({ ratingSum: 9, ratingCount: 2, ratingAvg: 4.5 });
    await seedReview(STUDENT, 'rvA', 4);
    await seedReview(OTHER, 'rvB', 5, 'Fine');
    await db().collection('reports').doc('adm-rep-1').set({
      contentType: 'review', reason: 'inappropriate', entity: { instructorUid: SCHOOL, reviewId: 'rvA' },
      review: { rating: 4, comment: 'Great lesson' }, userId: OTHER, status: 'open', createdAt: ts(Date.now()),
    });
  });
  const numbers = async () => {
    const d = (await school().get()).data()!;
    return [d.ratingSum, d.ratingCount, d.ratingAvg];
  };

  it('takes it out of the numbers and resolves the report; unhide puts both back', async () => {
    await call(fns.adminHideReview)({ instructorUid: SCHOOL, reviewId: 'rvA', reportId: 'adm-rep-1' });
    expect(await numbers()).toEqual([5, 1, 5]);
    const r = (await school().collection('reviews').doc(STUDENT).get()).data()!;
    expect(r).toMatchObject({ hidden: true, hiddenBy: ADMIN, hiddenReportId: 'adm-rep-1', comment: 'Great lesson' });
    expect((await db().collection('reports').doc('adm-rep-1').get()).data()).toMatchObject({ status: 'resolved', resolution: 'review_hidden', resolvedBy: ADMIN });

    // Hiding twice changes nothing.
    await call(fns.adminHideReview)({ instructorUid: SCHOOL, reviewId: 'rvA' });
    expect(await numbers()).toEqual([5, 1, 5]);

    await call(fns.adminHideReview)({ instructorUid: SCHOOL, reviewId: 'rvA', reportId: 'adm-rep-1', hidden: false });
    expect(await numbers()).toEqual([9, 2, 4.5]);
    expect((await school().collection('reviews').doc(STUDENT).get()).get('hidden')).toBeUndefined();
    const rep = (await db().collection('reports').doc('adm-rep-1').get()).data()!;
    expect(rep.status).toBe('open');
    expect(rep.resolvedAt).toBeUndefined();
  });

  it('students stop seeing it, its author still does; it cannot be reported', async () => {
    await call(fns.adminHideReview)({ instructorUid: SCHOOL, reviewId: 'rvA' });
    await db().collection('subscriptions').doc('adm-paid2').set({ userId: OTHER, isActive: true, planType: 'monthly', nextBillingDate: inDays(20) });
    const asOther = await call(fns.getInstructorReviews)({ id: SCHOOL }, OTHER);
    expect(asOther.reviews.map((r: any) => r.id)).toEqual(['rvB']);
    const asAuthor = await call(fns.getInstructorReviews)({ id: SCHOOL }, STUDENT);
    expect(asAuthor.reviews.map((r: any) => r.id).sort()).toEqual(['rvA', 'rvB']);
    await expect(call(fns.reportReview)({ instructorUid: SCHOOL, reviewId: 'rvA', reason: 'spam' }, OTHER))
      .rejects.toMatchObject({ code: 'not-found' });
  });

  it("an author's edit keeps it hidden and out of the numbers; deleting it doesn't subtract twice", async () => {
    await call(fns.adminHideReview)({ instructorUid: SCHOOL, reviewId: 'rvA' });
    await booking('rvA-b').set({ studentUid: STUDENT, instructorUid: SCHOOL, status: 'completed', startAt: inDays(-2), durationMinutes: 60 });
    await call(fns.submitReview)({ bookingId: 'rvA-b', rating: 1, comment: 'Changed' }, STUDENT);
    expect(await numbers()).toEqual([5, 1, 5]);
    expect((await school().collection('reviews').doc(STUDENT).get()).data()).toMatchObject({ hidden: true, rating: 1, comment: 'Changed', hiddenBy: ADMIN });
    await call(fns.deleteReview)({ instructorUid: SCHOOL }, STUDENT);
    expect(await numbers()).toEqual([5, 1, 5]);
  });

  it('an unknown review is not-found', async () => {
    await expect(call(fns.adminHideReview)({ instructorUid: SCHOOL, reviewId: 'nope' })).rejects.toMatchObject({ code: 'not-found' });
  });
});

describe('adminSetReportStatus / adminSetInReview', () => {
  beforeEach(async () => {
    await db().collection('reports').doc('adm-rep-2').set({
      contentType: 'quiz_question', reason: 'translation', entity: { questionId: 'q1', path: 'x' }, userId: STUDENT, status: 'open', createdAt: ts(Date.now()),
    });
  });
  it('dismisses, resolves and reopens', async () => {
    const rep = () => db().collection('reports').doc('adm-rep-2').get();
    await call(fns.adminSetReportStatus)({ reportId: 'adm-rep-2', status: 'dismissed' });
    expect((await rep()).data()).toMatchObject({ status: 'dismissed', resolution: 'dismissed', resolvedBy: ADMIN });
    await call(fns.adminSetReportStatus)({ reportId: 'adm-rep-2', status: 'open' });
    expect((await rep()).get('resolvedAt')).toBeUndefined();
    await call(fns.adminSetReportStatus)({ reportId: 'adm-rep-2', status: 'resolved' });
    expect((await rep()).get('resolution')).toBe('resolved');
    await expect(call(fns.adminSetReportStatus)({ reportId: 'adm-rep-2', status: 'deleted' })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(call(fns.adminSetReportStatus)({ reportId: 'missing', status: 'open' })).rejects.toMatchObject({ code: 'not-found' });
  });
  it('marks items in review, and refuses a resolved report', async () => {
    await call(fns.adminSetInReview)({ type: 'report', id: 'adm-rep-2' });
    expect((await db().collection('reports').doc('adm-rep-2').get()).get('status')).toBe('in_review');
    await seedSchool();
    await call(fns.adminSetInReview)({ type: 'licence', id: SCHOOL });
    expect((await db().collection('instructorPrivate').doc(SCHOOL).get()).get('adminReviewingAt')).toBeDefined();
    await call(fns.adminSetInReview)({ type: 'licence', id: SCHOOL, on: false });
    expect((await db().collection('instructorPrivate').doc(SCHOOL).get()).get('adminReviewingAt')).toBeUndefined();
    await call(fns.adminSetReportStatus)({ reportId: 'adm-rep-2', status: 'dismissed' });
    await expect(call(fns.adminSetInReview)({ type: 'report', id: 'adm-rep-2' })).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});

describe('adminSetInstructorStatus', () => {
  it('suspends (unlisted by computeListing) and lifts back to the status it had', async () => {
    await seedSchool({ status: 'deactivated' });
    await db().collection('reports').doc('adm-rep-3').set({ contentType: 'instructor', reason: 'fake_profile', entity: { instructorUid: SCHOOL }, userId: STUDENT, status: 'open', createdAt: ts(Date.now()) });
    await call(fns.adminSetInstructorStatus)({ uid: SCHOOL, status: 'suspended', reportId: 'adm-rep-3' });
    const s = (await school().get()).data()!;
    expect(s).toMatchObject({ status: 'suspended', statusBeforeSuspension: 'deactivated', suspendedBy: ADMIN });
    expect(computeListing(s).listed).toBe(false);
    expect((await db().collection('reports').doc('adm-rep-3').get()).get('resolution')).toBe('instructor_suspended');

    await call(fns.adminSetInstructorStatus)({ uid: SCHOOL, status: 'active', reportId: 'adm-rep-3' });
    const l = (await school().get()).data()!;
    expect(l.status).toBe('deactivated');
    expect(l.statusBeforeSuspension).toBeUndefined();
    expect((await db().collection('reports').doc('adm-rep-3').get()).get('status')).toBe('open');
  });
  it('a suspended school cannot start payouts', async () => {
    await seedSchool();
    await call(fns.adminSetInstructorStatus)({ uid: SCHOOL, status: 'suspended' });
    await expect(call(fns.startInstructorPayouts)({}, SCHOOL)).rejects.toMatchObject({ code: 'failed-precondition', message: 'suspended' });
  });
});

describe('adminReviewLicense + expireInstructorLicenses', () => {
  beforeEach(() => seedSchool());
  it('approves until a future date, rejects, and goes back to pending', async () => {
    await expect(call(fns.adminReviewLicense)({ uid: SCHOOL, approved: true, expiresAtMs: Date.now() - 1000 })).rejects.toMatchObject({ code: 'invalid-argument' });
    const until = Date.now() + 365 * 864e5;
    await call(fns.adminReviewLicense)({ uid: SCHOOL, approved: true, expiresAtMs: until });
    expect((await school().get()).data()).toMatchObject({ licenseCheck: 'passed', licenseReviewedBy: ADMIN });
    expect((await school().get()).get('licenseExpiresAt').toMillis()).toBe(until);
    await call(fns.adminReviewLicense)({ uid: SCHOOL, approved: false });
    expect((await school().get()).data()).toMatchObject({ licenseCheck: 'rejected', licenseExpiresAt: null });
    await call(fns.adminReviewLicense)({ uid: SCHOOL, approved: null });
    const p = (await school().get()).data()!;
    expect(p.licenseCheck).toBe('pending');
    expect(p.licenseReviewedAt).toBeUndefined();
  });
  it('refuses a profile with no licence number', async () => {
    await school().update({ licenseCheck: 'none' });
    await expect(call(fns.adminReviewLicense)({ uid: SCHOOL, approved: false })).rejects.toMatchObject({ code: 'failed-precondition' });
  });
  it('the daily job expires a passed licence past its date, once, with a push', async () => {
    await school().update({ licenseCheck: 'passed', licenseExpiresAt: inDays(-1) });
    await runExpireInstructorLicenses();
    expect((await school().get()).get('licenseCheck')).toBe('expired');
    expect(computeListing((await school().get()).data()!).stage).toBe(0);
    expect(pushes).toEqual([expect.objectContaining({ token: 'tok-school', title: 'Срок лицензии истёк', route: 'profile' })]);
    await runExpireInstructorLicenses();
    expect(pushes).toHaveLength(1);
  });
  it('leaves a licence not yet expired, and a rejected one', async () => {
    await school().update({ licenseCheck: 'passed', licenseExpiresAt: inDays(5) });
    await runExpireInstructorLicenses();
    expect((await school().get()).get('licenseCheck')).toBe('passed');
    expect(pushes).toHaveLength(0);
  });
});

describe('adminResolveNoShow (§9.3)', () => {
  beforeEach(() => seedSchool());

  it('refund: returns the payment in full and tells the student', async () => {
    await disputed('adm-ns-1');
    const res = await call(fns.adminResolveNoShow)({ bookingId: 'adm-ns-1', outcome: 'refund' });
    expect(res).toMatchObject({ status: 'refunded', refundStatus: 'succeeded' });
    expect(calls['transfers.list']).toEqual([expect.objectContaining({ transfer_group: 'adm-ns-1' })]);
    expect(calls['transfers.createReversal']).toBeUndefined();
    expect(calls['refunds.create']).toHaveLength(1);
    const b = (await booking('adm-ns-1').get()).data()!;
    expect(b).toMatchObject({ cancelledBy: 'admin', noShowResolution: 'refund', noShowResolvedBy: ADMIN });
    expect(b.payoutReleaseAt).toBeUndefined();
    expect(pushes.map((p) => p.token)).toEqual(['tok-student']);
  });

  it('refund after a transfer made in the same instant as the report: found by transfer_group, reversed first', async () => {
    await disputed('adm-ns-2');
    existing['adm-ns-2'] = [{ id: 'tr_race', reversed: false }];
    await call(fns.adminResolveNoShow)({ bookingId: 'adm-ns-2', outcome: 'refund' });
    expect(calls['transfers.createReversal']).toEqual([expect.objectContaining({ id: 'tr_race' })]);
    expect((await booking('adm-ns-2').get()).data()).toMatchObject({ stripeTransferId: 'tr_race', stripeTransferReversalId: 'trr_test', refundStatus: 'succeeded' });
  });

  it('release with no transfer: due now, and the hourly job pays it', async () => {
    await disputed('adm-ns-3');
    const res = await call(fns.adminResolveNoShow)({ bookingId: 'adm-ns-3', outcome: 'release' });
    expect(res.status).toBe('completed');
    await expect(call(fns.reportNoShow)({ bookingId: 'adm-ns-3' }, STUDENT)).rejects.toMatchObject({ message: 'not-reportable' });
    await runReleaseInstructorPayouts();
    expect(calls['transfers.create']).toHaveLength(1);
    expect((await booking('adm-ns-3').get()).data()).toMatchObject({ status: 'payout_released', stripeTransferId: 'tr_new_adm-ns-3' });
  });

  it('release when Stripe already shows a transfer: recorded as paid, nothing paid again', async () => {
    await disputed('adm-ns-4');
    existing['adm-ns-4'] = [{ id: 'tr_old_reversed', reversed: true }, { id: 'tr_race', reversed: false }];
    const res = await call(fns.adminResolveNoShow)({ bookingId: 'adm-ns-4', outcome: 'release' });
    expect(res.status).toBe('payout_released');
    await runReleaseInstructorPayouts();
    expect(calls['transfers.create']).toBeUndefined();
    expect((await booking('adm-ns-4').get()).get('stripeTransferId')).toBe('tr_race');
  });

  it('an emulator-paid lesson never asks Stripe', async () => {
    await disputed('adm-ns-5', { paymentProvider: 'emulator', stripePaymentIntentId: null, stripeChargeId: null });
    const res = await call(fns.adminResolveNoShow)({ bookingId: 'adm-ns-5', outcome: 'refund' });
    expect(res.status).toBe('refunded');
    expect(calls).toEqual({});
    expect((await booking('adm-ns-5').get()).get('refundedAt')).toBeDefined();
  });

  it('refuses a lesson that is not disputed, or a bad outcome', async () => {
    await disputed('adm-ns-6', { status: 'completed' });
    await expect(call(fns.adminResolveNoShow)({ bookingId: 'adm-ns-6', outcome: 'refund' })).rejects.toMatchObject({ message: 'not-disputed' });
    await expect(call(fns.adminResolveNoShow)({ bookingId: 'adm-ns-6', outcome: 'keep' })).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});

describe('adminResolveLostDispute', () => {
  beforeEach(() => seedSchool());
  const lost = (id: string, over: Record<string, unknown> = {}) => disputed(id, {
    status: 'completed', noShowReason: null, noShowReportedAt: null, payoutReleaseAt: null,
    disputeStatus: 'lost', payoutCancelledAt: ts(Date.now()), ...over,
  });

  it('pay: a transfer from the platform balance, recorded, once', async () => {
    await lost('adm-ld-1');
    const res = await call(fns.adminResolveLostDispute)({ bookingId: 'adm-ld-1', outcome: 'pay' });
    expect(res.transferId).toBe('tr_new_adm-ld-1');
    const [t] = calls['transfers.create'];
    expect(t.params).toMatchObject({ amount: 6500, destination: ACCT, transfer_group: 'adm-ld-1' });
    expect(t.params.source_transaction).toBeUndefined();
    expect((await booking('adm-ld-1').get()).data()).toMatchObject({ status: 'payout_released', lostDisputeResolution: 'pay', stripeTransferId: 'tr_new_adm-ld-1' });
    await expect(call(fns.adminResolveLostDispute)({ bookingId: 'adm-ld-1', outcome: 'pay' })).rejects.toMatchObject({ message: 'not-a-lost-dispute' });
  });

  it('pay when a transfer already exists: no second one', async () => {
    await lost('adm-ld-2');
    existing['adm-ld-2'] = [{ id: 'tr_before', reversed: false }];
    const res = await call(fns.adminResolveLostDispute)({ bookingId: 'adm-ld-2', outcome: 'pay' });
    expect(res.transferId).toBe('tr_before');
    expect(calls['transfers.create']).toBeUndefined();
  });

  it('keep unpaid: recorded, no money moves', async () => {
    await lost('adm-ld-3');
    await call(fns.adminResolveLostDispute)({ bookingId: 'adm-ld-3', outcome: 'keep_unpaid' });
    expect((await booking('adm-ld-3').get()).data()).toMatchObject({ status: 'completed', lostDisputeResolution: 'keep_unpaid' });
    expect(calls['transfers.create']).toBeUndefined();
  });

  it('refuses a dispute still open or won', async () => {
    await lost('adm-ld-4', { disputeStatus: 'open', payoutCancelledAt: null });
    await expect(call(fns.adminResolveLostDispute)({ bookingId: 'adm-ld-4', outcome: 'pay' })).rejects.toMatchObject({ message: 'not-a-lost-dispute' });
  });
});

describe('school cancellations alert (§9.3)', () => {
  const cancelled = (n: number, daysAgo: number, by = 'instructor') => booking(`adm-cx-${n}`).set({
    studentUid: STUDENT, instructorUid: SCHOOL, status: 'refunded', cancelledBy: by, cancelledAt: inDays(-daysAgo),
  });

  it('three in 30 days open one alert; more update its count; a closed one needs three new', async () => {
    await cancelled(1, 40);
    await cancelled(2, 10);
    await cancelled(3, 5, 'student');
    await cancelled(4, 3);
    expect(await noteSchoolCancellation(SCHOOL)).toBe(false);
    await cancelled(5, 1);
    expect(await noteSchoolCancellation(SCHOOL)).toBe(true);
    const ref = db().collection('reports').doc(`alert_cancellations_${SCHOOL}`);
    expect((await ref.get()).data()).toMatchObject({ contentType: 'school_cancellations', count: 3, status: 'open', userId: 'system' });
    await cancelled(6, 0);
    expect(await noteSchoolCancellation(SCHOOL)).toBe(false);
    expect((await ref.get()).get('count')).toBe(4);

    await call(fns.adminSetReportStatus)({ reportId: `alert_cancellations_${SCHOOL}`, status: 'dismissed' });
    await cancelled(7, 0);
    expect(await noteSchoolCancellation(SCHOOL, Date.now() + 1000)).toBe(false);
    expect((await ref.get()).get('status')).toBe('dismissed');
  });

  it('a school cancelling through cancelBooking raises it', async () => {
    await seedSchool();
    await cancelled(1, 3);
    await cancelled(2, 2);
    await booking('adm-cx-live').set({
      studentUid: STUDENT, instructorUid: SCHOOL, status: 'confirmed', startAt: inDays(3), durationMinutes: 60,
      timezone: 'America/Chicago', paymentProvider: 'emulator', instructorName: 'Admin Test Driving School', studentDisplayName: 'Anna K.',
    });
    await call(fns.cancelBooking)({ bookingId: 'adm-cx-live' }, SCHOOL);
    expect((await db().collection('reports').doc(`alert_cancellations_${SCHOOL}`).get()).get('count')).toBe(3);
  });
});

describe('the board (adminGetQueue)', () => {
  it('lists each kind with its stage, the stored review beside the current one', async () => {
    await seedSchool();
    await seedReview(OTHER, 'rvQ', 2, 'Edited since');
    await db().collection('reports').doc('adm-q-review').set({
      contentType: 'review', reason: 'spam', entity: { instructorUid: SCHOOL, reviewId: 'rvQ' },
      review: { rating: 1, comment: 'Original text' }, userId: STUDENT, status: 'in_review', createdAt: ts(Date.now()),
    });
    await db().collection('reports').doc('adm-q-old').set({
      contentType: 'theory_section', reason: 'other', entity: { topicDocId: 't', sectionIndex: 0, path: 'p' }, userId: STUDENT,
      status: 'dismissed', resolvedAt: inDays(-40), createdAt: inDays(-41),
    });
    await disputed('adm-q-ns');
    await disputed('adm-q-ld', { status: 'completed', disputeStatus: 'lost', payoutCancelledAt: ts(Date.now()) });

    const { items } = await call(fns.adminGetQueue)({});
    const byKey = Object.fromEntries(items.map((i: any) => [i.key, i]));
    expect(byKey['review:adm-q-review']).toMatchObject({
      stage: 'in_review', reported: { rating: 1, comment: 'Original text' }, current: { rating: 2, comment: 'Edited since', hidden: false },
      instructor: { name: 'Admin Test Driving School' },
    });
    expect(byKey['content:adm-q-old']).toBeUndefined();
    expect(byKey[`licence:${SCHOOL}`]).toMatchObject({ stage: 'new', schoolLicenseNumber: 'IL-12345' });
    expect(byKey['no_show:adm-q-ns']).toMatchObject({ stage: 'new', urgent: true, lessonCents: 6500, studentName: 'Anna K.' });
    expect(byKey['card_dispute:adm-q-ld']).toMatchObject({ stage: 'new', actionable: true, disputeStatus: 'lost' });
  });

  it('adminGetBookings: amounts, the state, no student names', async () => {
    await seedSchool();
    await disputed('adm-bk-1', { createdAt: ts(Date.now()) });
    const { bookings } = await call(fns.adminGetBookings)({ days: 7 });
    const row = bookings.find((b: any) => b.id === 'adm-bk-1');
    expect(row).toMatchObject({ state: 'ZQ', lessonCents: 6500, platformFeeCents: 1625, noShow: true });
    expect(JSON.stringify(row)).not.toContain('Anna');
  });
});

describe('adminGetLicenseImage (P10b)', () => {
  const BUCKET = 'demo-driveusa.appspot.com';
  it('returns the filed licence photo as a data URL; not-found without one', async () => {
    await seedSchool();
    await expect(call(fns.adminGetLicenseImage)({ uid: SCHOOL })).rejects.toMatchObject({ message: 'no-license-image' });
    const bytes = Buffer.from([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9]);
    await admin.storage().bucket(BUCKET).file(`instructorLicenses/${SCHOOL}/l1.jpg`).save(bytes, { contentType: 'image/jpeg' });
    await db().collection('instructorPrivate').doc(SCHOOL).set({ licenseImagePath: `instructorLicenses/${SCHOOL}/l1.jpg`, licenseImageBucket: BUCKET }, { merge: true });
    const res = await call(fns.adminGetLicenseImage)({ uid: SCHOOL });
    expect(res.dataUrl).toBe(`data:image/jpeg;base64,${bytes.toString('base64')}`);
    const { items } = await call(fns.adminGetQueue)({});
    expect(items.find((i: any) => i.key === `licence:${SCHOOL}`)).toMatchObject({ hasLicenseImage: true });
    await admin.storage().bucket(BUCKET).file(`instructorLicenses/${SCHOOL}/l1.jpg`).delete();
  });
});
