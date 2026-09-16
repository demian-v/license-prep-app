/**
 * Risk #18 — admin-grade functions were callable by ANY authenticated user.
 *
 * Each carried the identical comment "Optional: Add admin authentication check",
 * and one of them, `processSubscriptionsManualy`, mutates subscription state.
 * `subscriptionSystemHealth` returns other users' `subscriptionLogs` rows.
 *
 * Gate mirrors firestore.rules isAdmin(): a document must exist at
 * admins/{uid}. That collection is empty in production, so after this change
 * these endpoints are callable by nobody until an admin is provisioned —
 * the correct resting state for admin tooling.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';

const ADMIN_UID = 'admin-user';
const PLAIN_UID = 'plain-user';

const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } } });

const ADMIN_FUNCTIONS = [
  'processSubscriptionsManualy',
  'getSubscriptionStats',
  'subscriptionSystemHealth',
  'getRenewalStats',
] as const;

beforeAll(async () => {
  await admin.firestore().collection('admins').doc(ADMIN_UID).set({
    grantedAt: admin.firestore.FieldValue.serverTimestamp(),
    note: 'test fixture',
  });
  await admin.firestore().collection('admins').doc(PLAIN_UID).delete().catch(() => {});
});

afterAll(() => testEnv.cleanup());

describe('Risk #18 — admin functions reject non-admins', () => {
  it.each(ADMIN_FUNCTIONS)('%s rejects an unauthenticated caller', async (name) => {
    const wrapped = testEnv.wrap((fns as any)[name]);
    await expect(wrapped({} as any, {} as any)).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it.each(ADMIN_FUNCTIONS)('%s rejects a signed-in non-admin', async (name) => {
    const wrapped = testEnv.wrap((fns as any)[name]);
    await expect(wrapped({} as any, ctx(PLAIN_UID) as any))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  // Positive controls — without these, "deny everyone" would pass the above.
  it.each(ADMIN_FUNCTIONS)('%s serves a provisioned admin', async (name) => {
    const wrapped = testEnv.wrap((fns as any)[name]);
    await expect(wrapped({} as any, ctx(ADMIN_UID) as any)).resolves.toBeDefined();
  });
});
