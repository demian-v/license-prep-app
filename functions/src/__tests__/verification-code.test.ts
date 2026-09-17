/**
 * Risk #12 — email verification by 6-digit code, the pure logic.
 *
 * These are the security properties of the flow, tested directly rather than
 * inferred from an integration test: the code is never stored readable, a stale
 * or burned record cannot be probed, and neither a tight loop nor a slow drip
 * can turn this into a way to mail-bomb an address.
 */
import {
  generateCode,
  generateSalt,
  hashCode,
  issueRecord,
  verifyCode,
  canSend,
  isExpired,
  attemptsRemaining,
  CODE_TTL_MS,
  MAX_ATTEMPTS,
  RESEND_COOLDOWN_MS,
  MAX_SENDS_PER_WINDOW,
  SEND_WINDOW_MS,
  CODE_LENGTH,
  VerificationRecord,
} from '../email/verification-code';

const UID = 'user-abc';
const EMAIL = 'someone@example.com';
const T0 = 1_700_000_000_000;

const issue = (code: string, now = T0, previous: VerificationRecord | null = null) =>
  issueRecord({ code, uid: UID, email: EMAIL, now, previous });

describe('Risk #12 — code generation', () => {
  it('is always exactly six digits', () => {
    for (let i = 0; i < 200; i++) {
      expect(generateCode()).toMatch(/^\d{6}$/);
    }
  });

  it('keeps leading zeros rather than shortening the code', () => {
    // A code built with toString() alone would render 42 as "42".
    const padded = '000042';
    expect(padded).toHaveLength(CODE_LENGTH);
    expect(verifyCode({
      record: issue(padded), submitted: padded, uid: UID, currentEmail: EMAIL, now: T0,
    })).toEqual({ ok: true });
  });

  it('does not obviously repeat', () => {
    const seen = new Set(Array.from({ length: 300 }, () => generateCode()));
    // 300 draws from 10^6 should essentially never collide more than a little.
    expect(seen.size).toBeGreaterThan(290);
  });
});

describe('Risk #12 — the code is never stored readable', () => {
  it('the record does not contain the code', () => {
    const record = issue('123456');
    expect(JSON.stringify(record)).not.toContain('123456');
  });

  it('two issuances of the SAME code produce different hashes', () => {
    // Without a per-record salt, six digits is a trivially small rainbow table.
    const a = issue('123456');
    const b = issue('123456');
    expect(a.codeHash).not.toBe(b.codeHash);
  });

  it('the same code hashes differently for a different user', () => {
    const salt = generateSalt();
    expect(hashCode('123456', salt, 'user-a')).not.toBe(hashCode('123456', salt, 'user-b'));
  });
});

describe('Risk #12 — verification', () => {
  it('accepts the correct code', () => {
    expect(verifyCode({
      record: issue('123456'), submitted: '123456', uid: UID, currentEmail: EMAIL, now: T0,
    })).toEqual({ ok: true });
  });

  it('rejects a wrong code', () => {
    expect(verifyCode({
      record: issue('123456'), submitted: '654321', uid: UID, currentEmail: EMAIL, now: T0,
    })).toEqual({ ok: false, reason: 'mismatch' });
  });

  it('rejects when there is no outstanding code', () => {
    expect(verifyCode({
      record: null, submitted: '123456', uid: UID, currentEmail: EMAIL, now: T0,
    })).toEqual({ ok: false, reason: 'no_code' });
  });

  it('rejects once the code has expired', () => {
    expect(verifyCode({
      record: issue('123456'), submitted: '123456', uid: UID, currentEmail: EMAIL,
      now: T0 + CODE_TTL_MS,
    })).toEqual({ ok: false, reason: 'expired' });
  });

  it('accepts one millisecond before expiry (boundary)', () => {
    expect(verifyCode({
      record: issue('123456'), submitted: '123456', uid: UID, currentEmail: EMAIL,
      now: T0 + CODE_TTL_MS - 1,
    })).toEqual({ ok: true });
  });

  it('rejects after the attempt cap, even with the RIGHT code', () => {
    // The cap must burn the code, not merely slow guessing down.
    const record = { ...issue('123456'), attempts: MAX_ATTEMPTS };
    expect(verifyCode({
      record, submitted: '123456', uid: UID, currentEmail: EMAIL, now: T0,
    })).toEqual({ ok: false, reason: 'too_many_attempts' });
  });

  it('checks expiry before the code itself', () => {
    // Otherwise a stale record stays probeable for as long as nobody replaces it.
    const record = { ...issue('123456'), attempts: MAX_ATTEMPTS };
    expect(verifyCode({
      record, submitted: '000000', uid: UID, currentEmail: EMAIL, now: T0 + CODE_TTL_MS,
    })).toEqual({ ok: false, reason: 'expired' });
  });

  it('refuses when the address changed after the code was issued', () => {
    // Verifying here would mark an address the code never went to as confirmed.
    expect(verifyCode({
      record: issue('123456'), submitted: '123456', uid: UID,
      currentEmail: 'someone-else@example.com', now: T0,
    })).toEqual({ ok: false, reason: 'email_changed' });
  });

  it('reports attempts remaining', () => {
    expect(attemptsRemaining(issue('123456'))).toBe(MAX_ATTEMPTS);
    expect(attemptsRemaining({ ...issue('123456'), attempts: 3 })).toBe(MAX_ATTEMPTS - 3);
    expect(attemptsRemaining({ ...issue('123456'), attempts: 99 })).toBe(0);
  });
});

describe('Risk #12 — send throttling', () => {
  it('allows the first send', () => {
    expect(canSend(null, T0)).toEqual({ allowed: true });
  });

  it('refuses a second send inside the cooldown', () => {
    const r = canSend(issue('123456'), T0 + 1_000);
    expect(r.allowed).toBe(false);
    if (!r.allowed) {
      expect(r.reason).toBe('cooldown');
      expect(r.retryAfterMs).toBe(RESEND_COOLDOWN_MS - 1_000);
    }
  });

  it('allows a resend once the cooldown has passed', () => {
    expect(canSend(issue('123456'), T0 + RESEND_COOLDOWN_MS)).toEqual({ allowed: true });
  });

  it('refuses once the hourly cap is reached', () => {
    // A slow drip, one per cooldown, would still deliver a lot of mail to an
    // address the requester may not own.
    const record = { ...issue('123456'), sendCount: MAX_SENDS_PER_WINDOW };
    const r = canSend(record, T0 + RESEND_COOLDOWN_MS);
    expect(r.allowed).toBe(false);
    if (!r.allowed) expect(r.reason).toBe('window');
  });

  it('allows again once the window rolls over', () => {
    const record = { ...issue('123456'), sendCount: MAX_SENDS_PER_WINDOW };
    expect(canSend(record, T0 + SEND_WINDOW_MS)).toEqual({ allowed: true });
  });

  it('carries the send count forward within a window', () => {
    const first = issue('111111', T0);
    const second = issue('222222', T0 + RESEND_COOLDOWN_MS, first);
    expect(second.sendCount).toBe(2);
    expect(second.windowStartedAt).toBe(first.windowStartedAt);
  });

  it('restarts the count when the window has elapsed', () => {
    const first = { ...issue('111111', T0), sendCount: MAX_SENDS_PER_WINDOW };
    const second = issue('222222', T0 + SEND_WINDOW_MS, first);
    expect(second.sendCount).toBe(1);
    expect(second.windowStartedAt).toBe(T0 + SEND_WINDOW_MS);
  });

  it('a reissue clears previous failed attempts', () => {
    const burned = { ...issue('111111', T0), attempts: MAX_ATTEMPTS };
    const fresh = issue('222222', T0 + RESEND_COOLDOWN_MS, burned);
    expect(fresh.attempts).toBe(0);
    expect(verifyCode({
      record: fresh, submitted: '222222', uid: UID, currentEmail: EMAIL,
      now: T0 + RESEND_COOLDOWN_MS,
    })).toEqual({ ok: true });
  });
});

describe('Risk #12 — expiry helper', () => {
  it('is not expired before the TTL', () => {
    expect(isExpired(issue('123456'), T0 + CODE_TTL_MS - 1)).toBe(false);
  });
  it('is expired at the TTL', () => {
    expect(isExpired(issue('123456'), T0 + CODE_TTL_MS)).toBe(true);
  });
});
