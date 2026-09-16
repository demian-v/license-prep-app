/**
 * Risk #26 — the trial gate is forgeable, the dedupe is non-transactional, and
 * trialDevices is never cleaned up.
 *
 * Three separate problems, and only two of them are fixable in code:
 *
 *  (a) deviceIdHash and isPhysicalDevice are client-supplied. A modified client
 *      sends any 64-hex string and isPhysicalDevice:true for an endless supply
 *      of trials. NOT fixable here — it needs device attestation (App Check,
 *      DeviceCheck, Play Integrity). See SESSION.md.
 *  (b) both dedupe checks were read-then-write OUTSIDE a transaction, so two
 *      concurrent signups on one device could both pass. Fixed.
 *  (c) trialDevices records are never cleaned up and hold a userId. Deleting
 *      them on account deletion would turn account deletion into a trial
 *      farming tool, so they are anonymised instead. Fixed.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { anonymizeTrialDevicesForUser } from '../trial-devices';

const db = () => admin.firestore();
const ctx = (uid: string, emailVerified = true) =>
  ({ auth: { uid, token: { email_verified: emailVerified, firebase: { sign_in_provider: 'password' } } } });
const hash = (seed: string) => seed.padEnd(64, '0').slice(0, 64);

async function reset(deviceHash: string, ...userIds: string[]) {
  await db().collection('trialDevices').doc(deviceHash).delete().catch(() => {});
  for (const u of userIds) {
    const snap = await db().collection('subscriptions').where('userId', '==', u).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

afterAll(() => testEnv.cleanup());

describe('Risk #26 — the device dedupe must hold under concurrency', () => {
  it('grants exactly ONE trial when two accounts race on the same device', async () => {
    const h = hash('race-device');
    await reset(h, 'racer-a', 'racer-b');

    const wrapped = testEnv.wrap(fns.createTrialSubscription as any);
    const results = await Promise.allSettled([
      wrapped({ deviceIdHash: h, isPhysicalDevice: true } as any, ctx('racer-a') as any),
      wrapped({ deviceIdHash: h, isPhysicalDevice: true } as any, ctx('racer-b') as any),
    ]);

    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    expect(fulfilled).toHaveLength(1);

    const subs = await db().collection('subscriptions').where('deviceIdHash', '==', h).get();
    expect(subs.size).toBe(1);
  });

  it('still refuses a second trial on the same device sequentially', async () => {
    const h = hash('seq-device');
    await reset(h, 'seq-a', 'seq-b');
    const wrapped = testEnv.wrap(fns.createTrialSubscription as any);

    await wrapped({ deviceIdHash: h, isPhysicalDevice: true } as any, ctx('seq-a') as any);
    await expect(wrapped({ deviceIdHash: h, isPhysicalDevice: true } as any, ctx('seq-b') as any))
      .rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('grants a trial on a fresh device (positive control)', async () => {
    const h = hash('fresh-device');
    await reset(h, 'fresh-user');
    const wrapped = testEnv.wrap(fns.createTrialSubscription as any);
    const res: any = await wrapped({ deviceIdHash: h, isPhysicalDevice: true } as any, ctx('fresh-user') as any);
    expect(res.subscriptionId).toBeTruthy();
  });

  it('still rejects a malformed device hash', async () => {
    const wrapped = testEnv.wrap(fns.createTrialSubscription as any);
    await expect(wrapped({ deviceIdHash: 'too-short', isPhysicalDevice: true } as any, ctx('bad-hash') as any))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });
});

describe('Risk #26 — trialDevices is anonymised, not deleted, on account deletion', () => {
  it('strips the user link but keeps the device gate intact', async () => {
    const h = hash('delete-device');
    await db().collection('trialDevices').doc(h).set({
      firstUserId: 'departing-user',
      firstSubscriptionId: 'sub-123',
      createdAt: admin.firestore.Timestamp.now(),
    });

    const batch = db().batch();
    const count = await anonymizeTrialDevicesForUser(db(), batch, 'departing-user');
    await batch.commit();
    expect(count).toBe(1);

    const doc = await db().collection('trialDevices').doc(h).get();
    // Still present: deleting it would make account deletion a way to farm
    // unlimited trials.
    expect(doc.exists).toBe(true);
    expect(doc.get('firstUserId')).toBeUndefined();
    expect(doc.get('firstSubscriptionId')).toBeUndefined();
    expect(doc.get('anonymizedAt')).toBeTruthy();
  });

  it('is a no-op for a user with no device records', async () => {
    const batch = db().batch();
    const count = await anonymizeTrialDevicesForUser(db(), batch, 'user-with-no-devices');
    await batch.commit();
    expect(count).toBe(0);
  });
});


/**
 * Risk #12 — the trial is granted WITHOUT requiring a verified email.
 *
 * Product decision (owner, 2026-09-16): a registered user gets the 3-day trial
 * immediately and is blocked only once it expires. Verification belongs in the
 * signup flow, not in front of the trial. These tests exist so that intent is
 * not quietly reversed by a future "hardening" pass.
 */
describe('Risk #12 — a trial does NOT require a verified email', () => {
  it('grants the trial to a user whose email is not yet verified', async () => {
    const h = hash('unverified-dev');
    await reset(h, 'unverified-user');
    const wrapped = testEnv.wrap(fns.createTrialSubscription as any);
    const res: any = await wrapped(
      { deviceIdHash: h, isPhysicalDevice: true } as any,
      ctx('unverified-user', false) as any,
    );
    expect(res.subscriptionId).toBeTruthy();

    const subs = await db().collection('subscriptions').where('userId', '==', 'unverified-user').get();
    expect(subs.size).toBe(1);
    expect(subs.docs[0].get('planType')).toBe('trial');
    expect(subs.docs[0].get('isActive')).toBe(true);
  });

  it('grants the trial to a verified user too (positive control)', async () => {
    const h = hash('verified-dev');
    await reset(h, 'verified-user');
    const wrapped = testEnv.wrap(fns.createTrialSubscription as any);
    const res: any = await wrapped(
      { deviceIdHash: h, isPhysicalDevice: true } as any,
      ctx('verified-user', true) as any,
    );
    expect(res.subscriptionId).toBeTruthy();
  });
});
