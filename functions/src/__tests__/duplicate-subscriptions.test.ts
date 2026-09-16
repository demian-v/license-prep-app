/**
 * Risk #22 — duplicate subscriptions documents, and webhooks updating the corpse.
 *
 * findExistingSubscription requires isActive == true, so a purchase made after
 * deactivation created a SECOND document for the same store subscription. The
 * webhooks then keyed on originalTransactionId / purchaseToken and, with
 * .limit(1), updated whichever one Firestore returned first — often the dead
 * one — leaving the live document untouched and permanently out of sync.
 *
 * The isActive filter exists for a reason (BUG RV-C1): it stops a dead TRIAL
 * being resurrected into a paid plan. The fix must keep that.
 */
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import { findExistingSubscription, createOrUpdateSubscription } from '../receipt-validation';
import { applyToAllMatches } from '../webhook-fanout';

const db = () => admin.firestore();
const IOS_TXN = 'TXN-RESUB-777';

async function wipeUser(userId: string) {
  const snap = await db().collection('subscriptions').where('userId', '==', userId).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

describe('Risk #22 — re-subscribing must not create a second document', () => {
  it('reuses an INACTIVE document that shares the receipt identity', async () => {
    await wipeUser('resub-user');
    await db().collection('subscriptions').doc('dead-but-same-receipt').set({
      userId: 'resub-user', isActive: false, status: 'inactive',
      planType: 'monthly', packageId: '1', originalTransactionId: IOS_TXN,
    });

    const found = await findExistingSubscription('resub-user', {
      platform: 'ios', originalTransactionId: IOS_TXN,
    });
    expect(found).not.toBeNull();
    expect(found!.id).toBe('dead-but-same-receipt');
  });

  it('createOrUpdateSubscription does not add a second document on re-subscribe', async () => {
    await wipeUser('resub-user2');
    await db().collection('subscriptions').doc('lapsed-monthly').set({
      userId: 'resub-user2', isActive: false, status: 'inactive',
      planType: 'monthly', packageId: '1', originalTransactionId: 'TXN-RESUB-888',
      transactions: [],
    });

    await createOrUpdateSubscription(
      'resub-user2', 'monthly', new Date(Date.now() + 30 * 864e5),
      'ios', 'txn-new-charge', 'TXN-RESUB-888',
    );

    const snap = await db().collection('subscriptions').where('userId', '==', 'resub-user2').get();
    expect(snap.size).toBe(1);
    expect(snap.docs[0].id).toBe('lapsed-monthly');
    expect(snap.docs[0].get('isActive')).toBe(true);
  });

  // RV-C1 regression guard. A dead trial has no receipt identity, so it must
  // NOT be reused — resurrecting it turns a trial into a paid plan with stale
  // fields instead of creating a clean subscription.
  it('does NOT reuse a dead trial (RV-C1 regression guard)', async () => {
    await wipeUser('trial-user');
    await db().collection('subscriptions').doc('dead-trial').set({
      userId: 'trial-user', isActive: false, status: 'inactive',
      planType: 'trial', packageId: '3',
    });

    const found = await findExistingSubscription('trial-user', {
      platform: 'ios', originalTransactionId: 'TXN-BRAND-NEW',
    });
    expect(found).toBeNull();
  });

  it('still finds a live subscription with no receipt hint (positive control)', async () => {
    await wipeUser('live-user');
    await db().collection('subscriptions').doc('live-sub').set({
      userId: 'live-user', isActive: true, status: 'active',
      planType: 'monthly', packageId: '1',
    });
    const found = await findExistingSubscription('live-user');
    expect(found).not.toBeNull();
    expect(found!.id).toBe('live-sub');
  });
});

describe('Risk #22 — webhooks must reach every document sharing a receipt', () => {
  it('applies updates to all matches and to each document\'s own user', async () => {
    await db().collection('subscriptions').doc('shared-a').set({
      userId: 'share-user-a', isActive: true, originalTransactionId: 'TXN-SHARED',
    });
    await db().collection('subscriptions').doc('shared-b').set({
      userId: 'share-user-b', isActive: true, originalTransactionId: 'TXN-SHARED',
    });

    const snap = await db().collection('subscriptions')
      .where('originalTransactionId', '==', 'TXN-SHARED').get();
    expect(snap.size).toBe(2);

    const batch = db().batch();
    applyToAllMatches(db(), batch, snap.docs,
      { isActive: false, status: 'inactive' },
      { isActive: false });
    await batch.commit();

    for (const id of ['shared-a', 'shared-b']) {
      const d = await db().collection('subscriptions').doc(id).get();
      expect(d.get('isActive')).toBe(false);
    }
    for (const uid of ['share-user-a', 'share-user-b']) {
      const u = await db().collection('users').doc(uid).get();
      expect(u.get('isActive')).toBe(false);
    }
  });
});
