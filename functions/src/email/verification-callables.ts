import * as functions from 'firebase-functions/v1';
import { defineSecret } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';

import {
  VerificationRecord,
  generateCode,
  issueRecord,
  verifyCode,
  canSend,
  attemptsRemaining,
  MAX_ATTEMPTS,
  CODE_TTL_MS,
} from './verification-code';
import { createEmailSender, EmailSender } from './sender';
import { getVerificationCodeTemplate, replaceTemplateVariables } from '../email-templates';

/**
 * Risk #12 — the server half of email verification by 6-digit code.
 *
 * Product intent, and the one thing not to change without asking: **the trial
 * is NOT gated on verification.** A registered user gets the 3-day trial
 * immediately and is blocked only when it expires (owner decision, 2026-09-16,
 * reversing an earlier gate). Verification is a step inside signup, not a door
 * in front of entitlement. There are tests asserting an unverified user still
 * gets a trial; a future hardening pass must not quietly undo that.
 *
 * Codes live in `emailVerificationCodes/{uid}`, which is client-deny by rule —
 * nothing outside these functions may read or write it.
 */

const COLLECTION = 'emailVerificationCodes';

const db = () => admin.firestore();

function codeRef(uid: string) {
  return db().collection(COLLECTION).doc(uid);
}

async function readRecord(uid: string): Promise<VerificationRecord | null> {
  const snap = await codeRef(uid).get();
  return snap.exists ? (snap.data() as VerificationRecord) : null;
}

/** The signed-in user's uid, or a clean unauthenticated error. */
function requireUid(context: any): string {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Not logged in');
  }
  return context.auth.uid;
}

/**
 * Issue a code and email it.
 *
 * Exported separately from the callable so tests can drive it with a stub
 * sender — otherwise every test would need either a live Resend key or a
 * network stub, and the useful assertions are about what gets stored.
 */
export async function sendVerificationCodeFor(params: {
  uid: string;
  email: string;
  language: string;
  sender: EmailSender;
  now?: number;
}): Promise<{ sent: boolean; retryAfterMs?: number }> {
  const { uid, email, language, sender } = params;
  const now = params.now ?? Date.now();

  const previous = await readRecord(uid);
  const gate = canSend(previous, now);
  if (!gate.allowed) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      gate.reason === 'cooldown'
        ? 'A code was just sent. Please wait before requesting another.'
        : 'Too many codes requested. Please try again later.',
      { retryAfterMs: gate.retryAfterMs }
    );
  }

  const code = generateCode();
  const record = issueRecord({ code, uid, email, now, previous });

  const template = replaceTemplateVariables(getVerificationCodeTemplate(language), { code });
  const result = await sender.send({
    to: email,
    subject: template.subject,
    html: template.html,
    text: template.text,
  });

  // Risk #35's lesson: do not record a send that did not happen, and do not
  // burn the user's quota on our own failure. The record is written only after
  // the transport confirms delivery.
  if (!result.delivered) {
    throw new functions.https.HttpsError(
      'unavailable',
      'Could not send the verification email. Please try again.'
    );
  }

  await codeRef(uid).set({ ...record, updatedAt: FieldValue.serverTimestamp() });
  return { sent: true };
}

/**
 * Check a submitted code and, on success, set Firebase's real `emailVerified`.
 *
 * A failed guess increments `attempts` even though the code stays valid, so the
 * cap actually bites. A success deletes the record — a used code must not be
 * reusable.
 */
export async function verifyCodeFor(params: {
  uid: string;
  submitted: string;
  currentEmail: string;
  now?: number;
}): Promise<{ verified: true } | { verified: false; reason: string; attemptsLeft: number }> {
  const { uid, submitted, currentEmail } = params;
  const now = params.now ?? Date.now();

  const record = await readRecord(uid);
  const result = verifyCode({ record, submitted, uid, currentEmail, now });

  if (!result.ok) {
    if (result.reason === 'mismatch' && record) {
      await codeRef(uid).update({ attempts: FieldValue.increment(1) });
      return {
        verified: false,
        reason: 'mismatch',
        attemptsLeft: attemptsRemaining({ ...record, attempts: record.attempts + 1 }),
      };
    }
    return { verified: false, reason: result.reason, attemptsLeft: 0 };
  }

  // Firebase's own flag is the source of truth, so anything reading
  // `emailVerified` — now or later — sees a consistent answer.
  await admin.auth().updateUser(uid, { emailVerified: true });
  await db().collection('users').doc(uid).set(
    { emailVerified: true, emailVerifiedAt: FieldValue.serverTimestamp() },
    { merge: true }
  );
  await codeRef(uid).delete();

  return { verified: true };
}

/** Whether the caller still needs to verify — drives resume-on-relaunch. */
export async function verificationStatusFor(uid: string): Promise<{
  emailVerified: boolean;
  hasPendingCode: boolean;
  expiresInMs: number;
}> {
  const user = await admin.auth().getUser(uid);
  const record = await readRecord(uid);
  const now = Date.now();
  return {
    emailVerified: user.emailVerified,
    hasPendingCode: !!record && record.expiresAt > now,
    expiresInMs: record ? Math.max(0, record.expiresAt - now) : 0,
  };
}

export const CODE_POLICY = { MAX_ATTEMPTS, CODE_TTL_MS };

// ============================================================================
// CALLABLES
// ============================================================================

const resendApiKey = defineSecret('RESEND_API_KEY');

/**
 * Send (or resend) a verification code to the caller's own address.
 *
 * The address is read from the Auth record, never from the request — a
 * client-supplied address would let any signed-in user mail anyone.
 */
export const sendEmailVerificationCode = functions
  .runWith({ secrets: [resendApiKey] })
  .https.onCall(async (data: any, context: any) => {
    const uid = requireUid(context);
    const user = await admin.auth().getUser(uid);

    if (!user.email) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'This account has no email address.'
      );
    }
    if (user.emailVerified) {
      return { sent: false, alreadyVerified: true };
    }

    const language = typeof data?.language === 'string' ? data.language : 'en';
    const sender = createEmailSender(resendApiKey.value());

    await sendVerificationCodeFor({ uid, email: user.email, language, sender });
    return { sent: true, alreadyVerified: false };
  });

/** Check a submitted code. */
export const verifyEmailCode = functions.https.onCall(async (data: any, context: any) => {
  const uid = requireUid(context);

  const submitted = typeof data?.code === 'string' ? data.code.trim() : '';
  if (!/^\d{6}$/.test(submitted)) {
    throw new functions.https.HttpsError('invalid-argument', 'Enter the 6-digit code.');
  }

  const user = await admin.auth().getUser(uid);
  if (user.emailVerified) {
    return { verified: true, alreadyVerified: true };
  }
  if (!user.email) {
    throw new functions.https.HttpsError('failed-precondition', 'This account has no email address.');
  }

  return await verifyCodeFor({ uid, submitted, currentEmail: user.email });
});

/** Resume-on-relaunch: does the caller still owe us a verification? */
export const getEmailVerificationStatus = functions.https.onCall(
  async (_data: any, context: any) => {
    return await verificationStatusFor(requireUid(context));
  }
);
