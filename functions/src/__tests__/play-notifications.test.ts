/**
 * Risk #8 — Google Play pause states were not modelled at all.
 *
 * Types 10 (SUBSCRIPTION_PAUSED) and 11 (SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED)
 * fell into `default:`, which logs and returns. A paused subscriber therefore
 * kept full access indefinitely, because nothing ever revoked it: Play stops
 * charging, sends PAUSED, and we ignored it.
 *
 * The in-code comment also mislabelled type 8 as PAUSE_SCHEDULE_CHANGED. It is
 * SUBSCRIPTION_PRICE_CHANGE_CONFIRMED; 11 is PAUSE_SCHEDULE_CHANGED.
 */
import { mapPlayNotification, PLAY_NOTIFICATION } from '../play-notifications';

const NOW = 'SERVER_TS' as any;

describe('Risk #8 — Play pause states are modelled', () => {
  it('PAUSED (10) revokes access', () => {
    const r = mapPlayNotification(PLAY_NOTIFICATION.PAUSED, { now: NOW, newBillingDate: null });
    expect(r.handled).toBe(true);
    expect(r.subUpdates.isActive).toBe(false);
    expect(r.subUpdates.status).toBe('paused');
    expect(r.userUpdates).toMatchObject({ isActive: false });
  });

  it('PAUSE_SCHEDULE_CHANGED (11) is acknowledged without touching entitlement', () => {
    const r = mapPlayNotification(PLAY_NOTIFICATION.PAUSE_SCHEDULE_CHANGED, { now: NOW, newBillingDate: null });
    expect(r.handled).toBe(true);
    // A pause that has only been scheduled has not taken effect yet — the
    // subscriber is still entitled until Play sends PAUSED.
    expect(r.subUpdates.isActive).toBeUndefined();
    expect(r.userUpdates).toBeNull();
  });

  it('RESTARTED (7) restores access after a pause', () => {
    const r = mapPlayNotification(PLAY_NOTIFICATION.RESTARTED, { now: NOW, newBillingDate: null });
    expect(r.handled).toBe(true);
    expect(r.subUpdates.isActive).toBe(true);
    expect(r.subUpdates.status).toBe('active');
  });

  it('type 8 is PRICE_CHANGE_CONFIRMED, not a pause state', () => {
    expect(PLAY_NOTIFICATION.PRICE_CHANGE_CONFIRMED).toBe(8);
    expect(PLAY_NOTIFICATION.PAUSE_SCHEDULE_CHANGED).toBe(11);
    expect(PLAY_NOTIFICATION.PAUSED).toBe(10);
  });

  // Positive controls — the existing behaviour must be unchanged.
  it('RENEWED (2) still activates', () => {
    const r = mapPlayNotification(PLAY_NOTIFICATION.RENEWED, { now: NOW, newBillingDate: null });
    expect(r.subUpdates.isActive).toBe(true);
    expect(r.logAction).toBe('google_renewed');
  });

  it('EXPIRED (13) still deactivates', () => {
    const r = mapPlayNotification(PLAY_NOTIFICATION.EXPIRED, { now: NOW, newBillingDate: null });
    expect(r.subUpdates.isActive).toBe(false);
    expect(r.userUpdates).toMatchObject({ isActive: false });
  });

  it('CANCELED (3) leaves access alone until the billing date', () => {
    const r = mapPlayNotification(PLAY_NOTIFICATION.CANCELED, { now: NOW, newBillingDate: null });
    expect(r.subUpdates.isActive).toBeUndefined();
    expect(r.subUpdates.status).toBe('canceled');
  });

  it('an unknown type is reported unhandled rather than silently ignored', () => {
    const r = mapPlayNotification(99, { now: NOW, newBillingDate: null });
    expect(r.handled).toBe(false);
  });
});
