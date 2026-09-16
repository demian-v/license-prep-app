/**
 * Risk #7 — the home-grown grace period was ~18 hours.
 *
 * MAX_RENEWAL_ATTEMPTS = 3 on a 6-hour scheduler, against Apple's 16-day grace
 * and Google's up-to-30-day billing retry. A subscriber whose card succeeds on
 * the third day was already deactivated locally: a paying customer locked out,
 * who then has to notice, restore and re-validate. The register calls this the
 * single most likely cause of "I paid but I'm blocked" tickets.
 *
 * Counting scheduler passes was also the wrong unit. The queries are capped at
 * 100 documents per run (risk #25), so "3 attempts" is not 18 hours for anyone
 * behind a backlog — it is however long it takes to be picked up three times.
 * Grace is now measured in elapsed time from nextBillingDate.
 */
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import { processOverdueSubscription } from '../subscription-renewal-manager';
import { requireEntitledUser } from '../entitlement';
import { STORE_GRACE_PERIOD_DAYS } from '../billing-grace';

const db = () => admin.firestore();
const daysAgo = (d: number) => admin.firestore.Timestamp.fromMillis(Date.now() - d * 864e5);

async function makeSub(id: string, userId: string, overdueDays: number) {
  await db().collection('subscriptions').doc(id).set({
    id, userId, isActive: true, status: 'active', trialUsed: 1,
    planType: 'monthly', packageId: 1,
    nextBillingDate: daysAgo(overdueDays),
  });
  return { id, userId, isActive: true, status: 'active', trialUsed: 1,
           planType: 'monthly', packageId: 1,
           nextBillingDate: daysAgo(overdueDays) } as any;
}

const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } } });

describe('Risk #7 — the store\'s retry window, not 18 hours', () => {
  it('does NOT deactivate a subscription two days overdue', async () => {
    const sub = await makeSub('grace-2d', 'grace-user-2d', 2);
    const { deactivated } = await processOverdueSubscription(sub);
    expect(deactivated).toBe(false);
    const doc = await db().collection('subscriptions').doc('grace-2d').get();
    expect(doc.get('isActive')).toBe(true);
    expect(doc.get('status')).toBe('past_due');
  });

  it('does NOT deactivate one day before the grace window closes', async () => {
    const sub = await makeSub('grace-edge', 'grace-user-edge', STORE_GRACE_PERIOD_DAYS - 1);
    const { deactivated } = await processOverdueSubscription(sub);
    expect(deactivated).toBe(false);
  });

  it('DOES deactivate once the store\'s retry window has certainly closed', async () => {
    const sub = await makeSub('grace-expired', 'grace-user-exp', STORE_GRACE_PERIOD_DAYS + 5);
    const { deactivated } = await processOverdueSubscription(sub);
    expect(deactivated).toBe(true);
    const doc = await db().collection('subscriptions').doc('grace-expired').get();
    expect(doc.get('isActive')).toBe(false);
    const user = await db().collection('users').doc('grace-user-exp').get();
    expect(user.get('isActive')).toBe(false);
  });
});

describe('Risk #7 — entitlement must survive the grace period', () => {
  // The #3 gate required nextBillingDate > now, which would have locked out a
  // paying customer the moment their renewal was late — the same defect, one
  // layer up.
  it('serves a subscriber whose renewal is late but within grace', async () => {
    await db().collection('subscriptions').doc('ent-grace').set({
      userId: 'ent-grace-user', isActive: true, planType: 'monthly',
      nextBillingDate: daysAgo(3),
    });
    await expect(requireEntitledUser(ctx('ent-grace-user'))).resolves.toBe('ent-grace-user');
  });

  it('refuses a subscriber long past the grace window', async () => {
    await db().collection('subscriptions').doc('ent-stale').set({
      userId: 'ent-stale-user', isActive: true, planType: 'monthly',
      nextBillingDate: daysAgo(STORE_GRACE_PERIOD_DAYS + 10),
    });
    await expect(requireEntitledUser(ctx('ent-stale-user')))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('serves a subscriber in good standing (positive control)', async () => {
    await db().collection('subscriptions').doc('ent-good').set({
      userId: 'ent-good-user', isActive: true, planType: 'monthly',
      nextBillingDate: admin.firestore.Timestamp.fromMillis(Date.now() + 20 * 864e5),
    });
    await expect(requireEntitledUser(ctx('ent-good-user'))).resolves.toBe('ent-good-user');
  });
});
