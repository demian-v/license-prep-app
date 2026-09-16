/**
 * Risk #25 — the real scheduler path, not just the helper.
 *
 * Seeds more expired trials than the old limit(100) allowed and asserts the
 * sweep reaches every one of them. Before the fix this returned exactly 100 and
 * said nothing about the remainder.
 */
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import { processExpiredSubscriptions } from '../subscription-manager';

const db = () => admin.firestore();
const COUNT = 150;

beforeAll(async () => {
  // Clear anything a previous run left behind, so the count is exact.
  const existing = await db().collection('subscriptions').where('planType', '==', 'trial').get();
  await Promise.all(existing.docs.map((d) => d.ref.delete()));

  const past = admin.firestore.Timestamp.fromMillis(Date.now() - 5 * 864e5);
  for (let i = 0; i < COUNT; i += 400) {
    const batch = db().batch();
    for (let j = i; j < Math.min(i + 400, COUNT); j++) {
      batch.set(db().collection('subscriptions').doc(`cap-trial-${String(j).padStart(4, '0')}`), {
        userId: `cap-user-${j}`,
        planType: 'trial',
        isActive: true,
        status: 'active',
        trialUsed: 0,
        trialEndsAt: past,
        nextBillingDate: past,
      });
    }
    await batch.commit();
  }
}, 60000);

it(`sweeps all ${COUNT} expired trials, not just the first 100`, async () => {
  const result = await processExpiredSubscriptions();

  expect(result.expiredTrials).toBe(COUNT);
  expect(result.errors).toHaveLength(0);

  // And they are genuinely deactivated, not merely counted.
  const stillActive = await db().collection('subscriptions')
    .where('planType', '==', 'trial')
    .where('isActive', '==', true)
    .get();
  expect(stillActive.size).toBe(0);
}, 120000);
