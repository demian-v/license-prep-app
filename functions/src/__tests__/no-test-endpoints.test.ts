/**
 * Risk #4 — test and mock endpoints must not exist in deployable code.
 *
 * `handleMockPaymentWebhook` accepted unauthenticated POSTs and could mint
 * subscription state; the four test-data callables were any-auth and one of
 * them (`cleanupSubscriptionTestData`) deletes audit rows. `docs/webhook.md`
 * asked for the mock webhook to be removed before production, twice.
 *
 * Asserting absence rather than access control is deliberate: an endpoint that
 * does not exist cannot be misconfigured back into reachability later.
 */
import * as fns from '../index';

const FORBIDDEN = [
  'handleMockPaymentWebhook',
  'generateSubscriptionTestData',
  'cleanupSubscriptionTestData',
  'createQuickSubscriptionTest',
  'verifySubscriptionTestData',
];

describe('Risk #4 — no test or mock endpoints are exported', () => {
  it.each(FORBIDDEN)('does not export %s', (name) => {
    expect((fns as any)[name]).toBeUndefined();
  });

  it('still exports the real payment entry points (positive control)', () => {
    expect((fns as any).validatePurchaseReceipt).toBeDefined();
    expect((fns as any).appStoreWebhook).toBeDefined();
    expect((fns as any).handleGooglePlayNotifications).toBeDefined();
  });
});
