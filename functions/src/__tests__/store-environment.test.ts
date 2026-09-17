/**
 * Risk #27 — sandbox vs production is detected but never persisted.
 *
 * Both validators already work the environment out: Apple via status 21007
 * (sandbox receipt presented to the production endpoint), Google via
 * `testPurchase` on the subscription resource. Both used to log it and drop
 * it, so a TestFlight or internal-test subscription was stored exactly like a
 * real one and counted as revenue.
 *
 * The write path is what these tests pin. `null` is a deliberate third state:
 * an unknown environment must not be recorded as 'production', because that is
 * the defect — counting something we are not sure about as a real sale.
 */
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import { createOrUpdateSubscription } from '../receipt-validation';

const db = () => admin.firestore();

async function wipeUser(userId: string) {
  const snap = await db().collection('subscriptions').where('userId', '==', userId).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

const expiry = () => new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

async function subscriptionFor(userId: string) {
  const snap = await db().collection('subscriptions').where('userId', '==', userId).get();
  expect(snap.docs).toHaveLength(1);
  return snap.docs[0].data();
}

describe('Risk #27 — a new subscription records its store environment', () => {
  it('stores sandbox for a sandbox purchase', async () => {
    await wipeUser('env-sandbox');
    await createOrUpdateSubscription(
      'env-sandbox', 'monthly', expiry(), 'ios', 'TXN-ENV-SB', 'ORIG-ENV-SB', 'sandbox'
    );
    expect((await subscriptionFor('env-sandbox')).environment).toBe('sandbox');
  });

  it('stores production for a real purchase', async () => {
    await wipeUser('env-prod');
    await createOrUpdateSubscription(
      'env-prod', 'monthly', expiry(), 'ios', 'TXN-ENV-PR', 'ORIG-ENV-PR', 'production'
    );
    expect((await subscriptionFor('env-prod')).environment).toBe('production');
  });

  it('stores null — not production — when the environment is unknown', async () => {
    await wipeUser('env-unknown');
    await createOrUpdateSubscription(
      'env-unknown', 'monthly', expiry(), 'ios', 'TXN-ENV-UN', 'ORIG-ENV-UN'
    );
    const sub = await subscriptionFor('env-unknown');
    expect(sub.environment).toBeNull();
    expect(sub.environment).not.toBe('production');
  });
});

describe('Risk #27 — renewals keep the environment honest', () => {
  it('a renewal that knows the environment records it', async () => {
    await wipeUser('env-renew');
    await createOrUpdateSubscription(
      'env-renew', 'monthly', expiry(), 'ios', 'TXN-ENV-R1', 'ORIG-ENV-R', 'sandbox'
    );
    await createOrUpdateSubscription(
      'env-renew', 'monthly', expiry(), 'ios', 'TXN-ENV-R2', 'ORIG-ENV-R', 'sandbox'
    );
    expect((await subscriptionFor('env-renew')).environment).toBe('sandbox');
  });

  it('a renewal that does not know leaves the stored environment alone', async () => {
    await wipeUser('env-keep');
    await createOrUpdateSubscription(
      'env-keep', 'monthly', expiry(), 'ios', 'TXN-ENV-K1', 'ORIG-ENV-K', 'sandbox'
    );
    await createOrUpdateSubscription(
      'env-keep', 'monthly', expiry(), 'ios', 'TXN-ENV-K2', 'ORIG-ENV-K'
    );
    // Still sandbox — an unknown renewal must not quietly promote a test
    // subscription into a real one.
    expect((await subscriptionFor('env-keep')).environment).toBe('sandbox');
  });
});
