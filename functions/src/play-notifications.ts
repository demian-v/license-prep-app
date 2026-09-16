/**
 * Google Play Real-time Developer Notification types, and the state change each
 * one implies (risk #8).
 *
 * These were bare integers behind a comment, and the comment was wrong: it
 * labelled 8 as PAUSE_SCHEDULE_CHANGED. 8 is PRICE_CHANGE_CONFIRMED; 11 is
 * PAUSE_SCHEDULE_CHANGED. Naming them in code means the next reader cannot
 * inherit that mistake.
 *
 * Pause was not modelled at all: 10 and 11 fell into `default:`, which logs and
 * returns. Play stops charging a paused subscriber and sends PAUSED — and we
 * ignored it, so they kept full access indefinitely.
 */
export const PLAY_NOTIFICATION = {
  RECOVERED: 1,
  RENEWED: 2,
  CANCELED: 3,
  PURCHASED: 4,
  ON_HOLD: 5,
  IN_GRACE_PERIOD: 6,
  RESTARTED: 7,
  PRICE_CHANGE_CONFIRMED: 8,
  DEFERRED: 9,
  PAUSED: 10,
  PAUSE_SCHEDULE_CHANGED: 11,
  REVOKED: 12,
  EXPIRED: 13,
  PENDING_PURCHASE_CANCELED: 20,
} as const;

export interface PlayMappingResult {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  subUpdates: Record<string, any>;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  userUpdates: Record<string, any> | null;
  logAction: string;
  /** False when the type carries no state change we act on. */
  handled: boolean;
}

/**
 * Map a Play notification type to the Firestore updates it implies.
 *
 * Pure, so the entitlement consequences of each notification can be tested
 * without a Pub/Sub message, a signed payload or a live Play account.
 */
export function mapPlayNotification(
  notificationType: number,
  opts: {
    // serverTimestamp() sentinel from the caller
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    now: any;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    newBillingDate: any | null;
  },
): PlayMappingResult {
  const { now, newBillingDate } = opts;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const base: Record<string, any> = { updatedAt: now };

  switch (notificationType) {
    case PLAY_NOTIFICATION.RECOVERED:
    case PLAY_NOTIFICATION.RENEWED:
    case PLAY_NOTIFICATION.PURCHASED:
    case PLAY_NOTIFICATION.RESTARTED:
      return {
        subUpdates: {
          ...base,
          isActive: true,
          status: 'active',
          renewalAttempts: 0,
          ...(newBillingDate && { nextBillingDate: newBillingDate }),
        },
        userUpdates: {
          isActive: true,
          ...(newBillingDate && { nextBillingDate: newBillingDate }),
          lastUpdated: now,
        },
        logAction: 'google_renewed',
        handled: true,
      };

    case PLAY_NOTIFICATION.CANCELED:
      // Cancellation is a request, not an ending: access continues until
      // nextBillingDate.
      return {
        subUpdates: { ...base, status: 'canceled' },
        userUpdates: null,
        logAction: 'google_cancel_requested',
        handled: true,
      };

    case PLAY_NOTIFICATION.ON_HOLD:
    case PLAY_NOTIFICATION.IN_GRACE_PERIOD:
      // Play is still trying to charge. Access is retained deliberately —
      // see billing-grace.ts and risk #7.
      return {
        subUpdates: { ...base, status: 'past_due' },
        userUpdates: null,
        logAction: `google_play_${notificationType}`,
        handled: true,
      };

    case PLAY_NOTIFICATION.PAUSED:
      // Risk #8. The pause has taken effect: Play has stopped charging and the
      // subscriber is no longer entitled. RESTARTED (7) is the resume signal
      // and reactivates above.
      return {
        subUpdates: { ...base, isActive: false, status: 'paused' },
        userUpdates: { isActive: false, lastUpdated: now },
        logAction: 'google_paused',
        handled: true,
      };

    case PLAY_NOTIFICATION.PAUSE_SCHEDULE_CHANGED:
      // Risk #8. A pause has been scheduled, moved or cancelled, but has NOT
      // taken effect. Entitlement is deliberately untouched — acting here would
      // cut off a subscriber who is still paying.
      return {
        subUpdates: { ...base, status: 'pause_scheduled' },
        userUpdates: null,
        logAction: 'google_pause_schedule_changed',
        handled: true,
      };

    case PLAY_NOTIFICATION.REVOKED:
    case PLAY_NOTIFICATION.EXPIRED:
      return {
        subUpdates: { ...base, isActive: false, status: 'inactive' },
        userUpdates: { isActive: false, lastUpdated: now },
        logAction: 'google_expired',
        handled: true,
      };

    default:
      return {
        subUpdates: base,
        userUpdates: null,
        logAction: `google_play_${notificationType}`,
        handled: false,
      };
  }
}
