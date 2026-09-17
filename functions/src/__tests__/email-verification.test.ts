/**
 * Risk #12 — email verification, the Firestore/Auth half.
 *
 * The pure policy is covered in verification-code.test.ts. These pin the parts
 * that touch state: what is stored, what a failed guess costs, what a success
 * changes, and — most importantly — what verification must NOT affect.
 *
 * The trial is deliberately NOT gated on verification (owner decision,
 * 2026-09-16, reversing an earlier gate). The last group here exists so a
 * future hardening pass cannot quietly reintroduce that gate.
 */
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import {
  sendVerificationCodeFor,
  verifyCodeFor,
  verificationStatusFor,
} from '../email/verification-callables';
import { EmailSender, EmailMessage, SendResult } from '../email/sender';
import { MAX_ATTEMPTS, CODE_TTL_MS } from '../email/verification-code';

const db = () => admin.firestore();
const EMAIL = 'verify-test@example.com';

/** Captures what was sent and hands back the code the message carried. */
class CapturingSender implements EmailSender {
  sent: EmailMessage[] = [];
  async send(message: EmailMessage): Promise<SendResult> {
    this.sent.push(message);
    return { delivered: true, transport: 'log' };
  }
  get lastCode(): string {
    const match = this.sent[this.sent.length - 1].text.match(/\d{6}/);
    return match ? match[0] : '';
  }
}

/** A transport that fails, for the "do not record a send that did not happen" case. */
class FailingSender implements EmailSender {
  async send(): Promise<SendResult> {
    return { delivered: false, transport: 'resend', error: 'simulated rejection' };
  }
}

async function makeUser(email: string): Promise<string> {
  try {
    const existing = await admin.auth().getUserByEmail(email);
    await admin.auth().deleteUser(existing.uid);
  } catch { /* not there yet */ }
  const user = await admin.auth().createUser({ email, password: 'test-password-123' });
  return user.uid;
}

async function cleanup(uid: string) {
  await db().collection('emailVerificationCodes').doc(uid).delete();
  await db().collection('users').doc(uid).delete();
  try { await admin.auth().deleteUser(uid); } catch { /* already gone */ }
}

describe('Risk #12 — issuing a code', () => {
  let uid: string;
  let sender: CapturingSender;

  beforeEach(async () => {
    uid = await makeUser(EMAIL);
    sender = new CapturingSender();
  });
  afterEach(async () => { await cleanup(uid); });

  it('emails a six-digit code', async () => {
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender });
    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].to).toBe(EMAIL);
    expect(sender.lastCode).toMatch(/^\d{6}$/);
  });

  it('stores the code hashed — the plaintext never reaches Firestore', async () => {
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender });
    const stored = (await db().collection('emailVerificationCodes').doc(uid).get()).data()!;
    expect(JSON.stringify(stored)).not.toContain(sender.lastCode);
    expect(stored.codeHash).toEqual(expect.any(String));
    expect(stored.salt).toEqual(expect.any(String));
  });

  it('localises the subject', async () => {
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'ru', sender });
    expect(sender.sent[0].subject).toContain('DriveUSA');
    expect(sender.sent[0].subject).toMatch(/[А-Яа-я]/);
  });

  it('falls back to English for an unknown language', async () => {
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'kl', sender });
    expect(sender.sent[0].subject).toMatch(/verification code/i);
  });

  it('refuses a second send inside the cooldown', async () => {
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender });
    await expect(
      sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender })
    ).rejects.toThrow(/wait/i);
  });

  it('does NOT store a record when the transport failed', async () => {
    // Risk #35's lesson: never record a send that did not happen — and do not
    // burn the user's quota on our own failure.
    await expect(
      sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender: new FailingSender() })
    ).rejects.toThrow(/could not send/i);

    const stored = await db().collection('emailVerificationCodes').doc(uid).get();
    expect(stored.exists).toBe(false);
  });
});

describe('Risk #12 — checking a code', () => {
  let uid: string;
  let sender: CapturingSender;

  beforeEach(async () => {
    uid = await makeUser(EMAIL);
    sender = new CapturingSender();
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender });
  });
  afterEach(async () => { await cleanup(uid); });

  it('accepts the right code and sets Firebase emailVerified', async () => {
    const result = await verifyCodeFor({ uid, submitted: sender.lastCode, currentEmail: EMAIL });
    expect(result).toEqual({ verified: true });
    expect((await admin.auth().getUser(uid)).emailVerified).toBe(true);
  });

  it('mirrors the flag onto the user document', async () => {
    await verifyCodeFor({ uid, submitted: sender.lastCode, currentEmail: EMAIL });
    const doc = (await db().collection('users').doc(uid).get()).data()!;
    expect(doc.emailVerified).toBe(true);
  });

  it('deletes the record, so a used code cannot be replayed', async () => {
    await verifyCodeFor({ uid, submitted: sender.lastCode, currentEmail: EMAIL });
    expect((await db().collection('emailVerificationCodes').doc(uid).get()).exists).toBe(false);

    const replay = await verifyCodeFor({ uid, submitted: sender.lastCode, currentEmail: EMAIL });
    expect(replay).toMatchObject({ verified: false, reason: 'no_code' });
  });

  it('a wrong code does not verify, and costs an attempt', async () => {
    const wrong = sender.lastCode === '000000' ? '111111' : '000000';
    const result = await verifyCodeFor({ uid, submitted: wrong, currentEmail: EMAIL });
    expect(result).toMatchObject({ verified: false, reason: 'mismatch' });
    expect((await admin.auth().getUser(uid)).emailVerified).toBe(false);

    const stored = (await db().collection('emailVerificationCodes').doc(uid).get()).data()!;
    expect(stored.attempts).toBe(1);
  });

  it('burns the code after the attempt cap, even if the right code arrives later', async () => {
    const right = sender.lastCode;
    const wrong = right === '000000' ? '111111' : '000000';

    for (let i = 0; i < MAX_ATTEMPTS; i++) {
      await verifyCodeFor({ uid, submitted: wrong, currentEmail: EMAIL });
    }

    const result = await verifyCodeFor({ uid, submitted: right, currentEmail: EMAIL });
    expect(result).toMatchObject({ verified: false, reason: 'too_many_attempts' });
    expect((await admin.auth().getUser(uid)).emailVerified).toBe(false);
  });

  it('refuses an expired code', async () => {
    const result = await verifyCodeFor({
      uid, submitted: sender.lastCode, currentEmail: EMAIL,
      now: Date.now() + CODE_TTL_MS + 1,
    });
    expect(result).toMatchObject({ verified: false, reason: 'expired' });
  });

  it('refuses when the address changed after issuing', async () => {
    const result = await verifyCodeFor({
      uid, submitted: sender.lastCode, currentEmail: 'different@example.com',
    });
    expect(result).toMatchObject({ verified: false, reason: 'email_changed' });
  });
});

describe('Risk #12 — resume on relaunch', () => {
  let uid: string;
  beforeEach(async () => { uid = await makeUser(EMAIL); });
  afterEach(async () => { await cleanup(uid); });

  it('reports nothing pending before a code is sent', async () => {
    const status = await verificationStatusFor(uid);
    expect(status).toMatchObject({ emailVerified: false, hasPendingCode: false });
  });

  it('reports a pending code so the app can return to the code screen', async () => {
    const sender = new CapturingSender();
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender });

    const status = await verificationStatusFor(uid);
    expect(status.hasPendingCode).toBe(true);
    expect(status.expiresInMs).toBeGreaterThan(0);
    expect(status.expiresInMs).toBeLessThanOrEqual(CODE_TTL_MS);
  });

  it('reports verified once done', async () => {
    const sender = new CapturingSender();
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender });
    await verifyCodeFor({ uid, submitted: sender.lastCode, currentEmail: EMAIL });

    const status = await verificationStatusFor(uid);
    expect(status).toMatchObject({ emailVerified: true, hasPendingCode: false });
  });
});

describe('Risk #12 — verification must NOT gate the trial', () => {
  // Owner decision 2026-09-16: a registered user gets the 3-day trial
  // immediately and is blocked only when it expires. Verification is a step in
  // signup, not a door in front of entitlement. These assertions exist so a
  // later hardening pass cannot quietly reverse that.
  let uid: string;
  beforeEach(async () => { uid = await makeUser(EMAIL); });
  afterEach(async () => { await cleanup(uid); });

  it('issuing a code does not touch entitlement', async () => {
    await db().collection('users').doc(uid).set({ isActive: true, email: EMAIL });

    const sender = new CapturingSender();
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender });

    const doc = (await db().collection('users').doc(uid).get()).data()!;
    expect(doc.isActive).toBe(true);
  });

  it('an UNVERIFIED user keeps their entitlement', async () => {
    await db().collection('users').doc(uid).set({ isActive: true, email: EMAIL });
    const sender = new CapturingSender();
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender });

    // Deliberately never verified.
    expect((await admin.auth().getUser(uid)).emailVerified).toBe(false);
    const doc = (await db().collection('users').doc(uid).get()).data()!;
    expect(doc.isActive).toBe(true);
  });

  it('verifying does not grant entitlement either', async () => {
    await db().collection('users').doc(uid).set({ isActive: false, email: EMAIL });
    const sender = new CapturingSender();
    await sendVerificationCodeFor({ uid, email: EMAIL, language: 'en', sender });
    await verifyCodeFor({ uid, submitted: sender.lastCode, currentEmail: EMAIL });

    const doc = (await db().collection('users').doc(uid).get()).data()!;
    expect(doc.isActive).toBe(false);
  });
});
