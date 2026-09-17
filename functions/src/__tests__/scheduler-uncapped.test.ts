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

const docId = (j: number) => `cap-trial-${String(j).padStart(4, '0')}`;
const ownRefs = () =>
  Array.from({ length: COUNT }, (_, j) => db().collection('subscriptions').doc(docId(j)));

beforeAll(async () => {
  // Clear only THIS suite's fixtures. It used to delete every trial
  // subscription in the collection, which raced other suites running in
  // parallel workers against the same emulator — it could wipe their fixture
  // mid-test, and their fixture could inflate the count asserted below.
  await Promise.all(ownRefs().map((ref) => ref.delete()));

  const past = admin.firestore.Timestamp.fromMillis(Date.now() - 5 * 864e5);
  for (let i = 0; i < COUNT; i += 400) {
    const batch = db().batch();
    for (let j = i; j < Math.min(i + 400, COUNT); j++) {
      batch.set(db().collection('subscriptions').doc(docId(j)), {
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

  // At least COUNT, not exactly: other suites run in parallel against the same
  // emulator and may have their own expired trials in flight. The point of this
  // test is that the sweep goes past the old limit(100), and >= 150 proves it.
  expect(result.expiredTrials).toBeGreaterThanOrEqual(COUNT);
  expect(result.errors).toHaveLength(0);

  // Exactness belongs here instead, scoped to this suite's own documents:
  // every one of them is genuinely deactivated, not merely counted.
  const own = await db().getAll(...ownRefs());
  expect(own).toHaveLength(COUNT);
  const stillActive = own.filter((d) => d.data()?.isActive === true);
  expect(stillActive.map((d) => d.id)).toEqual([]);
}, 120000);
