/**
 * Instructors plan v2 §3/§13 — listInstructors is the ONLY way a student reads
 * instructor data. It must refuse trial users, return only listed instructors
 * of a launched state, and never let a private or server-bookkeeping field out.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { publicInstructor } from '../instructors';

const db = () => admin.firestore();
const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } } });
const inDays = (d: number) => admin.firestore.Timestamp.fromMillis(Date.now() + d * 864e5);
const call = (data: unknown, uid: string) =>
  testEnv.wrap(fns.listInstructors as any)(data as any, ctx(uid) as any);

const base = {
  kind: 'school', name: 'Lakeview', state: 'ZI', city: 'Chicago', languages: ['en'],
  hourlyRateCents: 6000, stage: 2, ratingAvg: 4.5, ratingCount: 2, status: 'active',
  // Server bookkeeping and private-ish fields that must NOT be returned:
  listed: true, ratingSum: 9, idCheck: 'passed', licenseCheck: 'passed', timezone: 'America/Chicago',
  photoPath: 'instructorPhotos/li-1/a1.jpg', photoApproved: true, photoStatus: 'approved',
};

beforeAll(async () => {
  await db().collection('subscriptions').doc('li-paid').set({
    userId: 'li-paid-user', isActive: true, planType: 'monthly', nextBillingDate: inDays(20),
  });
  await db().collection('subscriptions').doc('li-trial').set({
    userId: 'li-trial-user', isActive: true, planType: 'trial', nextBillingDate: inDays(2),
  });
  // ZI / ZT are fixture-only state codes so the long-running seeded data never mixes in.
  await db().collection('config').doc('instructors').set({ launchStates: ['ZI'] });
  await db().collection('instructors').doc('li-1').set(base);
  await db().collection('instructors').doc('li-2').set({ ...base, name: 'Pending photo', photoApproved: false });
  await db().collection('instructors').doc('li-3').set({ ...base, name: 'Unlisted', listed: false, status: 'deactivated' });
  await db().collection('instructors').doc('li-4').set({ ...base, name: 'Other state', state: 'ZT' });
});

afterAll(() => testEnv.cleanup());

describe('listInstructors', () => {
  it('refuses a trial user', async () => {
    await expect(call({ state: 'ZI' }, 'li-trial-user')).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects a malformed state code', async () => {
    await expect(call({ state: 'Illinois' }, 'li-paid-user')).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('returns launched:false and no data for a state that has not launched', async () => {
    await expect(call({ state: 'ZT' }, 'li-paid-user')).resolves.toEqual({ launched: false, instructors: [] });
  });

  it('returns only the listed instructors of the requested state', async () => {
    const res = await call({ state: 'zi' }, 'li-paid-user');
    expect(res.launched).toBe(true);
    expect(res.instructors.map((i: any) => i.id).sort()).toEqual(['li-1', 'li-2']);
  });

  it('strips every field outside the public projection', async () => {
    const res = await call({ state: 'ZI' }, 'li-paid-user');
    for (const i of res.instructors) {
      for (const hidden of ['listed', 'ratingSum', 'idCheck', 'licenseCheck', 'timezone', 'photoApproved', 'photoStatus', 'status']) {
        expect(i).not.toHaveProperty(hidden);
      }
    }
  });

  it('returns a photo only once moderation approved it', async () => {
    const res = await call({ state: 'ZI' }, 'li-paid-user');
    const byId = Object.fromEntries(res.instructors.map((i: any) => [i.id, i]));
    expect(byId['li-1'].photoPath).toBe('instructorPhotos/li-1/a1.jpg');
    expect(byId['li-2'].photoPath).toBeNull();
  });
});

// Owner, 2026-09-30 (option A): a private instructor is listed, but their
// price is shown only once a licence number has been checked. A profile
// without a price is "here's who I am, message me", not an advertised paid
// lesson — 625 ILCS 5/6-401 covers "instruction for hire". Done here, in the
// one projection students receive, so no client can show it early.
describe('publicInstructor — private instructor price', () => {
  const priv = { ...base, kind: 'schoolInstructor', name: 'Carlos Diaz', lessonDurations: [60] };

  it.each(['none', 'pending', 'rejected', 'expired', undefined])('hides the price while licenseCheck is %s', (check) => {
    const out = publicInstructor('p-1', { ...priv, licenseCheck: check }) as any;
    expect(out).not.toHaveProperty('hourlyRateCents');
    expect(out.priceHidden).toBe(true);
    expect(out.lessonDurations).toEqual([60]);
  });

  it('shows the price once the licence is checked', () => {
    const out = publicInstructor('p-2', { ...priv, licenseCheck: 'passed' }) as any;
    expect(out.hourlyRateCents).toBe(6000);
    expect(out.priceHidden).toBe(false);
  });

  it('leaves a driving school\'s price as it is', () => {
    const out = publicInstructor('s-1', { ...base, licenseCheck: 'pending' }) as any;
    expect(out.hourlyRateCents).toBe(6000);
    expect(out.priceHidden).toBe(false);
  });
});
