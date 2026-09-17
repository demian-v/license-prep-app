/**
 * Risk #19 — rate limiting counted failures, so a paying user could be locked out.
 *
 * checkRateLimit counted receipt_validated PLUS receipt_validation_failed PLUS
 * receipt_validation_error against one cap of 10/hour. Ten transient failures
 * (network, Apple 21005, a missing subscriptionsType row) and the eleventh
 * attempt — the one that would have worked — is refused with
 * resource-exhausted. The user has already been charged.
 *
 * iOS sandbox makes this trivially reachable: 5-minute renewals produce 12+
 * distinct receipts.
 */
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import { checkRateLimit, RATE_LIMIT_SCAN_LIMIT } from '../receipt-validation';

const db = () => admin.firestore();

async function seed(userId: string, action: string, count: number, ageMs = 60_000) {
  const batch = db().batch();
  for (let i = 0; i < count; i++) {
    batch.set(db().collection('subscriptionLogs').doc(`${userId}-${action}-${i}`), {
      userId,
      action,
      timestamp: admin.firestore.Timestamp.fromMillis(Date.now() - ageMs),
    });
  }
  await batch.commit();
}

describe('Risk #19 — failures must not consume a paying user\'s validation budget', () => {
  it('blocks after too many SUCCESSFUL validations (abuse guard intact)', async () => {
    await seed('rl-many-success', 'receipt_validated', 10);
    await expect(checkRateLimit('rl-many-success')).resolves.toBe(true);
  });

  it('does NOT block a user whose attempts were mostly failures', async () => {
    // The regression this risk is about: 20 transient failures used to exhaust
    // the same 10-attempt budget and refuse the next real purchase.
    await seed('rl-failures', 'receipt_validation_failed', 20);
    await seed('rl-failures', 'receipt_validated', 2);
    await expect(checkRateLimit('rl-failures')).resolves.toBe(false);
  });

  it('still blocks genuine failure floods (abuse guard on the failure path)', async () => {
    await seed('rl-flood', 'receipt_validation_error', 40);
    await expect(checkRateLimit('rl-flood')).resolves.toBe(true);
  });

  it('ignores attempts older than the window', async () => {
    await seed('rl-old', 'receipt_validated', 20, 3 * 60 * 60 * 1000);
    await expect(checkRateLimit('rl-old')).resolves.toBe(false);
  });

  it('allows a brand-new user (positive control)', async () => {
    await expect(checkRateLimit('rl-fresh')).resolves.toBe(false);
  });
});

describe('Risk #19 — the limiter fails open, never blocking a paid purchase', () => {
  afterEach(() => jest.restoreAllMocks());

  it('allows the purchase when Firestore cannot answer', async () => {
    // e.g. FAILED_PRECONDITION from the missing composite index of risk #15.
    // The call site sits outside validatePurchaseReceipt's try block, so this
    // would otherwise surface as a bare 'internal' error after the charge.
    jest.spyOn(admin, 'firestore').mockImplementationOnce((() => {
      throw new Error('9 FAILED_PRECONDITION: The query requires an index.');
    }) as any);

    await expect(checkRateLimit('rl-infra-failure')).resolves.toBe(false);
  });
});

describe('Risk #40 — the rate-limit query is bounded', () => {
  it('blocks a user far past the cap without reading all their rows', async () => {
    // Before this bound the query had no limit, so a client hammering
    // validation made every later check read every one of its own attempts —
    // on the purchase path, where slow means a failed sale. The row count here
    // is well past the cap; the limiter must still answer, and answer "blocked".
    await seed('rl-cap', 'receipt_validation_failed', RATE_LIMIT_SCAN_LIMIT + 25);

    await expect(checkRateLimit('rl-cap')).resolves.toBe(true);
  });

  it('the cap can only be reached when a budget is already blown', () => {
    // Acting on "cap reached" without counting is only sound because the cap
    // sits above the largest total that could still be under both budgets.
    const maxUnderBothBudgets = (10 - 1) + (30 - 1);
    expect(RATE_LIMIT_SCAN_LIMIT).toBeGreaterThan(maxUnderBothBudgets);
  });

  it('still lets a normal purchase through (positive control)', async () => {
    // The bound must not turn into a blanket block.
    await seed('rl-normal', 'receipt_validated', 1);
    await expect(checkRateLimit('rl-normal')).resolves.toBe(false);
  });
});
