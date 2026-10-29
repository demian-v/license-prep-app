import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { DIDIT_SECRETS, DiditDecision, didit, verifyDiditSignature, webhookSecret, workflowId } from './didit-client';
import { recordWebhookFailure } from './webhook-dead-letter';
import { sendPushToUser } from './push';

/**
 * The instructor's identity check (instructors plan v2 §6.1, §6.3; P10b).
 *
 * 1. Our biometric consent screen → recordBiometricConsent stores when, and
 *    which wording, in instructorPrivate (Illinois BIPA wants a written
 *    release; Didit's own screen is not relied on).
 * 2. createIdentitySession creates the Didit session on the server
 *    (`vendor_data = uid`), so a client can't attach anyone else's result.
 * 3. The app runs Didit's SDK with the token.
 * 4. diditWebhook / reconcileIdentitySessions set `idCheck`; onInstructorWrite
 *    recomputes the stage from it.
 *
 * We keep only name, date of birth, status and document expiry — no images,
 * no document number. Didit itself keeps the session for its retention
 * window (1 month, owner setup) and until account deletion.
 */

const db = () => admin.firestore();

/**
 * The consent wording the app shows, by version. DRAFT for the lawyer (P11):
 * a new wording gets a new version here and in the app, and old consents
 * stay readable by the version they were given under.
 */
export const BIOMETRIC_CONSENT_VERSIONS = ['draft-2026-10-28'];

export const MAX_SESSIONS_PER_30_DAYS = 3;
const DAY_MS = 864e5;
export const RECONCILE_AFTER_MS = 10 * 60 * 1000;

function instructorCaller(context: functions.https.CallableContext): string {
  if (!context?.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  if (context.auth.token?.firebase?.sign_in_provider === 'anonymous') {
    throw new functions.https.HttpsError('permission-denied', 'Anonymous sessions cannot do this.');
  }
  return context.auth.uid;
}

export const recordBiometricConsent = functions.https.onCall(async (data, context) => {
  const uid = instructorCaller(context);
  const version = data?.version;
  if (typeof version !== 'string' || !BIOMETRIC_CONSENT_VERSIONS.includes(version)) {
    throw new functions.https.HttpsError('invalid-argument', 'Unknown consent version.');
  }
  if (data?.agreed !== true) throw new functions.https.HttpsError('invalid-argument', 'Consent must be given.');
  if (!(await db().collection('instructors').doc(uid).get()).exists) {
    throw new functions.https.HttpsError('failed-precondition', 'Not an instructor account.');
  }
  const at = Timestamp.now();
  await db().collection('instructorPrivate').doc(uid).set(
    { biometricConsentAt: at, biometricConsentVersion: version }, { merge: true });
  return { consentedAtMs: at.toMillis() };
});

/** «Marek Nowak» → first «Marek», last «Nowak»; one word goes in both. */
export function splitName(name: string): { first_name: string; last_name: string } {
  const parts = name.trim().split(/\s+/);
  return parts.length < 2
    ? { first_name: parts[0], last_name: parts[0] }
    : { first_name: parts[0], last_name: parts.slice(1).join(' ') };
}

export const createIdentitySession = functions.runWith({ secrets: DIDIT_SECRETS }).https.onCall(async (_data, context) => {
  const uid = instructorCaller(context);
  const ref = db().collection('instructors').doc(uid);
  const privRef = db().collection('instructorPrivate').doc(uid);
  const [pub, priv] = await Promise.all([ref.get(), privRef.get()]);
  if (!pub.exists) throw new functions.https.HttpsError('failed-precondition', 'Not an instructor account.');
  if (pub.get('status') === 'suspended') throw new functions.https.HttpsError('failed-precondition', 'suspended');
  if (pub.get('idCheck') === 'passed') throw new functions.https.HttpsError('failed-precondition', 'already-passed');
  const consentAt = priv.get('biometricConsentAt') as Timestamp | null | undefined;
  const consentVersion = priv.get('biometricConsentVersion') as string | undefined;
  if (!consentAt || !consentVersion) throw new functions.https.HttpsError('failed-precondition', 'consent-required');

  const known: string[] = priv.get('identitySessionIds') ?? [];
  const now = Date.now();
  const recent = ((priv.get('identitySessionTimes') ?? []) as Timestamp[]).filter((t) => t.toMillis() > now - 30 * DAY_MS);

  // A driving school's name is the business, not the person holding the ID,
  // so only a private instructor's entered name is sent for Didit to match.
  const session = await didit().createSession({
    workflowId: workflowId(),
    vendorData: uid,
    ...(pub.get('kind') === 'schoolInstructor' ? { expectedDetails: splitName(pub.get('name')) } : {}),
    userState: typeof pub.get('state') === 'string' ? `US-${pub.get('state')}` : undefined,
    biometricConsent: { given_at: consentAt.toDate().toISOString(), text_version: consentVersion },
  }).catch((e) => {
    functions.logger.error('createIdentitySession: Didit refused', { uid, error: (e as Error).message });
    throw new functions.https.HttpsError('unavailable', 'identity-unavailable');
  });

  // Didit hands back the unfinished session for the same uid rather than a
  // new one, and that one doesn't count against the limit again.
  const isNew = !known.includes(session.sessionId);
  if (isNew && recent.length >= MAX_SESSIONS_PER_30_DAYS) {
    throw new functions.https.HttpsError('resource-exhausted', 'too-many-sessions');
  }
  const at = Timestamp.now();
  await db().runTransaction(async (tx) => {
    tx.set(privRef, {
      ...(isNew ? {
        identitySessionIds: FieldValue.arrayUnion(session.sessionId),
        identitySessionTimes: [...recent, at],
      } : {}),
      identityCurrentSessionId: session.sessionId,
      identityPendingSince: at,
    }, { merge: true });
    tx.update(ref, { idCheck: 'pending', idCheckReason: FieldValue.delete(), updatedAt: at });
  });
  return { sessionToken: session.sessionToken, url: session.url };
});

export type IdCheck = 'passed' | 'failed' | 'pending' | 'none';

/** Didit's session statuses (plan v2 §6.1); null for one we don't act on. */
export function idCheckFor(status: string | undefined): IdCheck | null {
  switch ((status ?? '').toLowerCase()) {
    case 'approved': return 'passed';
    case 'declined': return 'failed';
    case 'in review': case 'in progress': case 'awaiting user': case 'not started': case 'resubmitted': return 'pending';
    case 'abandoned': case 'expired': case 'kyc expired': return 'none';
    default: return null;
  }
}

/** Name, date of birth, status and document expiry; nothing else is kept. */
function keptIdentity(decision: DiditDecision, sessionId: string, at: Timestamp) {
  const id = decision.id_verifications?.[0];
  const name = id?.full_name ?? ([id?.first_name, id?.last_name].filter(Boolean).join(' ') || null);
  return {
    fullName: name, dateOfBirth: id?.date_of_birth ?? null, documentExpiresOn: id?.expiration_date ?? null,
    status: decision.status ?? null, sessionId, checkedAt: at,
  };
}

/** A decline reason we can show and search for: Didit's risk code, never personal data. */
function declineReason(decision: DiditDecision): string | null {
  for (const id of decision.id_verifications ?? []) {
    const risk = id.warnings?.find((w) => typeof w.risk === 'string')?.risk;
    if (risk && /^[A-Z0-9_]{2,64}$/.test(risk)) return risk;
  }
  return null;
}

/**
 * Applies one session status to the instructor, once per `dedupeKey` (in the
 * same transaction as the change, like stripeWebhook). A passed check is
 * never undone by a late or out-of-order event. The push goes only when the
 * result actually changed, so a webhook and a reconcile of the same result
 * notify once.
 */
export async function applyIdentityStatus(
  uid: string, sessionId: string, status: string, decision: DiditDecision | null, dedupeKey: string | null,
): Promise<IdCheck | null> {
  const next = idCheckFor(status);
  if (!next) return null;
  const ref = db().collection('instructors').doc(uid);
  const privRef = db().collection('instructorPrivate').doc(uid);
  const dedupe = dedupeKey ? db().collection('processedWebhooks').doc(dedupeKey) : null;
  const changed = await db().runTransaction(async (tx) => {
    if (dedupe && (await tx.get(dedupe)).exists) return null;
    const [pub, priv] = await Promise.all([tx.get(ref), tx.get(privRef)]);
    if (!pub.exists || !((priv.get('identitySessionIds') ?? []) as string[]).includes(sessionId)) {
      functions.logger.warn('Didit: a session that is not this instructor\'s', { uid, sessionId });
      if (dedupe) tx.create(dedupe, { processedAt: Timestamp.now(), ignored: 'unknown-session' });
      return null;
    }
    if (dedupe) tx.create(dedupe, { uid, sessionId, status: next, processedAt: Timestamp.now() });
    const current = pub.get('idCheck');
    if (current === 'passed' && next !== 'passed') return null;
    // Still pending (a reconcile every 15 min): nothing to write.
    if (current === next && !decision) return null;
    // An older session's news doesn't overwrite the one in progress.
    if (priv.get('identityCurrentSessionId') && priv.get('identityCurrentSessionId') !== sessionId && next !== 'passed') return null;
    const at = Timestamp.now();
    tx.update(ref, {
      idCheck: next,
      idCheckReason: next === 'failed' && decision ? (declineReason(decision) ?? 'declined') : FieldValue.delete(),
      ...(next === 'passed' ? { idCheckedAt: at } : {}),
      updatedAt: at,
    });
    tx.set(privRef, {
      ...(next === 'pending' ? {} : { identityPendingSince: FieldValue.delete() }),
      ...(decision && (next === 'passed' || next === 'failed') ? { identity: keptIdentity(decision, sessionId, at) } : {}),
    }, { merge: true });
    return current !== next ? next : null;
  });
  if (changed === 'passed') await sendPushToUser(uid, 'identity_passed', 'profile');
  if (changed === 'failed') await sendPushToUser(uid, 'identity_failed', 'profile');
  return changed;
}

/** Only these webhook statuses come with a result worth fetching. */
const FINAL = ['approved', 'declined'];

/**
 * Didit's `status.updated` webhook. The V2 signature is checked first; the
 * result is fetched from the API (the decision), never taken from the body.
 * A sandbox event in production — or a live one on the emulator — is
 * ignored. A failure is dead-lettered WITHOUT the decision (it holds
 * personal data) and Didit asked to retry (it does so only twice;
 * reconcileIdentitySessions catches the rest).
 */
export const diditWebhook = functions.runWith({ secrets: DIDIT_SECRETS }).https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('POST only');
    return;
  }
  const body = req.body as Record<string, unknown>;
  if (!verifyDiditSignature(body, req.header('x-signature-v2'), req.header('x-timestamp'), [webhookSecret()])) {
    res.status(401).send('Bad signature');
    return;
  }
  const eventId = String(body.event_id ?? '');
  const sessionId = String(body.session_id ?? '');
  const status = String(body.status ?? '');
  const uid = String(body.vendor_data ?? '');
  const expected = process.env.FUNCTIONS_EMULATOR === 'true' ? 'sandbox' : 'live';
  if (body.webhook_type !== 'status.updated' || !eventId || !sessionId || !uid || body.environment !== expected) {
    functions.logger.info('diditWebhook: ignored', { type: body.webhook_type, environment: body.environment });
    res.status(200).json({ received: true });
    return;
  }
  try {
    const decision = FINAL.includes(status.toLowerCase()) ? await didit().getDecision(sessionId) : null;
    // The fetched decision decides, if there is one.
    await applyIdentityStatus(uid, sessionId, decision?.status ?? status, decision, `didit_${eventId}`);
    res.status(200).json({ received: true });
  } catch (error) {
    const r = await recordWebhookFailure(db(), {
      source: 'didit', key: eventId, notificationType: status,
      payload: { event_id: eventId, session_id: sessionId, status, vendor_data: uid }, error,
    });
    res.status(r.shouldRetry ? 500 : 200).json({ received: !r.shouldRetry });
  }
});

/**
 * The poll fallback (plan v2 §6.1 step 5): every 15 min, the decision of
 * each session still pending after 10 min. No dedupe key: the transaction
 * compares states, so a result the webhook already applied changes nothing.
 */
export async function runReconcileIdentitySessions(nowMs = Date.now()): Promise<number> {
  const due = await db().collection('instructorPrivate')
    .where('identityPendingSince', '<=', Timestamp.fromMillis(nowMs - RECONCILE_AFTER_MS))
    .limit(100).get();
  let applied = 0;
  for (const doc of due.docs) {
    const sessionId = doc.get('identityCurrentSessionId');
    if (typeof sessionId !== 'string') continue;
    try {
      const decision = await didit().getDecision(sessionId);
      if (decision.status) {
        const known = FINAL.includes(decision.status.toLowerCase());
        if ((await applyIdentityStatus(doc.id, sessionId, decision.status, known ? decision : null, null)) !== null) applied++;
      }
    } catch (error) {
      functions.logger.error('reconcileIdentitySessions: decision failed', { uid: doc.id, error: (error as Error).message });
    }
  }
  return applied;
}

/** Also retries the Didit erasures of deleted accounts (below). */
export const reconcileIdentitySessions = functions.runWith({ secrets: DIDIT_SECRETS })
  .pubsub.schedule('every 15 minutes').onRun(async () => {
    await runReconcileIdentitySessions();
    await runDiditErasures();
  });

// ── Account deletion (plan v2 §17) ───────────────────────────────────────────

const ERASURE_RETRY_MS = 60 * 60 * 1000;

/**
 * Erases everything Didit holds for an instructor: each session (privacy
 * erasure, which also purges any retained face template), then the Didit
 * User. Both calls are idempotent at Didit (a deleted session answers 404,
 * a deleted user counts 0), so a retry after a partial failure is safe.
 */
export async function eraseDiditData(uid: string, sessionIds: string[]): Promise<void> {
  const client = didit();
  for (const id of sessionIds) await client.deleteSession(id);
  await client.deleteUsers([uid]);
}

/**
 * Called by deleteUserAccount with the session ids it read before the data
 * went. Queued first, so a failure here (or Didit being down) never blocks
 * the account deletion: runDiditErasures retries it every hour.
 */
export async function eraseDiditDataForDeletedAccount(uid: string, sessionIds: string[]): Promise<void> {
  if (sessionIds.length === 0) return;
  const ref = db().collection('diditErasures').doc(uid);
  try {
    await ref.set({ sessionIds, retryAt: Timestamp.now(), attempts: 0 }, { merge: true });
    await eraseDiditData(uid, sessionIds);
    await ref.delete();
  } catch (error) {
    functions.logger.error('Didit erasure failed, will retry', { uid, error: (error as Error).message });
    await ref.update({ retryAt: Timestamp.fromMillis(Date.now() + ERASURE_RETRY_MS), attempts: FieldValue.increment(1) })
      .catch(() => {});
  }
}

export async function runDiditErasures(nowMs = Date.now()): Promise<number> {
  const due = await db().collection('diditErasures').where('retryAt', '<=', Timestamp.fromMillis(nowMs)).limit(50).get();
  let done = 0;
  for (const doc of due.docs) {
    try {
      await eraseDiditData(doc.id, doc.get('sessionIds') ?? []);
      await doc.ref.delete();
      done++;
    } catch (error) {
      functions.logger.error('Didit erasure retry failed', { uid: doc.id, error: (error as Error).message });
      await doc.ref.update({ retryAt: Timestamp.fromMillis(nowMs + ERASURE_RETRY_MS), attempts: FieldValue.increment(1) });
    }
  }
  return done;
}
