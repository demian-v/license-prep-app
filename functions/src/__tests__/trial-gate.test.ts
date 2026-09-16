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
 * Risk #12 — sendEmailVerification() was never called and emailVerified gated
 * nothing, so a free trial cost an attacker nothing but a throwaway string.
 * Requiring a reachable inbox is what makes farming cost something — and it is
 * the only half of risk #26 enforceable server-side, since deviceIdHash is
 * client-supplied and unverifiable without attestation.
 */
describe('Risk #12 — a trial requires a verified email', () => {
  it('refuses a trial when the email is not verified', async () => {
    const wrapped = testEnv.wrap(fns.createTrialSubscription as any);
    await expect(wrapped(
      { deviceIdHash: hash('unverified-dev'), isPhysicalDevice: true } as any,
      ctx('unverified-user', false) as any,
    )).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('tells the client WHY, so it can say something specific', async () => {
    const wrapped = testEnv.wrap(fns.createTrialSubscription as any);
    // Risk #58: a refusal with no machine-readable reason is what left the UI
    // rendering an empty box.
    await expect(wrapped(
      { deviceIdHash: hash('unverified-dev2'), isPhysicalDevice: true } as any,
      ctx('unverified-user2', false) as any,
    )).rejects.toMatchObject({ details: { reason: 'email-not-verified' } });
  });

  it('writes nothing when it refuses', async () => {
    const h = hash('unverified-dev3');
    const wrapped = testEnv.wrap(fns.createTrialSubscription as any);
    await expect(wrapped(
      { deviceIdHash: h, isPhysicalDevice: true } as any,
      ctx('unverified-user3', false) as any,
    )).rejects.toBeDefined();

    const device = await db().collection('trialDevices').doc(h).get();
    expect(device.exists).toBe(false);
    const subs = await db().collection('subscriptions').where('userId', '==', 'unverified-user3').get();
    expect(subs.size).toBe(0);
  });

  it('grants the trial once the email is verified (positive control)', async () => {
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
