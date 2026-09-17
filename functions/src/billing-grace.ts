import { Timestamp } from 'firebase-admin/firestore';

/**
 * How long a lapsed subscription keeps access before we revoke it locally
 * (risk #7).
 *
 * This is NOT our billing policy — Apple and Google own the billing. It is a
 * backstop for the case where their signal never reaches us.
 *
 * It must exceed the stores' own retry windows, or we lock out customers the
 * stores are still successfully charging:
 *   - Apple: billing retry with a grace period of up to 16 days
 *   - Google Play: account hold / billing retry of up to 30 days
 *
 * The previous mechanism was MAX_RENEWAL_ATTEMPTS = 3 on a 6-hour scheduler,
 * about 18 hours. A customer whose card cleared on day 3 was already
 * deactivated here.
 *
 * Counting scheduler passes was also the wrong unit: the renewal queries are
 * capped at 100 documents per run (risk #25), so "3 attempts" meant three
 * pickups, not eighteen hours, for anyone behind a backlog. Grace is measured
 * in elapsed time from nextBillingDate instead, which no scheduler delay or
 * backlog can distort.
 *
 * The authority remains the store webhook — EXPIRED / GRACE_PERIOD_EXPIRED on
 * Apple, types 12/13 on Play. Those revoke immediately regardless of this
 * window. This only decides how long we wait when no signal ever arrives.
 */
export const STORE_GRACE_PERIOD_DAYS = 30;

const GRACE_MS = STORE_GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000;

/**
 * True while a subscription whose billing date has passed should still be
 * honoured, because the store may yet be retrying the charge.
 *
 * A missing nextBillingDate is treated as NOT in grace: we cannot reason about
 * a window we have no start point for, and the surrounding code already
 * requires the field.
 */
export function isWithinStoreGrace(
  nextBillingDate: Timestamp | null | undefined,
  now: number = Date.now(),
): boolean {
  if (!nextBillingDate) return false;
  return now - nextBillingDate.toMillis() <= GRACE_MS;
}
