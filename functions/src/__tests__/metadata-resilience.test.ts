/**
 * Risk #20 — subscriptionsType is a single point of failure for every purchase.
 *
 * getSubscriptionMetadata threw when no document had planType == productId,
 * before any write, and the throw became a bare 'internal' error. One deleted,
 * renamed or mistyped catalogue document took down purchase activation on every
 * platform, silently. PAYMENT_SYSTEM_IMPLEMENTATION.md even documents planType
 * as 'monthly_subscription' — seeding it that way would break every purchase.
 *
 * Also covers the flattening that hides it: validatePurchaseReceipt's outer
 * catch converted HttpsError into 'internal', so invalid-argument,
 * resource-exhausted and the risk #5 permission-denied all reached the client
 * as the same useless code.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { getSubscriptionMetadata } from '../receipt-validation';

const db = () => admin.firestore();
const CTX = { auth: { uid: 'meta-user', token: { firebase: { sign_in_provider: 'password' } } } };

afterAll(() => testEnv.cleanup());

describe('Risk #20 — a missing catalogue row must not kill purchases', () => {
  beforeEach(async () => {
    const snap = await db().collection('subscriptionsType').get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  });

  it('uses the Firestore catalogue row when present (positive control)', async () => {
    await db().collection('subscriptionsType').doc('1').set({
      id: 1, planType: 'monthly', price: 12.34, duration: 31, isSubscription: true,
    });
    const meta = await getSubscriptionMetadata('monthly');
    expect(meta.price).toBe(12.34);
    expect(meta.duration).toBe(31);
  });

  it('falls back to built-in defaults when the monthly row is missing', async () => {
    const meta = await getSubscriptionMetadata('monthly');
    expect(meta.duration).toBe(30);
    expect(meta.price).toBe(9.99);
  });

  it('falls back for trial too', async () => {
    const meta = await getSubscriptionMetadata('trial');
    expect(meta.duration).toBe(3);
    expect(meta.price).toBe(0);
  });

  it('still refuses a genuinely unknown product id', async () => {
    await expect(getSubscriptionMetadata('monthly_subscription'))
      .rejects.toThrow(/monthly_subscription/);
  });
});

describe('Risk #20 — real error codes must survive to the client', () => {
  it('validatePurchaseReceipt reports invalid-argument, not internal', async () => {
    const wrapped = testEnv.wrap(fns.validatePurchaseReceipt as any);
    await expect(wrapped({ platform: 'ios' } as any, CTX as any))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('validatePurchaseReceipt reports unauthenticated, not internal', async () => {
    const wrapped = testEnv.wrap(fns.validatePurchaseReceipt as any);
    await expect(wrapped({ platform: 'ios', receipt: 'x', productId: 'monthly' } as any, {} as any))
      .rejects.toMatchObject({ code: 'unauthenticated' });
  });
});
