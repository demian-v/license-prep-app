/**
 * Instructors plan v2 §13 — the detail page reads one instructor through
 * getInstructorProfile and their reviews through getInstructorReviews. Both
 * must refuse trial users, reach only a listed instructor of a launched state,
 * and never let a private field (or the reviewer's uid) out.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';

const db = () => admin.firestore();
const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } } });
const inDays = (d: number) => admin.firestore.Timestamp.fromMillis(Date.now() + d * 864e5);
const profile = (data: unknown, uid = 'ip-paid-user') =>
  testEnv.wrap(fns.getInstructorProfile as any)(data as any, ctx(uid) as any);
const reviews = (data: unknown, uid = 'ip-paid-user') =>
  testEnv.wrap(fns.getInstructorReviews as any)(data as any, ctx(uid) as any);

const availability = { mon: [{ start: '09:00', end: '12:00' }] };
const base = {
  kind: 'school', name: 'Lakeview', state: 'ZP', city: 'Chicago', languages: ['en'],
  hourlyRateCents: 6000, lessonDurations: [60], stage: 2, ratingAvg: 4.5, ratingCount: 2,
  status: 'active', listed: true, ratingSum: 9, idCheck: 'passed', licenseCheck: 'passed',
  timezone: 'America/Chicago', availability, photoPath: null, photoApproved: false,
};

beforeAll(async () => {
  await db().collection('subscriptions').doc('ip-paid').set({
    userId: 'ip-paid-user', isActive: true, planType: 'monthly', nextBillingDate: inDays(20),
  });
  await db().collection('subscriptions').doc('ip-trial').set({
    userId: 'ip-trial-user', isActive: true, planType: 'trial', nextBillingDate: inDays(2),
  });
  // ZP is a fixture-only launched state, ZQ one that is not (own codes, so
  // list-instructors' ZI fixtures never see these).
  await db().collection('config').doc('instructors').set({ launchStates: ['ZP'] });
  await db().collection('instructors').doc('ip-1').set(base);
  await db().collection('instructors').doc('ip-unlisted').set({ ...base, listed: false, status: 'deactivated' });
  await db().collection('instructors').doc('ip-other').set({ ...base, state: 'ZQ' });
  await db().collection('instructors').doc('ip-private').set({ ...base, kind: 'schoolInstructor', licenseCheck: 'pending' });
  const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
  await db().collection('instructors').doc('ip-1').collection('reviews').doc('student-uid-a').set({
    studentDisplayName: 'Anna K.', rating: 5, comment: 'Great', lastBookingId: 'b-1', createdAt: at(1000), updatedAt: at(1000),
  });
  await db().collection('instructors').doc('ip-1').collection('reviews').doc('student-uid-b').set({
    studentDisplayName: 'Jake M.', rating: 4, comment: 'Good', lastBookingId: 'b-2', createdAt: at(2000), updatedAt: at(2000),
  });
});

afterAll(() => testEnv.cleanup());

describe('getInstructorProfile', () => {
  it('refuses a trial user', async () => {
    await expect(profile({ id: 'ip-1' }, 'ip-trial-user')).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects a missing or malformed id', async () => {
    await expect(profile({})).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(profile({ id: '../ip-1' })).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it.each([['ip-unlisted'], ['ip-other'], ['ip-missing']])('answers not-found for %s', async (id) => {
    await expect(profile({ id })).rejects.toMatchObject({ code: 'not-found' });
  });

  it('returns the public projection plus the weekly hours and timezone', async () => {
    const res = await profile({ id: 'ip-1' });
    expect(res).toMatchObject({ id: 'ip-1', name: 'Lakeview', hourlyRateCents: 6000, availability, timezone: 'America/Chicago' });
    for (const hidden of ['listed', 'ratingSum', 'idCheck', 'licenseCheck', 'status', 'photoApproved']) {
      expect(res).not.toHaveProperty(hidden);
    }
  });

  it('hides a private instructor\'s price until the licence is checked', async () => {
    const res = await profile({ id: 'ip-private' });
    expect(res.priceHidden).toBe(true);
    expect(res).not.toHaveProperty('hourlyRateCents');
  });
});

describe('getInstructorReviews', () => {
  it('refuses a trial user', async () => {
    await expect(reviews({ id: 'ip-1' }, 'ip-trial-user')).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('answers not-found for an unlisted instructor', async () => {
    await expect(reviews({ id: 'ip-unlisted' })).rejects.toMatchObject({ code: 'not-found' });
  });

  it('returns the newest first, without the reviewer\'s uid or booking', async () => {
    const res = await reviews({ id: 'ip-1' });
    // `id` is the opaque reviewId (P8); these fixtures predate it.
    expect(res.reviews).toEqual([
      { id: null, name: 'Jake M.', rating: 4, comment: 'Good', createdAtMs: 2000, mine: false },
      { id: null, name: 'Anna K.', rating: 5, comment: 'Great', createdAtMs: 1000, mine: false },
    ]);
    expect(JSON.stringify(res)).not.toContain('student-uid');
    expect(JSON.stringify(res)).not.toContain('b-1');
  });
});
