import * as crypto from 'crypto';

/**
 * Risk #12 / #35 — email verification by 6-digit code.
 *
 * This module is deliberately pure: no Firestore, no network, no Firebase. The
 * security properties of the flow live here, so they can be tested directly
 * rather than inferred from an integration test.
 *
 * The chosen shape, and why:
 *
 *  - **A code, not a link.** A link would have to travel through
 *    `/__/auth/action`, which `firebase.json` rewrites to `password-reset.html`
 *    for every mode — a page with no `verifyEmail` handling at all. It would
 *    also need the Associated Domains entitlement that only became real in #30.
 *    A code typed into the app avoids both, and is testable today.
 *
 *  - **Stored hashed.** The code is a shared secret. A readable copy in
 *    Firestore would mean anyone who could read that collection could verify
 *    any address; hashing means the stored form is useless on its own.
 *
 *  - **Salted per record.** Six digits is a 10^6 space, small enough to build a
 *    rainbow table for in seconds. A per-record salt makes each stored hash
 *    unique to that issuance, so one table cannot cover them all. The uid is
 *    mixed in for the same reason.
 */

/** How long a code stays usable. Long enough to switch to a mail app and back. */
export const CODE_TTL_MS = 10 * 60 * 1000;

/** Wrong guesses allowed before the code is burned. */
export const MAX_ATTEMPTS = 5;

/** Minimum gap between sends, so this cannot be used to mail-bomb an address. */
export const RESEND_COOLDOWN_MS = 60 * 1000;

/** Codes issuable in the window below, per user. Bounds total mail volume. */
export const MAX_SENDS_PER_WINDOW = 5;
export const SEND_WINDOW_MS = 60 * 60 * 1000;

export const CODE_LENGTH = 6;

/** What is persisted for an outstanding code. The code itself never appears. */
export interface VerificationRecord {
  codeHash: string;
  salt: string;
  email: string;
  expiresAt: number;
  attempts: number;
  sendCount: number;
  lastSentAt: number;
  windowStartedAt: number;
}

export type VerifyFailure =
  | 'no_code'
  | 'expired'
  | 'too_many_attempts'
  | 'mismatch'
  | 'email_changed';

export type VerifyResult =
  | { ok: true }
  | { ok: false; reason: VerifyFailure };

/**
 * A uniformly distributed 6-digit code.
 *
 * `randomInt` is used rather than `randomBytes` with a modulo, because taking a
 * modulo of a byte stream biases the low end of the range — the classic mistake
 * in exactly this kind of code. `randomInt` rejects out-of-range draws instead.
 */
export function generateCode(): string {
  return crypto.randomInt(0, 10 ** CODE_LENGTH).toString().padStart(CODE_LENGTH, '0');
}

export function generateSalt(): string {
  return crypto.randomBytes(16).toString('hex');
}

export function hashCode(code: string, salt: string, uid: string): string {
  return crypto.createHash('sha256').update(`${salt}:${uid}:${code}`).digest('hex');
}

/**
 * Constant-time comparison. A plain `===` on hex strings leaks, through timing,
 * how many leading characters matched — which over enough attempts narrows the
 * search. The attempt cap makes this largely theoretical here; it costs one
 * function call to not have to reason about it.
 */
function hashesEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

export function isExpired(record: VerificationRecord, now: number): boolean {
  return now >= record.expiresAt;
}

/**
 * Whether another code may be sent, and if not, when it may be.
 *
 * Two limits, because they stop different things: the cooldown stops a tight
 * loop of requests, the window cap stops a slow drip that would still deliver
 * hundreds of emails to an address the requester may not own.
 */
export function canSend(
  record: VerificationRecord | null,
  now: number
): { allowed: true } | { allowed: false; reason: 'cooldown' | 'window'; retryAfterMs: number } {
  if (!record) return { allowed: true };

  const sinceLast = now - record.lastSentAt;
  if (sinceLast < RESEND_COOLDOWN_MS) {
    return { allowed: false, reason: 'cooldown', retryAfterMs: RESEND_COOLDOWN_MS - sinceLast };
  }

  const windowElapsed = now - record.windowStartedAt;
  if (windowElapsed < SEND_WINDOW_MS && record.sendCount >= MAX_SENDS_PER_WINDOW) {
    return { allowed: false, reason: 'window', retryAfterMs: SEND_WINDOW_MS - windowElapsed };
  }

  return { allowed: true };
}

/** Build the record for a freshly issued code, carrying forward send counters. */
export function issueRecord(params: {
  code: string;
  uid: string;
  email: string;
  now: number;
  previous: VerificationRecord | null;
}): VerificationRecord {
  const { code, uid, email, now, previous } = params;
  const salt = generateSalt();

  // The send window rolls: once it has elapsed, counting starts again.
  const windowExpired = !previous || now - previous.windowStartedAt >= SEND_WINDOW_MS;

  return {
    codeHash: hashCode(code, salt, uid),
    salt,
    email,
    expiresAt: now + CODE_TTL_MS,
    attempts: 0,
    sendCount: windowExpired ? 1 : previous!.sendCount + 1,
    lastSentAt: now,
    windowStartedAt: windowExpired ? now : previous!.windowStartedAt,
  };
}

/**
 * Check a submitted code against the stored record.
 *
 * Order matters. Expiry and the attempt cap are checked BEFORE the comparison,
 * so a burned or stale record cannot be probed indefinitely.
 *
 * `email_changed` covers the case where the address was edited after the code
 * was issued: verifying then would mark a different address as confirmed.
 */
export function verifyCode(params: {
  record: VerificationRecord | null;
  submitted: string;
  uid: string;
  currentEmail: string;
  now: number;
}): VerifyResult {
  const { record, submitted, uid, currentEmail, now } = params;

  if (!record) return { ok: false, reason: 'no_code' };
  if (record.email !== currentEmail) return { ok: false, reason: 'email_changed' };
  if (isExpired(record, now)) return { ok: false, reason: 'expired' };
  if (record.attempts >= MAX_ATTEMPTS) return { ok: false, reason: 'too_many_attempts' };

  const submittedHash = hashCode(submitted, record.salt, uid);
  if (!hashesEqual(submittedHash, record.codeHash)) {
    return { ok: false, reason: 'mismatch' };
  }

  return { ok: true };
}

/** Attempts remaining after a failed guess — surfaced so the UI can warn. */
export function attemptsRemaining(record: VerificationRecord): number {
  return Math.max(0, MAX_ATTEMPTS - record.attempts);
}
