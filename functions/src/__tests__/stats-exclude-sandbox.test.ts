import { countsTowardRealStats } from '../subscription-manager';

/**
 * Operator statistics counted sandbox subscriptions as real ones.
 *
 * Risk #27 persisted `environment` on every subscription precisely so a test
 * purchase could never be mistaken for a real one. `getSubscriptionStatistics`
 * never consulted it, so the four counts an operator reads — trials expiring
 * today/tomorrow, cancellations ending today/tomorrow — included sandbox rows.
 * With **zero real subscriptions** in production (register reading 2026-08-29:
 * 10 paid rows, all inactive sandbox), sandbox was most of what there was.
 *
 * **Corrected scope.** The remaining-work list described this as sandbox
 * purchases sitting in "the revenue figures". That was wrong and overstated
 * it: this function returns operational counts and reports no revenue at all.
 * The real cost is an operator reading inflated numbers.
 *
 * The filter is applied in **code**, not in the query. Adding
 * `.where('environment', ...)` would change the query shape and need new
 * composite indexes (#15) — and a shape change on a money-path query is how
 * #19 nearly broke every purchase.
 */
describe('sandbox subscriptions do not count as real ones', () => {
  it('excludes a known sandbox row', () => {
    expect(countsTowardRealStats('sandbox')).toBe(false);
  });

  it('counts a known production row', () => {
    expect(countsTowardRealStats('production')).toBe(true);
  });
});

describe('unknown is not sandbox', () => {
  /**
   * Every document written before #27 has no `environment` field. Treating
   * those as sandbox would silently delete most of the history from the
   * numbers — the mirror of the mistake #27 refused to make in the other
   * direction, where an unknown environment must never be promoted to
   * `production`.
   */
  it.each([
    ['undefined (pre-#27 documents)', undefined],
    ['null (what #27 writes when it cannot tell)', null],
    ['an empty string', ''],
    ['an unexpected value', 'staging'],
  ])('counts a row whose environment is %s', (_label, value) => {
    expect(countsTowardRealStats(value)).toBe(true);
  });

  it('is not fooled by a lookalike', () => {
    // Only the exact value is excluded; anything else is unknown, and unknown
    // counts. Being wrong in this direction overstates by a row rather than
    // hiding one.
    expect(countsTowardRealStats('Sandbox')).toBe(true);
    expect(countsTowardRealStats('sandbox ')).toBe(true);
  });
});
