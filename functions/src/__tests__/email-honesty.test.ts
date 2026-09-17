/**
 * Risk #35 — the audit trail claimed emails that were never sent.
 *
 * `nodemailer` is commented out in subscription-manager.ts and the
 * 1,382-line, five-language email-templates.ts is imported by nothing, so no
 * code path can send mail. The three notification helpers nonetheless ended in
 * `return true` ("Mock successful send"), and every caller wrote that value
 * straight into `subscriptionLogs.emailSent`.
 *
 * So the money-state audit trail recorded a trial-expiry notice, an
 * expiry notice and a past-due warning for customers who received none of
 * them. An earlier "BUG SM-2 fix" made the callers pass the *actual* return
 * value instead of a hardcoded true — but the actual value was itself a
 * hardcoded true, so nothing changed.
 *
 * These tests pin the honest behaviour: while no transport exists, the sweeps
 * report zero emails and log emailSent: false. When mail is finally wired up
 * they will fail, which is the correct moment to revisit them.
 */
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import { processExpiredSubscriptions } from '../subscription-manager';

const db = () => admin.firestore();

const daysFromNow = (n: number) =>
  admin.firestore.Timestamp.fromDate(new Date(Date.now() + n * 24 * 60 * 60 * 1000));

async function wipe(userId: string) {
  for (const collection of ['subscriptions', 'subscriptionLogs']) {
    const snap = await db().collection(collection).where('userId', '==', userId).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
  await db().collection('users').doc(userId).delete();
}

describe('Risk #35 — no email is claimed while none can be sent', () => {
  const USER = 'email-honesty-user';

  beforeEach(async () => {
    await wipe(USER);
    await db().collection('users').doc(USER).set({
      name: 'Test', email: 'nobody@example.com', language: 'en', isActive: true,
    });
    await db().collection('subscriptions').add({
      userId: USER,
      planType: 'trial',
      isActive: true,
      status: 'active',
      trialUsed: 0,
      trialEndsAt: daysFromNow(-1),   // expired yesterday
      nextBillingDate: daysFromNow(-1),
    });
  });

  afterAll(async () => { await wipe(USER); });

  it('the expiry sweep reports zero emails sent', async () => {
    const result = await processExpiredSubscriptions();
    expect(result.emailsSent).toBe(0);
  });

  it('the audit row records emailSent: false, not true', async () => {
    await processExpiredSubscriptions();

    const logs = await db().collection('subscriptionLogs')
      .where('userId', '==', USER).get();

    expect(logs.docs.length).toBeGreaterThan(0);
    for (const doc of logs.docs) {
      expect(doc.data().emailSent).toBe(false);
    }
  });

  it('the sweep still does its real work (positive control)', async () => {
    const result = await processExpiredSubscriptions();
    // The trial is processed and deactivated — only the email claim changed.
    expect(result.totalProcessed).toBeGreaterThan(0);
    const subs = await db().collection('subscriptions').where('userId', '==', USER).get();
    expect(subs.docs[0].data().isActive).toBe(false);
  });
});
