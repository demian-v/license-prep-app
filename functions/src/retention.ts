/**
 * Risk #40 — retention for the two collections that grow forever.
 *
 * `processedWebhooks` is one document per store notification, kept only so a
 * redelivery is recognised as a duplicate. Once no store will retry a given
 * notification, the record has no further purpose.
 *
 * `subscriptionLogs` is different in kind: it is the money-state audit trail.
 * Risk #4 was a job that deleted rows out of it by accident, so nothing here
 * deletes from it unless an operator sets a retention period explicitly. There
 * is no default, because how long payment records must be kept is a business
 * and compliance question, not an engineering one.
 */

/**
 * How long a webhook dedup record is kept.
 *
 * Sized well past both stores' retry windows, so a late redelivery is still
 * recognised as a duplicate rather than reprocessed:
 *   - Apple retries App Store Server Notifications V2 over ~3 days.
 *   - Google Play RTDN rides on Pub/Sub, which retains undelivered messages
 *     for up to 7 days.
 * 30 days leaves a wide margin over the longer of the two.
 */
export const WEBHOOK_DEDUP_RETENTION_DAYS = 30;

/**
 * Retention for `subscriptionLogs`, in days. Zero means "keep everything",
 * which is the default and the only safe default — see the note above.
 */
export const SUBSCRIPTION_LOG_RETENTION_DISABLED = 0;

/** Documents older than this instant are eligible for deletion. */
export function retentionCutoff(days: number, now: number = Date.now()): Date {
  return new Date(now - days * 24 * 60 * 60 * 1000);
}

/**
 * Whether a configured retention value should cause any deletion at all.
 *
 * Anything that is not a positive, finite number reads as disabled. A typo in
 * a config value must never be interpreted as "delete everything": a negative
 * or NaN cutoff would put the boundary in the future and match every document
 * in the collection.
 */
export function isRetentionEnabled(days: unknown): days is number {
  return typeof days === 'number' && Number.isFinite(days) && days > 0;
}
