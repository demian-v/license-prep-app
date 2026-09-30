/**
 * Instructors plan v2 §3 — the marketplace (listing, chat, booking) needs a
 * PAID subscription. Trial users see only the locked preview (owner decision
 * 2026-09-30), so requirePaidSubscriber must refuse a live trial while
 * requireEntitledUser keeps accepting it for the test-prep content.
 */
import * as admin from 'firebase-admin';
import { requireEntitledUser, requirePaidSubscriber } from '../entitlement';

if (admin.apps.length === 0) admin.initializeApp({ projectId: 'demo-driveusa' });
const db = () => admin.firestore();

const ctx = (uid: string, provider = 'password') =>
  ({ auth: { uid, token: { firebase: { sign_in_provider: provider } } } });
const inDays = (d: number) => admin.firestore.Timestamp.fromMillis(Date.now() + d * 864e5);

async function subscription(id: string, userId: string, planType: string, nextBillingDate: any) {
  await db().collection('subscriptions').doc(id).set({ userId, isActive: true, planType, nextBillingDate });
}

beforeAll(async () => {
  await subscription('psg-trial', 'psg-trial-user', 'trial', inDays(3));
  await subscription('psg-monthly', 'psg-paid-user', 'monthly', inDays(20));
  await subscription('psg-both-trial', 'psg-both-user', 'trial', inDays(1));
  await subscription('psg-both-paid', 'psg-both-user', 'monthly', inDays(25));
  // Lapsed past the 30-day store grace window: not entitled at all.
  await subscription('psg-lapsed', 'psg-lapsed-user', 'monthly', inDays(-40));
});

afterAll(async () => { await Promise.all(admin.apps.map((app) => app?.delete())); });

describe('requirePaidSubscriber', () => {
  it('rejects a caller with no auth', async () => {
    await expect(requirePaidSubscriber({})).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('rejects an anonymous session', async () => {
    await expect(requirePaidSubscriber(ctx('psg-paid-user', 'anonymous')))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects a user whose only live subscription is a trial', async () => {
    await expect(requirePaidSubscriber(ctx('psg-trial-user')))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects a paid subscription that lapsed beyond the store grace window', async () => {
    await expect(requirePaidSubscriber(ctx('psg-lapsed-user')))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects a user with no subscription', async () => {
    await expect(requirePaidSubscriber(ctx('psg-nobody')))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('accepts a live paid subscription (positive control)', async () => {
    await expect(requirePaidSubscriber(ctx('psg-paid-user'))).resolves.toBe('psg-paid-user');
  });

  it('accepts a user holding both a trial and a paid subscription', async () => {
    await expect(requirePaidSubscriber(ctx('psg-both-user'))).resolves.toBe('psg-both-user');
  });
});

describe('requireEntitledUser is unchanged by the refactor', () => {
  it('still accepts a live trial (content stays open to trial users)', async () => {
    await expect(requireEntitledUser(ctx('psg-trial-user'))).resolves.toBe('psg-trial-user');
  });

  it('still rejects a lapsed subscription', async () => {
    await expect(requireEntitledUser(ctx('psg-lapsed-user')))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });
});
