import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import type Stripe from 'stripe';
import { stripe, verifyWebhook, functionUrl, STRIPE_SECRETS } from './stripe-client';
import { settlePayment, processRefund, PAYOUT_HOLD_MS } from './bookings';
import { recordWebhookFailure } from './webhook-dead-letter';
import { sendPushToUser } from './push';
import { sweepPaginated, SWEEP_TIME_BUDGET_MS, SweepResult } from './sweep';

/**
 * Stripe Connect (instructors plan v2 §9.2–§9.4, P9; test mode only).
 *
 * Separate charges and transfers: the student pays the platform
 * (bookings.ts, stripeGateway); 48 h after the lesson the school's price is
 * transferred to its connected account (releaseInstructorPayouts); the
 * service fee stays. Only a driving school (`kind == 'school'`) takes
 * payments (§6.2).
 *
 * Connected accounts are Accounts v2 (Stripe refuses v1 account creation on
 * a new platform): the Recipient configuration only — the platform is the
 * merchant of record — with the Express dashboard, the platform collecting
 * fees and carrying losses, Stripe collecting the KYC. "Ready" is the
 * recipient's `stripe_transfers` and `payouts` both active. Charges,
 * refunds and transfers stay on v1, which takes a v2 account id as is.
 */

const db = () => admin.firestore();

// ── Webhook ──────────────────────────────────────────────────────────────────

/**
 * One endpoint for the platform's events, connected accounts' events and the
 * v2 account events (thin: id + type + related object; `stripe listen
 * --forward-to … --forward-connect-to …` with the v2 types in `--events`). The signature is
 * checked first; each state change dedupes on processedWebhooks/stripe_<id>
 * inside its own transaction, so a redelivery changes nothing (the store
 * webhooks check, then write — not copied here). A failure is dead-lettered
 * and Stripe asked to retry a bounded number of times.
 */
export const stripeWebhook = functions.runWith({ secrets: STRIPE_SECRETS }).https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('POST only');
    return;
  }
  const event = verifyWebhook(req.rawBody, req.header('stripe-signature'));
  if (!event) {
    res.status(400).send('Bad signature');
    return;
  }
  if (event.livemode && process.env.FUNCTIONS_EMULATOR === 'true') {
    functions.logger.error('stripeWebhook: a live-mode event on the emulator, ignored', { id: event.id, type: event.type });
    res.status(200).json({ received: true });
    return;
  }
  try {
    await handleStripeEvent(event);
    res.status(200).json({ received: true });
  } catch (error) {
    const r = await recordWebhookFailure(db(), { source: 'stripe', key: event.id, notificationType: event.type, payload: event, error });
    res.status(r.shouldRetry ? 500 : 200).json({ received: !r.shouldRetry });
  }
});

/** The v2 account events that can change whether a school is ready. */
export const ACCOUNT_EVENTS = [
  'v2.core.account[configuration.recipient].capability_status_updated',
  'v2.core.account[requirements].updated',
];

export async function handleStripeEvent(event: Stripe.Event): Promise<void> {
  const dedupe = db().collection('processedWebhooks').doc(`stripe_${event.id}`);
  const thin = event as unknown as { object?: string; type: string; related_object?: { id?: string } | null };
  if (thin.object === 'v2.core.event') {
    // A thin event carries no account state: read it fresh.
    if (ACCOUNT_EVENTS.includes(thin.type) && thin.related_object?.id) {
      await applyAccountState(await readAccount(thin.related_object.id), dedupe);
    }
    return;
  }
  switch (event.type) {
    case 'payment_intent.succeeded': {
      const pi = event.data.object;
      const bookingId = pi.metadata?.bookingId;
      if (!bookingId) return;
      const chargeId = typeof pi.latest_charge === 'string' ? pi.latest_charge : pi.latest_charge?.id ?? null;
      const outcome = await settlePayment(bookingId, { dedupe, paymentIntentId: pi.id, chargeId });
      functions.logger.info('stripeWebhook payment_intent.succeeded', { bookingId, outcome });
      return;
    }
    case 'account.updated':
      // v1 still reports a v2 account's changes to Connect webhooks; read the v2 state.
      await applyAccountState(await readAccount(event.data.object.id), dedupe);
      return;
    case 'charge.dispute.created':
    case 'charge.dispute.updated':
    case 'charge.dispute.closed':
      await recordDispute(event.data.object, dedupe);
      return;
    default:
      return;
  }
}

/**
 * A card dispute (chargeback) on a lesson's charge. The platform is the
 * merchant of record, so the dispute is ours; Stripe runs it. What we record:
 * `disputeStatus` (`open` while Stripe's status is a `needs_response` /
 * `under_review` kind, then Stripe's final word), the id, reason and amount.
 * An open dispute holds the payout; anything but `won` keeps it held for
 * the admin (P10).
 */
async function recordDispute(dispute: Stripe.Dispute, dedupe: FirebaseFirestore.DocumentReference) {
  const pi = typeof dispute.payment_intent === 'string' ? dispute.payment_intent : dispute.payment_intent?.id;
  if (!pi) return;
  const found = await db().collection('bookings').where('stripePaymentIntentId', '==', pi).limit(1).get();
  if (found.empty) {
    functions.logger.warn('stripeWebhook: dispute for an unknown PaymentIntent', { dispute: dispute.id });
    return;
  }
  const ref = found.docs[0].ref;
  const closed = ['won', 'lost', 'warning_closed', 'prevented'].includes(dispute.status);
  await db().runTransaction(async (tx) => {
    if ((await tx.get(dedupe)).exists) return;
    tx.create(dedupe, { bookingId: ref.id, processedAt: Timestamp.now() });
    tx.update(ref, {
      disputeStatus: closed ? dispute.status : 'open',
      stripeDisputeId: dispute.id,
      disputeReason: dispute.reason ?? null,
      disputeAmountCents: dispute.amount ?? null,
      updatedAt: Timestamp.now(),
    });
  });
}

// ── Payouts onboarding (plan v2 §9.2, §14.2) ─────────────────────────────────

async function schoolOf(uid: string) {
  const doc = await db().collection('instructors').doc(uid).get();
  if (!doc.exists) throw new functions.https.HttpsError('failed-precondition', 'not-an-instructor');
  if (doc.get('kind') !== 'school') throw new functions.https.HttpsError('failed-precondition', 'not-a-school');
  return doc;
}

function signedIn(context: any): string {
  if (!context?.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  return context.auth.uid;
}

/**
 * Creates the school's connected account the first time (kept as
 * `stripePendingAccountId` and reused on every retry; the idempotency key
 * covers two taps at once) and returns a one-time onboarding link. Weekly
 * payouts on Mondays, so the per-payout fee is shared across lessons (§9.1):
 * v2 has no payout schedule, so it is set through v1 before the id is kept
 * (a failure there retries the whole step; the create key returns the same
 * account for 24 h).
 */
export const startInstructorPayouts = functions.runWith({ secrets: STRIPE_SECRETS }).https.onCall(async (_data, context) => {
  const uid = signedIn(context);
  const school = await schoolOf(uid);
  if (school.get('status') === 'suspended') throw new functions.https.HttpsError('failed-precondition', 'suspended');
  const privRef = db().collection('instructorPrivate').doc(uid);
  const priv = await privRef.get();
  let accountId: string | null = priv.get('stripeAccountId') ?? priv.get('stripePendingAccountId') ?? null;
  if (!accountId) {
    const account = await stripe().v2.core.accounts.create({
      contact_email: priv.get('contactEmail') ?? undefined,
      display_name: school.get('name') ?? undefined,
      dashboard: 'express',
      identity: { country: 'us' },
      defaults: {
        responsibilities: { fees_collector: 'application', losses_collector: 'application' },
        profile: { product_description: 'Driving lessons booked through the DriveUSA app' },
      },
      configuration: { recipient: { capabilities: { stripe_balance: { stripe_transfers: { requested: true } } } } },
      metadata: { uid },
    }, { idempotencyKey: `instructor-account-${uid}` });
    await stripe().accounts.update(account.id, {
      settings: { payouts: { schedule: { interval: 'weekly', weekly_anchor: 'monday' } } },
    }, { idempotencyKey: `instructor-payout-schedule-${account.id}` });
    accountId = account.id;
    await privRef.set({ stripePendingAccountId: accountId }, { merge: true });
  }
  const link = await stripe().v2.core.accountLinks.create({
    account: accountId,
    use_case: {
      type: 'account_onboarding',
      account_onboarding: {
        configurations: ['recipient'],
        refresh_url: `${functionUrl('stripeOnboardingReturn')}?expired=1`,
        return_url: functionUrl('stripeOnboardingReturn'),
      },
    },
  });
  return { url: link.url };
});

/** The account with what the ready check needs (v2 leaves configurations out unless asked). */
export async function readAccount(accountId: string): Promise<Stripe.V2.Core.Account> {
  return stripe().v2.core.accounts.retrieve(accountId, { include: ['configuration.recipient', 'requirements'] });
}

/**
 * The payouts card's state: `none` (nothing started), `pending` (an account
 * exists but Stripe still needs something), `enabled`. Re-reads the account
 * from Stripe while it is pending, so the card is right when the app comes
 * back from onboarding even if the webhook has not arrived yet.
 */
export const getInstructorPayouts = functions.runWith({ secrets: STRIPE_SECRETS }).https.onCall(async (_data, context) => {
  const uid = signedIn(context);
  const school = await schoolOf(uid);
  const priv = await db().collection('instructorPrivate').doc(uid).get();
  const accountId: string | null = priv.get('stripeAccountId') ?? priv.get('stripePendingAccountId') ?? null;
  if (!accountId) return { state: school.get('payoutsEnabled') === true ? 'enabled' : 'none' };
  let detailsSubmitted = false;
  try {
    const account = await readAccount(accountId);
    detailsSubmitted = detailsDone(account);
    await applyAccountState(account);
  } catch (e: any) {
    functions.logger.warn('getInstructorPayouts: account not read', { uid, code: e?.code ?? String(e) });
  }
  const enabled = (await db().collection('instructors').doc(uid).get()).get('payoutsEnabled') === true;
  return { state: enabled ? 'enabled' : 'pending', detailsSubmitted };
});

/** Ready to receive transfers and pay them out. */
export function accountReady(account: Pick<Stripe.V2.Core.Account, 'configuration'>): boolean {
  const balance = account.configuration?.recipient?.capabilities?.stripe_balance;
  return balance?.stripe_transfers?.status === 'active' && balance?.payouts?.status === 'active';
}

/** The school has given Stripe everything asked for (what is left waits on Stripe). */
function detailsDone(account: Pick<Stripe.V2.Core.Account, 'requirements'>): boolean {
  return !(account.requirements?.entries ?? []).some((e) => e.awaiting_action_from === 'user');
}

/**
 * Copies a connected account's state onto the school (read after a webhook
 * or by the app's status check): ready → `instructorPrivate.stripeAccountId` and
 * `payoutsEnabled: true` (onInstructorWrite recomputes the stage); no longer
 * ready → `payoutsEnabled: false`. The account must be the one we created
 * for that uid. A school that just became ready is told.
 */
export async function applyAccountState(account: Pick<Stripe.V2.Core.Account, 'id' | 'metadata' | 'configuration'>, dedupe?: FirebaseFirestore.DocumentReference): Promise<void> {
  const uid = account.metadata?.uid;
  if (!uid) return;
  const privRef = db().collection('instructorPrivate').doc(uid);
  const instRef = db().collection('instructors').doc(uid);
  const becameReady = await db().runTransaction(async (tx) => {
    if (dedupe && (await tx.get(dedupe)).exists) return false;
    const [priv, inst] = await Promise.all([tx.get(privRef), tx.get(instRef)]);
    if (dedupe) tx.create(dedupe, { accountId: account.id, processedAt: Timestamp.now() });
    if (!priv.exists || !inst.exists
      || (priv.get('stripePendingAccountId') !== account.id && priv.get('stripeAccountId') !== account.id)) {
      functions.logger.warn('applyAccountState: account not ours for that uid', { accountId: account.id });
      return false;
    }
    const ready = accountReady(account);
    const was = inst.get('payoutsEnabled') === true;
    if (ready) tx.update(privRef, { stripeAccountId: account.id });
    if (ready !== was) tx.update(instRef, { payoutsEnabled: ready, updatedAt: Timestamp.now() });
    return ready && !was;
  });
  if (becameReady) await sendPushToUser(uid, 'payouts_enabled', 'profile');
}

/**
 * Where Stripe sends the school after onboarding (an account link must
 * return to an http(s) URL). Stripe passes no state, so this page only says
 * to go back; the app re-reads the account when it comes to the foreground.
 * Deliberately no `driveusa://` link: the app's deep-link routing is for
 * email action codes.
 */
export const stripeOnboardingReturn = functions.https.onRequest((req, res) => {
  const expired = req.query.expired !== undefined;
  const text = expired
    ? 'This link has expired. Go back to the DriveUSA app and tap «Set up payouts» again.'
    : 'Thank you. Go back to the DriveUSA app — your payouts card shows what Stripe still needs, if anything.';
  res.set('Cache-Control', 'no-store');
  res.status(200).send(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DriveUSA</title></head>`
    + `<body style="font-family:-apple-system,system-ui,sans-serif;padding:32px 24px;font-size:18px;line-height:1.4;color:#111"><h1 style="font-size:24px">DriveUSA</h1><p>${text}</p></body></html>`);
});

// ── No-show (plan v2 §9.3) ───────────────────────────────────────────────────

/** How long after a lesson ends the student can say it didn't happen. */
export const NO_SHOW_WINDOW_MS = PAYOUT_HOLD_MS;
const NO_SHOW_REASONS = ['instructor_no_show', 'lesson_not_given', 'other'];

/**
 * The student says the lesson didn't happen: `completed` → `disputed`,
 * within 48 h of its end, so before the payout. The payout is held
 * (releaseInstructorPayouts only takes `completed`); the admin resolves it
 * in P10 (refund or release).
 */
export const reportNoShow = functions.https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const bookingId = data?.bookingId;
  if (typeof bookingId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(bookingId)) {
    throw new functions.https.HttpsError('invalid-argument', 'A booking id is required.');
  }
  const reason = NO_SHOW_REASONS.includes(data?.reason) ? data.reason : 'other';
  const ref = db().collection('bookings').doc(bookingId);
  await db().runTransaction(async (tx) => {
    const b = await tx.get(ref);
    if (!b.exists || b.get('studentUid') !== uid) throw new functions.https.HttpsError('permission-denied', 'Not your booking.');
    const endMs = b.get('startAt').toMillis() + b.get('durationMinutes') * 60000;
    if (b.get('status') !== 'completed' || Date.now() > endMs + NO_SHOW_WINDOW_MS) {
      throw new functions.https.HttpsError('failed-precondition', 'not-reportable');
    }
    const at = Timestamp.now();
    tx.update(ref, { status: 'disputed', noShowReason: reason, noShowReportedAt: at, updatedAt: at });
  });
  return { bookingId, status: 'disputed' };
});

// ── Release, refund retries, account closing (hourly) ────────────────────────

/** Is this booking's money ready to go to the school? */
function releasable(b: FirebaseFirestore.DocumentSnapshot, nowMs: number): boolean {
  const dispute = b.get('disputeStatus');
  return ['completed', 'late_cancelled'].includes(b.get('status'))
    && (dispute == null || dispute === 'won')
    && (b.get('payoutReleaseAt')?.toMillis() ?? Infinity) <= nowMs;
}

/**
 * Pays schools (plan v2 §9.2 step 4): every `completed` (or `late_cancelled`)
 * lesson past `payoutReleaseAt` with no open dispute → a transfer of the
 * lesson price to the school's account, tied to the lesson's charge
 * (`source_transaction`, so it never fails on the platform's available
 * balance) → `payout_released` (a late cancel keeps its status and gets
 * `payoutReleasedAt` only). `payoutReleaseAt` exists only while a lesson
 * waits, so the query needs no index. A lesson the emulator's gateway "paid"
 * has no charge and is marked released without Stripe.
 */
export async function runReleaseInstructorPayouts(nowMs = Date.now()): Promise<SweepResult> {
  return sweepPaginated({
    label: 'releaseInstructorPayouts',
    baseQuery: db().collection('bookings').where('payoutReleaseAt', '<=', Timestamp.fromMillis(nowMs)).orderBy('payoutReleaseAt'),
    deadline: Date.now() + SWEEP_TIME_BUDGET_MS,
    handle: async (doc) => {
      const b = await doc.ref.get();
      if (!releasable(b, nowMs)) return;
      const stripePaid = b.get('paymentProvider') === 'stripe';
      let transferId: string | null = null;
      if (stripePaid) {
        const chargeId: string | undefined = b.get('stripeChargeId');
        const priv = await db().collection('instructorPrivate').doc(b.get('instructorUid')).get();
        const destination: string | undefined = priv.get('stripeAccountId');
        if (!chargeId || !destination) {
          functions.logger.warn('releaseInstructorPayouts: no charge or no connected account yet, retried next hour', { bookingId: doc.id });
          return;
        }
        const transfer = await stripe().transfers.create({
          amount: b.get('lessonCents'),
          currency: 'usd',
          destination,
          source_transaction: chargeId,
          transfer_group: doc.id,
          metadata: { bookingId: doc.id },
        }, { idempotencyKey: `booking-transfer-${doc.id}` });
        transferId = transfer.id;
      }
      await db().runTransaction(async (tx) => {
        const now = await tx.get(doc.ref);
        if (!releasable(now, nowMs)) return;
        const at = Timestamp.now();
        tx.update(doc.ref, {
          // A late cancel stays `late_cancelled`: the lesson never happened,
          // so it must not read «Прошёл» or become reviewable (found on the
          // simulator 2026-10-17); `payoutReleasedAt` says it was paid.
          status: now.get('status') === 'completed' ? 'payout_released' : now.get('status'),
          stripeTransferId: transferId,
          payoutReleasedAt: at,
          payoutReleaseAt: FieldValue.delete(),
          updatedAt: at,
        });
      });
    },
  });
}

/** Refunds whose Stripe call failed (processRefund leaves `refundDueAt`). */
export async function runRetryRefunds(nowMs = Date.now()): Promise<SweepResult> {
  return sweepPaginated({
    label: 'retryRefunds',
    // Only ones that waited a while: a fresh refund is still being made by its own callable.
    baseQuery: db().collection('bookings').where('refundDueAt', '<=', Timestamp.fromMillis(nowMs - 10 * 60000)).orderBy('refundDueAt'),
    deadline: Date.now() + SWEEP_TIME_BUDGET_MS,
    handle: async (doc) => { await processRefund(doc.id); },
  });
}

/**
 * A deleted school's connected account is closed after its last payout
 * (plan v2 §17). Stripe refuses to close an account with money on it, so a
 * refusal leaves the request for the next hour.
 */
export async function closeConnectedAccount(accountId: string): Promise<boolean> {
  const ref = db().collection('stripeAccountClosures').doc(accountId);
  try {
    await stripe().v2.core.accounts.close(accountId, { applied_configurations: ['recipient'] });
    await ref.delete();
    return true;
  } catch (e: any) {
    if (e?.code === 'resource_missing') {
      await ref.delete();
      return true;
    }
    await ref.set({ accountId, attempts: FieldValue.increment(1), lastError: String(e?.code ?? e?.message ?? e).slice(0, 200), retryAt: Timestamp.fromMillis(Date.now() + 3600 * 1000) }, { merge: true });
    return false;
  }
}

export async function runCloseConnectedAccounts(nowMs = Date.now()): Promise<SweepResult> {
  return sweepPaginated({
    label: 'closeConnectedAccounts',
    baseQuery: db().collection('stripeAccountClosures').where('retryAt', '<=', Timestamp.fromMillis(nowMs)).orderBy('retryAt'),
    deadline: Date.now() + SWEEP_TIME_BUDGET_MS,
    handle: async (doc) => { await closeConnectedAccount(doc.id); },
  });
}

export const releaseInstructorPayouts = functions
  .runWith({ timeoutSeconds: 540, memory: '256MB', secrets: STRIPE_SECRETS })
  .pubsub.schedule('every 60 minutes').timeZone('America/Chicago')
  .onRun(async () => {
    await runReleaseInstructorPayouts();
    await runRetryRefunds();
    await runCloseConnectedAccounts();
  });
