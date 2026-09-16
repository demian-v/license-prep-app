/**
 * Risk #2 — `upgradeSubscription` granted 365 days of `yearly` entitlement with
 * no payment, no store transaction and no audit row. Its own header comment
 * called this "free proration for existing subscribers".
 *
 * Owner decision 2026-09-16: only the 30-day monthly plan is sold, so there is
 * no legitimate upgrade path to preserve. The callable is deleted rather than
 * gated — production has never had a single `yearly` subscription (register,
 * verified 2026-08-20), so nothing is stranded by its removal.
 */
import * as fns from '../index';

describe('Risk #2 — no callable grants entitlement without payment', () => {
  it('does not export upgradeSubscription', () => {
    expect((fns as any).upgradeSubscription).toBeUndefined();
  });

  it('still exports the paid and cancellation paths (positive control)', () => {
    expect((fns as any).validatePurchaseReceipt).toBeDefined();
    expect((fns as any).cancelSubscription).toBeDefined();
    expect((fns as any).createTrialSubscription).toBeDefined();
  });
});
