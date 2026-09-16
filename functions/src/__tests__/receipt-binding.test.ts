/**
 * Risk #5 — no receipt→account binding.
 *
 * validatePurchaseReceipt attached whatever receipt it was handed to
 * context.auth.uid. Nothing checked whether that originalTransactionId (iOS) or
 * purchase token (Android) was already bound to a DIFFERENT userId, so one
 * paid receipt could entitle unlimited accounts.
 *
 * Compounding it: both webhook lookups use .limit(1), so a later revocation
 * reaches exactly one of the N documents and the rest stay isActive forever.
 */
import * as admin from 'firebase-admin';

// receipt-validation does not call initializeApp (index.ts does, and this suite
// deliberately imports only the module under test).
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import { assertReceiptNotBoundToAnotherUser } from '../receipt-validation';

const db = () => admin.firestore();
const OWNER = 'receipt-owner';
const ATTACKER = 'receipt-thief';
const IOS_TXN = 'TXN-ORIGINAL-1000000123456789';
const PLAY_TOKEN = 'play-token-abcdef123456';

beforeAll(async () => {
  await db().collection('subscriptions').doc('sub-ios-owner').set({
    userId: OWNER, isActive: true, planType: 'monthly',
    originalTransactionId: IOS_TXN, androidPurchaseToken: null,
  });
  await db().collection('subscriptions').doc('sub-play-owner').set({
    userId: OWNER, isActive: true, planType: 'monthly',
    originalTransactionId: null, androidPurchaseToken: PLAY_TOKEN,
  });
});

describe('Risk #5 — a receipt cannot be redeemed by a second account', () => {
  it('rejects an iOS receipt already bound to another user', async () => {
    await expect(assertReceiptNotBoundToAnotherUser({
      userId: ATTACKER, platform: 'ios', originalTransactionId: IOS_TXN,
    })).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects an Android purchase token already bound to another user', async () => {
    await expect(assertReceiptNotBoundToAnotherUser({
      userId: ATTACKER, platform: 'android', androidPurchaseToken: PLAY_TOKEN,
    })).rejects.toMatchObject({ code: 'permission-denied' });
  });

  // Positive controls. Without these, a guard that always threw would pass.
  it('allows the original owner to re-submit their own iOS receipt (renewal)', async () => {
    await expect(assertReceiptNotBoundToAnotherUser({
      userId: OWNER, platform: 'ios', originalTransactionId: IOS_TXN,
    })).resolves.toBeUndefined();
  });

  it('allows the original owner to re-submit their own Android token (renewal)', async () => {
    await expect(assertReceiptNotBoundToAnotherUser({
      userId: OWNER, platform: 'android', androidPurchaseToken: PLAY_TOKEN,
    })).resolves.toBeUndefined();
  });

  it('allows a brand-new receipt nobody has used', async () => {
    await expect(assertReceiptNotBoundToAnotherUser({
      userId: ATTACKER, platform: 'ios', originalTransactionId: 'TXN-NEVER-SEEN',
    })).resolves.toBeUndefined();
  });

  it('is a no-op when the platform identifier is absent', async () => {
    await expect(assertReceiptNotBoundToAnotherUser({
      userId: ATTACKER, platform: 'ios',
    })).resolves.toBeUndefined();
  });
});

/**
 * Wiring: the guard must actually run inside the write path, not merely exist.
 */
describe('Risk #5 — the write path refuses a foreign receipt', () => {
  it('createOrUpdateSubscription rejects, and writes nothing, for a foreign iOS receipt', async () => {
    const { createOrUpdateSubscription } = await import('../receipt-validation');

    await expect(createOrUpdateSubscription(
      ATTACKER, 'monthly', new Date(Date.now() + 30 * 864e5), 'ios', 'txn-attempt-1', IOS_TXN,
    )).rejects.toMatchObject({ code: 'permission-denied' });

    const attackerSubs = await db().collection('subscriptions')
      .where('userId', '==', ATTACKER).get();
    expect(attackerSubs.size).toBe(0);
  });

  it('createOrUpdateSubscription rejects a foreign Android token', async () => {
    const { createOrUpdateSubscription } = await import('../receipt-validation');

    await expect(createOrUpdateSubscription(
      ATTACKER, 'monthly', new Date(Date.now() + 30 * 864e5), 'android', PLAY_TOKEN,
    )).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
