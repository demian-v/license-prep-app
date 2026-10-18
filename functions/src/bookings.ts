import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldPath, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { defineInt } from 'firebase-functions/params';
import { listedInstructor } from './instructors';
import { studentDisplayName } from './chat';
import { sendPushToUser, Lang } from './push';
import { sweepPaginated, SWEEP_TIME_BUDGET_MS, SweepResult } from './sweep';
import { wallClock, wallToUtc, weekDay, addDays, minutesOf, hhmm } from './zone';
import { stripe, stripeConfigured, publishableKey, STRIPE_SECRETS } from './stripe-client';

/**
 * Bookings without money (instructors plan v2 §9, P7).
 *
 * bookings/{id} and bookingSlots/{instructorUid}_{yyyyMMddTHHmm} are written
 * only here (firestore.rules: bookings read by its two sides, slots closed).
 * One slot doc per booked half hour; `tx.create()` of every slot is the lock,
 * so two students racing for the same time cannot both win.
 *
 * Who books: a paid student, only a driving school (`kind == 'school'`) at
 * stage 2 (ID + licence + payouts + hours, computeListing). Private
 * instructors never take bookings (plan v2 §6.2).
 *
 * Payment sits behind PaymentGateway (P9, 2026-10-17): Stripe when its
 * secret key is set — a PaymentIntent on the platform account, confirmed by
 * stripeWebhook (payments.ts); otherwise the emulator's instant gateway (jest
 * and the seed); anywhere else none, so createBooking refuses before locking
 * anything.
 *
 * The schedulers query one field each — `expiresAt` exists only while a
 * booking is `pending_payment`, `completeAfter` only while it is `confirmed`
 * — so neither needs a composite index (risk #15).
 */

export const SLOT_MINUTES = 30;
const SLOT_MS = SLOT_MINUTES * 60 * 1000;
const HOUR_MS = 3600 * 1000;
export const MIN_LEAD_MS = 12 * HOUR_MS;
export const MAX_AHEAD_MS = 60 * 24 * HOUR_MS;
export const HOLD_MS = 15 * 60 * 1000;
export const FREE_CANCEL_MS = 24 * HOUR_MS;
/** Payout release after the lesson ends (plan v2 §9.2 step 3). */
export const PAYOUT_HOLD_MS = 48 * HOUR_MS;
/** Open, unpaid holds one student may have at once (P9 decision, risk register P7 residual). */
export const MAX_OPEN_HOLDS = 2;

// Fee settings (plan v2 §9.1): function params, never in client code.
const firstFeeBps = defineInt('FIRST_FEE_BPS', { default: 2500 });
const laterFeeBps = defineInt('LATER_FEE_BPS', { default: 500 });
const laterFeeMinCents = defineInt('LATER_FEE_MIN_CENTS', { default: 150 });

export type FeeKind = 'first' | 'later';

export interface Fees {
  lessonCents: number;
  platformFeeCents: number;
  totalCents: number;
  feeKind: FeeKind;
}

/**
 * The fee goes on top; the instructor always gets their full price (plan v2
 * §9.1): 25% on the first lesson with an instructor, then 5% with a $1.50
 * minimum.
 */
export function computeFees(
  hourlyRateCents: number,
  durationMinutes: number,
  feeKind: FeeKind,
  s = { firstBps: firstFeeBps.value(), laterBps: laterFeeBps.value(), laterMinCents: laterFeeMinCents.value() },
): Fees {
  const lessonCents = Math.round((hourlyRateCents * durationMinutes) / 60);
  const platformFeeCents = feeKind === 'first'
    ? Math.round((lessonCents * s.firstBps) / 10000)
    : Math.max(Math.round((lessonCents * s.laterBps) / 10000), s.laterMinCents);
  return { lessonCents, platformFeeCents, totalCents: lessonCents + platformFeeCents, feeKind };
}

/**
 * Statuses that mean the pair has had its first lesson (plan v2 §9.3). An
 * expired or refunded booking does not count, so the next one is a first
 * lesson again; a late cancel keeps its fee, so the next one is not.
 */
const FEE_BEARING = new Set(['pending_payment', 'confirmed', 'completed', 'late_cancelled', 'disputed', 'payout_released']);

export function feeKindFor(studentBookings: FirebaseFirestore.DocumentData[], instructorUid: string, nowMs: number): FeeKind {
  const had = studentBookings.some((b) => b.instructorUid === instructorUid && FEE_BEARING.has(b.status)
    && !(b.status === 'pending_payment' && (b.expiresAt?.toMillis() ?? 0) <= nowMs));
  return had ? 'later' : 'first';
}

/** `yyyyMMddTHHmm` in UTC — the slot doc id after the instructor's uid. */
export function slotKey(ms: number): string {
  return new Date(ms).toISOString().slice(0, 16).replace(/[-:]/g, '');
}

const slotRef = (instructorUid: string, ms: number) =>
  admin.firestore().collection('bookingSlots').doc(`${instructorUid}_${slotKey(ms)}`);

/** The half-hour starts a lesson occupies. */
function cellsOf(startMs: number, durationMinutes: number): number[] {
  return Array.from({ length: durationMinutes / SLOT_MINUTES }, (_, i) => startMs + i * SLOT_MS);
}

type Availability = Record<string, { start: string; end: string }[]>;

/** Is this half hour inside the instructor's weekly hours, on `date`? */
function open(availability: Availability, tz: string, cellMs: number, date: string): boolean {
  const local = wallClock(cellMs, tz);
  if (local.date !== date) return false;
  return (availability[weekDay(date)] ?? []).some((i) =>
    minutesOf(i.start) <= local.minutes && local.minutes + SLOT_MINUTES <= minutesOf(i.end));
}

// ── Payment gateway ──────────────────────────────────────────────────────────

/** What the app needs to open Stripe's PaymentSheet. */
export interface PaymentStart {
  clientSecret: string;
  publishableKey: string;
}

/**
 * Takes a `pending_payment` booking towards `confirmed`. Stripe creates a
 * PaymentIntent and returns what the app's PaymentSheet needs; the webhook
 * then calls settlePayment. The emulator's gateway confirms at once.
 */
export interface PaymentGateway {
  provider?: 'emulator' | 'stripe';
  begin(bookingId: string, totalCents: number): Promise<PaymentStart | void>;
}

/** The emulator "pays" at once, so the whole flow runs without money. */
const emulatorGateway: PaymentGateway = {
  provider: 'emulator',
  begin: (bookingId) => confirmBooking(bookingId).then(() => undefined),
};

/**
 * Separate charges and transfers (plan v2 §9.2): the charge is on the
 * platform account, `transfer_group` ties the later transfer to it. Cards
 * only for now (owner decision: Apple Pay / Google Pay later).
 */
const stripeGateway: PaymentGateway = {
  provider: 'stripe',
  async begin(bookingId, totalCents) {
    const pi = await stripe().paymentIntents.create({
      amount: totalCents,
      currency: 'usd',
      payment_method_types: ['card'],
      transfer_group: bookingId,
      description: 'Driving lesson',
      metadata: { bookingId },
    }, { idempotencyKey: `booking-pi-${bookingId}` });
    await admin.firestore().collection('bookings').doc(bookingId)
      .update({ stripePaymentIntentId: pi.id, updatedAt: Timestamp.now() });
    if (!pi.client_secret) throw new Error(`PaymentIntent ${pi.id} came back without a client secret`);
    return { clientSecret: pi.client_secret, publishableKey: publishableKey() };
  },
};

let gatewayOverride: PaymentGateway | null | undefined;
/** Tests only: replace the gateway (undefined restores the default). */
export function setPaymentGateway(gateway: PaymentGateway | null | undefined) {
  gatewayOverride = gateway;
}

function paymentGateway(): PaymentGateway | null {
  if (gatewayOverride !== undefined) return gatewayOverride;
  if (stripeConfigured()) return stripeGateway;
  return process.env.FUNCTIONS_EMULATOR === 'true' ? emulatorGateway : null;
}

// ── Callables ────────────────────────────────────────────────────────────────

function signedIn(context: any): string {
  if (!context?.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  if (context.auth.token?.firebase?.sign_in_provider === 'anonymous') {
    throw new functions.https.HttpsError('permission-denied', 'Anonymous sessions cannot book.');
  }
  return context.auth.uid;
}

/**
 * The listed instructor a paid student may book: a stage-2 driving school
 * with a timezone. The detail page's gates (listedInstructor) come first.
 */
async function bookableInstructor(instructorUid: unknown, context: any) {
  const doc = await listedInstructor({ id: instructorUid }, context);
  if (doc.get('kind') !== 'school' || (doc.get('stage') ?? 0) < 2 || typeof doc.get('timezone') !== 'string') {
    throw new functions.https.HttpsError('failed-precondition', 'not-bookable');
  }
  if (doc.id === context.auth.uid) throw new functions.https.HttpsError('invalid-argument', 'Cannot book yourself.');
  return doc;
}

const durationsOf = (doc: FirebaseFirestore.DocumentSnapshot): number[] =>
  ((doc.get('lessonDurations') ?? []) as number[]).filter((d) => Number.isInteger(d) && d > 0 && d % SLOT_MINUTES === 0);

async function studentBookings(uid: string, tx?: FirebaseFirestore.Transaction) {
  const q = admin.firestore().collection('bookings').where('studentUid', '==', uid);
  return (await (tx ? tx.get(q) : q.get())).docs.map((d) => d.data());
}

/**
 * What the booking page shows (plan v2 §9.3): the free half-hour starts per
 * local date, from 12 h to 60 days ahead, and the price of each lesson length
 * for this student (first or later lesson). The app finds the starts where a
 * whole lesson fits; createBooking checks it all again.
 */
export const getBookingOptions = functions.https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const doc = await bookableInstructor(data?.instructorUid, context);
  const tz: string = doc.get('timezone');
  const availability: Availability = doc.get('availability') ?? {};
  const now = Date.now();
  const from = now + MIN_LEAD_MS;
  const to = now + MAX_AHEAD_MS;

  // Taken half hours, by doc id range — the ids sort by time, so no index.
  const taken = new Set(
    (await admin.firestore().collection('bookingSlots')
      .orderBy(FieldPath.documentId())
      .startAt(`${doc.id}_${slotKey(from)}`)
      .endAt(`${doc.id}_${slotKey(to)}`)
      .get()).docs.map((d) => d.id),
  );

  // Each free half hour as its local time and its UTC instant, so the app
  // shows the instructor's wall clock without a timezone database.
  const days: { date: string; slots: { time: string; startAtMs: number }[] }[] = [];
  const last = wallClock(to, tz).date;
  for (let date = wallClock(from, tz).date; date <= last; date = addDays(date, 1)) {
    const slots: { time: string; startAtMs: number }[] = [];
    for (const interval of availability[weekDay(date)] ?? []) {
      for (let m = minutesOf(interval.start); m + SLOT_MINUTES <= minutesOf(interval.end); m += SLOT_MINUTES) {
        const ms = wallToUtc(date, m, tz);
        if (ms === null || ms < from || ms > to || taken.has(`${doc.id}_${slotKey(ms)}`)) continue;
        slots.push({ time: hhmm(m), startAtMs: ms });
      }
    }
    slots.sort((a, b) => a.startAtMs - b.startAtMs);
    if (slots.length > 0) days.push({ date, slots });
  }

  const feeKind = feeKindFor(await studentBookings(uid), doc.id, now);
  const rate: number = doc.get('hourlyRateCents');
  return {
    timezone: tz,
    days,
    quotes: durationsOf(doc).map((durationMinutes) => ({ durationMinutes, ...computeFees(rate, durationMinutes, feeKind) })),
  };
});

/**
 * Books one lesson (plan v2 §9.2): validates, then in ONE transaction locks
 * every half hour and writes the booking as `pending_payment` for 15 minutes;
 * then hands it to the payment gateway.
 */
export const createBooking = functions.runWith({ secrets: STRIPE_SECRETS }).https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const doc = await bookableInstructor(data?.instructorUid, context);
  const tz: string = doc.get('timezone');
  const startMs = data?.startAtMs;
  const durationMinutes = data?.durationMinutes;
  const now = Date.now();

  if (!Number.isInteger(durationMinutes) || !durationsOf(doc).includes(durationMinutes)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: durationMinutes');
  }
  if (!Number.isInteger(startMs) || startMs % SLOT_MS !== 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: startAtMs');
  }
  if (startMs < now + MIN_LEAD_MS || startMs > now + MAX_AHEAD_MS) {
    throw new functions.https.HttpsError('failed-precondition', 'outside-booking-window');
  }
  const cells = cellsOf(startMs, durationMinutes);
  const date = wallClock(startMs, tz).date;
  if (!cells.every((c) => open(doc.get('availability') ?? {}, tz, c, date))) {
    throw new functions.https.HttpsError('failed-precondition', 'outside-hours');
  }

  const gateway = paymentGateway();
  if (!gateway) throw new functions.https.HttpsError('failed-precondition', 'payments-unavailable');

  const db = admin.firestore();
  const ref = db.collection('bookings').doc();
  const student = await db.collection('users').doc(uid).get();
  let fees: Fees;
  try {
    fees = await db.runTransaction(async (tx) => {
      const mine = await studentBookings(uid, tx);
      // With real money a student could otherwise hold many half hours for
      // 15 minutes each without paying (risk register, P7 residual).
      const openHolds = mine.filter((b) => b.status === 'pending_payment' && (b.expiresAt?.toMillis() ?? 0) > now).length;
      if (openHolds >= MAX_OPEN_HOLDS) throw new functions.https.HttpsError('resource-exhausted', 'too-many-holds');
      const feeKind = feeKindFor(mine, doc.id, now);
      const f = computeFees(doc.get('hourlyRateCents'), durationMinutes, feeKind);
      const at = Timestamp.now();
      for (const c of cells) {
        tx.create(slotRef(doc.id, c), { instructorUid: doc.id, bookingId: ref.id, startAt: Timestamp.fromMillis(c) });
      }
      tx.create(ref, {
        studentUid: uid,
        instructorUid: doc.id,
        // Denormalised for the two lists, like conversations (§17 clears them).
        studentDisplayName: studentDisplayName(student.get('name')),
        instructorName: doc.get('name') ?? '',
        schoolAddress: doc.get('schoolAddress') ?? null,
        startAt: Timestamp.fromMillis(startMs),
        // The lesson's wall clock where it happens (owner, 2026-10-05: times
        // are shown in the instructor's timezone), for the app's lists.
        localDate: date,
        localTime: hhmm(wallClock(startMs, tz).minutes),
        durationMinutes,
        timezone: tz,
        ...f,
        status: 'pending_payment',
        paymentProvider: gateway.provider ?? 'emulator',
        expiresAt: Timestamp.fromMillis(now + HOLD_MS),
        createdAt: at,
        updatedAt: at,
      });
      return f;
    });
  } catch (e: any) {
    // gRPC 6 = ALREADY_EXISTS: a half hour was taken since the page loaded.
    if (e?.code === 6 || e?.code === 'already-exists') {
      throw new functions.https.HttpsError('already-exists', 'slot-taken');
    }
    throw e;
  }

  let payment: PaymentStart | void;
  try {
    payment = await gateway.begin(ref.id, fees.totalCents);
  } catch (e) {
    // No PaymentIntent, no payment: give the half hours back at once.
    functions.logger.error('createBooking: the payment could not start', { bookingId: ref.id, error: String(e) });
    await expireHold(ref);
    throw new functions.https.HttpsError('unavailable', 'payment-start-failed');
  }
  const status = (await ref.get()).get('status');
  return { bookingId: ref.id, status, ...fees, payment: payment ?? null };
});

/**
 * The student closed the PaymentSheet without paying: the hold ends now
 * instead of after 15 minutes, so the time is free again and the hold no
 * longer counts against MAX_OPEN_HOLDS.
 *
 * The sheet can report a failure for a payment that went through (the
 * connection dropped at the end), so Stripe is asked first: a succeeded
 * PaymentIntent confirms the booking here (the webhook then finds it
 * settled), a processing one keeps the hold for the webhook. The app reads
 * the returned status.
 */
export const releaseBookingHold = functions.runWith({ secrets: STRIPE_SECRETS }).https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const ref = admin.firestore().collection('bookings').doc(bookingIdOf(data));
  const b = await ref.get();
  if (!b.exists || b.get('studentUid') !== uid) throw new functions.https.HttpsError('permission-denied', 'Not your booking.');
  const paymentIntentId = b.get('stripePaymentIntentId');
  if (b.get('status') === 'pending_payment' && b.get('paymentProvider') === 'stripe' && typeof paymentIntentId === 'string') {
    try {
      const pi = await stripe().paymentIntents.retrieve(paymentIntentId);
      if (pi.status === 'succeeded') {
        const chargeId = typeof pi.latest_charge === 'string' ? pi.latest_charge : pi.latest_charge?.id ?? null;
        await settlePayment(ref.id, { paymentIntentId: pi.id, chargeId });
        return { bookingId: ref.id, status: (await ref.get()).get('status') };
      }
      if (pi.status === 'processing') return { bookingId: ref.id, status: 'pending_payment' };
    } catch (e: any) {
      // Not read: release anyway; a payment that did go through comes back
      // by the webhook's late-payment path (settlePayment).
      functions.logger.warn('releaseBookingHold: PaymentIntent not read', { bookingId: ref.id, code: e?.code ?? String(e) });
    }
  }
  await expireHold(ref);
  return { bookingId: ref.id, status: (await ref.get()).get('status') };
});

function bookingIdOf(data: any): string {
  const bookingId = data?.bookingId;
  if (typeof bookingId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(bookingId)) {
    throw new functions.https.HttpsError('invalid-argument', 'A booking id is required.');
  }
  return bookingId;
}

/**
 * `pending_payment` → `expired`, half hours freed, and the PaymentIntent
 * cancelled so it can no longer be paid. With `dueBy`, only a hold whose 15
 * minutes are over by then. A PaymentIntent that succeeded in the meantime
 * cannot be cancelled; its webhook then re-locks the time (settlePayment).
 */
async function expireHold(ref: FirebaseFirestore.DocumentReference, dueBy?: number): Promise<boolean> {
  const db = admin.firestore();
  const expired = await db.runTransaction(async (tx) => {
    const b = await tx.get(ref);
    if (b.get('status') !== 'pending_payment') return null;
    if (dueBy !== undefined && b.get('expiresAt').toMillis() > dueBy) return null;
    for (const c of cellsOf(b.get('startAt').toMillis(), b.get('durationMinutes'))) tx.delete(slotRef(b.get('instructorUid'), c));
    tx.update(ref, { status: 'expired', expiresAt: FieldValue.delete(), updatedAt: Timestamp.now() });
    return { paymentIntentId: (b.get('stripePaymentIntentId') ?? null) as string | null };
  });
  if (expired?.paymentIntentId) {
    try {
      await stripe().paymentIntents.cancel(expired.paymentIntentId, {}, { idempotencyKey: `booking-pi-cancel-${ref.id}` });
    } catch (e: any) {
      functions.logger.warn('expireHold: PaymentIntent not cancelled', { bookingId: ref.id, code: e?.code ?? String(e) });
    }
  }
  return expired !== null;
}

/**
 * `pending_payment` → `confirmed` without a payment record: the emulator
 * gateway and tests. Stripe's webhook calls settlePayment. False when the
 * booking was no longer pending (a redelivery, or expired).
 */
export async function confirmBooking(bookingId: string): Promise<boolean> {
  return (await settlePayment(bookingId)) === 'confirmed';
}

export type SettleOutcome = 'confirmed' | 'duplicate' | 'not-pending' | 'slot-taken';

export interface SettleOptions {
  /** processedWebhooks/stripe_<event.id>: checked and written in the same transaction. */
  dedupe?: FirebaseFirestore.DocumentReference;
  paymentIntentId?: string;
  chargeId?: string | null;
}

/**
 * A booking was paid (plan v2 §9.2 step 2, §9.3). Confirms it, unlocks the
 * pair's contacts (§10, creating the conversation when they never wrote) and
 * tells the instructor.
 *
 * Paid in the last second of an `expired` hold: the half hours are locked
 * again if they are still free; if one was taken meanwhile the booking is
 * refunded automatically and the student told.
 *
 * With `dedupe`, a redelivered webhook changes nothing and pushes nothing.
 */
export async function settlePayment(bookingId: string, opts: SettleOptions = {}): Promise<SettleOutcome> {
  const db = admin.firestore();
  const ref = db.collection('bookings').doc(bookingId);
  const result = await db.runTransaction(async (tx): Promise<{ outcome: SettleOutcome; b?: FirebaseFirestore.DocumentSnapshot }> => {
    if (opts.dedupe && (await tx.get(opts.dedupe)).exists) return { outcome: 'duplicate' };
    const b = await tx.get(ref);
    const markProcessed = () => {
      if (opts.dedupe) tx.create(opts.dedupe, { bookingId, processedAt: Timestamp.now() });
    };
    const status = b.get('status');
    const knownIntent = b.get('stripePaymentIntentId');
    const sameIntent = !opts.paymentIntentId || !knownIntent || knownIntent === opts.paymentIntentId;
    const late = status === 'expired' && opts.paymentIntentId !== undefined;
    if (!b.exists || !sameIntent || (status !== 'pending_payment' && !late)) {
      markProcessed();
      return { outcome: 'not-pending' };
    }

    const studentUid: string = b.get('studentUid');
    const instructorUid: string = b.get('instructorUid');
    const startMs: number = b.get('startAt').toMillis();
    const cells = cellsOf(startMs, b.get('durationMinutes'));
    const convRef = db.collection('conversations').doc(`${studentUid}_${instructorUid}`);
    // Every read before any write (Firestore transactions).
    const slots = late ? await tx.getAll(...cells.map((c) => slotRef(instructorUid, c))) : [];
    const [conv, instructor] = await Promise.all([tx.get(convRef), tx.get(db.collection('instructors').doc(instructorUid))]);
    const now = Timestamp.now();
    const payment = {
      ...(opts.paymentIntentId ? { stripePaymentIntentId: opts.paymentIntentId } : {}),
      ...(opts.chargeId ? { stripeChargeId: opts.chargeId } : {}),
      paidAt: now,
    };
    markProcessed();

    if (late && slots.some((s) => s.exists)) {
      tx.update(ref, {
        ...payment,
        status: 'refunded',
        cancelledBy: 'system',
        cancelReason: 'slot-taken',
        cancelledAt: now,
        refundStatus: 'pending',
        refundDueAt: now,
        updatedAt: now,
      });
      return { outcome: 'slot-taken', b };
    }
    if (late) {
      for (const c of cells) tx.create(slotRef(instructorUid, c), { instructorUid, bookingId, startAt: Timestamp.fromMillis(c) });
    }
    tx.update(ref, {
      ...payment,
      status: 'confirmed',
      expiresAt: FieldValue.delete(),
      completeAfter: Timestamp.fromMillis(startMs + b.get('durationMinutes') * 60000),
      confirmedAt: now,
      updatedAt: now,
    });
    if (conv.exists) {
      tx.update(convRef, { contactUnlocked: true });
    } else {
      // The same fields sendMessage creates, with no message yet.
      tx.create(convRef, {
        studentUid,
        instructorUid,
        participantUids: [studentUid, instructorUid],
        instructorName: instructor.get('name') ?? b.get('instructorName') ?? '',
        instructorPhotoPath: instructor.get('photoApproved') === true ? instructor.get('photoPath') ?? null : null,
        instructorKind: instructor.get('kind') ?? null,
        studentDisplayName: b.get('studentDisplayName') ?? '',
        contactUnlocked: true,
        lastMessageText: '',
        lastMessageAt: now,
        lastMessageSender: null,
        studentUnread: 0,
        instructorUnread: 0,
        createdAt: now,
      });
    }
    return { outcome: 'confirmed', b };
  });

  // After the commit, so a retried transaction cannot push twice.
  if (result.outcome === 'confirmed') {
    await sendPushToUser(result.b!.get('instructorUid'), 'booking_new', `booking/${bookingId}`, pushVars(result.b!, 'studentDisplayName'));
  } else if (result.outcome === 'slot-taken') {
    functions.logger.warn('settlePayment: paid after the hold expired and the time was taken; refunding', { bookingId });
    await processRefund(bookingId);
  }
  return result.outcome;
}

/**
 * Returns a Stripe payment in full (owner decision, P9: a free cancel refunds
 * the service fee too; Stripe keeps its own processing fee). Money already
 * transferred to the school is reversed first (plan v2 §9.2 step 5).
 *
 * Runs only for a booking whose transaction set `refundDueAt`; on success it
 * is cleared and the student told «Возврат оформлен». A failure leaves it
 * set, so releaseInstructorPayouts retries with the same idempotency keys.
 * Never throws.
 */
export async function processRefund(bookingId: string): Promise<boolean> {
  const ref = admin.firestore().collection('bookings').doc(bookingId);
  const b = await ref.get();
  if (!b.exists || !b.get('refundDueAt')) return false;
  const paymentIntentId: string | undefined = b.get('stripePaymentIntentId');
  try {
    if (!paymentIntentId) throw new Error('no PaymentIntent on the booking');
    const transferId: string | undefined = b.get('stripeTransferId');
    if (transferId && !b.get('stripeTransferReversalId')) {
      const reversal = await stripe().transfers.createReversal(transferId, { metadata: { bookingId } }, { idempotencyKey: `booking-reversal-${bookingId}` });
      await ref.update({ stripeTransferReversalId: reversal.id });
    }
    let refundId: string | null = null;
    try {
      const refund = await stripe().refunds.create({ payment_intent: paymentIntentId, metadata: { bookingId } }, { idempotencyKey: `booking-refund-${bookingId}` });
      refundId = refund.id;
    } catch (e: any) {
      if (e?.code !== 'charge_already_refunded') throw e;
    }
    const at = Timestamp.now();
    await ref.update({ refundStatus: 'succeeded', stripeRefundId: refundId, refundedAt: at, refundDueAt: FieldValue.delete(), updatedAt: at });
  } catch (e: any) {
    functions.logger.error('processRefund failed; the hourly job retries', { bookingId, code: e?.code ?? String(e) });
    await ref.update({ refundStatus: 'failed', refundAttempts: FieldValue.increment(1), refundLastError: String(e?.code ?? e?.message ?? e).slice(0, 200) })
      .catch(() => undefined);
    return false;
  }
  await sendPushToUser(b.get('studentUid'), 'booking_refunded', `booking/${bookingId}`, pushVars(b, 'instructorName'));
  return true;
}

/** `{name}` and `{time}` for a booking push, in the reader's language. */
function pushVars(b: FirebaseFirestore.DocumentSnapshot, nameField: 'studentDisplayName' | 'instructorName') {
  return (lang: Lang) => ({
    name: b.get(nameField) || '—',
    time: new Intl.DateTimeFormat(lang === 'en' ? 'en-US' : lang, {
      timeZone: b.get('timezone'), weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit',
    }).format(b.get('startAt').toDate()),
  });
}

/**
 * Cancels a confirmed lesson (plan v2 §9.3). The student: 24 h or more
 * before the start → `refunded`, later → `late_cancelled` (no refund, the
 * time stays blocked, the school is paid 48 h after the start). The
 * instructor: always `refunded`. A refund frees the half hours; a Stripe
 * payment is returned in full (processRefund, marked due inside this
 * transaction so a failed refund is retried). The other side gets a push.
 */
export const cancelBooking = functions.runWith({ secrets: STRIPE_SECRETS }).https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const bookingId = bookingIdOf(data);
  const db = admin.firestore();
  const ref = db.collection('bookings').doc(bookingId);
  const result = await db.runTransaction(async (tx) => {
    const b = await tx.get(ref);
    const byStudent = b.get('studentUid') === uid;
    if (!b.exists || (!byStudent && b.get('instructorUid') !== uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not your booking.');
    }
    const startMs: number = b.get('startAt').toMillis();
    const now = Date.now();
    if (b.get('status') !== 'confirmed' || startMs <= now) {
      throw new functions.https.HttpsError('failed-precondition', 'not-cancellable');
    }
    const status = byStudent && startMs - now < FREE_CANCEL_MS ? 'late_cancelled' : 'refunded';
    if (status === 'refunded') {
      for (const c of cellsOf(startMs, b.get('durationMinutes'))) tx.delete(slotRef(b.get('instructorUid'), c));
    }
    const at = Timestamp.now();
    const paidByStripe = typeof b.get('stripePaymentIntentId') === 'string' && b.get('paymentProvider') === 'stripe';
    tx.update(ref, {
      status,
      cancelledBy: byStudent ? 'student' : 'instructor',
      cancelledAt: at,
      completeAfter: FieldValue.delete(),
      ...(status === 'refunded' && paidByStripe ? { refundStatus: 'pending', refundDueAt: at } : {}),
      ...(status === 'late_cancelled' ? { payoutReleaseAt: Timestamp.fromMillis(startMs + PAYOUT_HOLD_MS) } : {}),
      updatedAt: at,
    });
    return { b, status, byStudent, refund: status === 'refunded' && paidByStripe };
  });
  const { b, status, byStudent, refund } = result;
  await (byStudent
    ? sendPushToUser(b.get('instructorUid'), 'booking_cancelled_student', `booking/${bookingId}`, pushVars(b, 'studentDisplayName'))
    : sendPushToUser(b.get('studentUid'), 'booking_cancelled_instructor', `booking/${bookingId}`, pushVars(b, 'instructorName')));
  if (refund) await processRefund(bookingId);
  return { bookingId, status };
});

// ── Schedulers (cursor-paginated, risk #25) ──────────────────────────────────

/** `pending_payment` past its 15 minutes → `expired`, half hours freed. */
export async function runExpirePendingBookings(nowMs = Date.now()): Promise<SweepResult> {
  const db = admin.firestore();
  return sweepPaginated({
    label: 'expirePendingBookings',
    baseQuery: db.collection('bookings').where('expiresAt', '<=', Timestamp.fromMillis(nowMs)).orderBy('expiresAt'),
    deadline: Date.now() + SWEEP_TIME_BUDGET_MS,
    handle: async (doc) => { await expireHold(doc.ref, nowMs); },
  });
}

/**
 * `confirmed` whose end has passed → `completed`, due for payout 48 h after
 * the end (`payoutReleaseAt`, releaseInstructorPayouts), and the student is asked
 * for a review (plan v2 §12) — unless they already reviewed this school
 * (owner, 2026-10-07: a weekly student isn't asked every week).
 */
export async function runMarkBookingsCompleted(nowMs = Date.now()): Promise<SweepResult> {
  const db = admin.firestore();
  return sweepPaginated({
    label: 'markBookingsCompleted',
    baseQuery: db.collection('bookings').where('completeAfter', '<=', Timestamp.fromMillis(nowMs)).orderBy('completeAfter'),
    deadline: Date.now() + SWEEP_TIME_BUDGET_MS,
    handle: async (doc) => {
      const b = await db.runTransaction(async (tx) => {
        const snap = await tx.get(doc.ref);
        if (snap.get('status') !== 'confirmed') return null;
        const at = Timestamp.now();
        tx.update(doc.ref, {
          status: 'completed',
          completeAfter: FieldValue.delete(),
          payoutReleaseAt: Timestamp.fromMillis(snap.get('completeAfter').toMillis() + PAYOUT_HOLD_MS),
          completedAt: at,
          updatedAt: at,
        });
        return snap;
      });
      // After the commit, so a retried transaction cannot push twice.
      if (!b) return;
      const studentUid: string = b.get('studentUid');
      const reviewed = await db.collection('instructors').doc(b.get('instructorUid')).collection('reviews').doc(studentUid).get();
      if (!reviewed.exists) {
        await sendPushToUser(studentUid, 'review_request', `booking/${doc.id}`, () => ({ name: b.get('instructorName') || '—' }));
      }
    },
  });
}

export const expirePendingBookings = functions
  .runWith({ timeoutSeconds: 540, memory: '256MB', secrets: STRIPE_SECRETS })
  .pubsub.schedule('every 5 minutes').timeZone('America/Chicago')
  .onRun(async () => { await runExpirePendingBookings(); });

export const markBookingsCompleted = functions
  .runWith({ timeoutSeconds: 540, memory: '256MB' })
  .pubsub.schedule('every 15 minutes').timeZone('America/Chicago')
  .onRun(async () => { await runMarkBookingsCompleted(); });

// ── Account deletion (plan v2 §9.4) ──────────────────────────────────────────

/**
 * Upcoming confirmed lessons on either side. deleteUserAccount refuses while
 * there are any: «У вас N предстоящих уроков — отмените их перед удалением».
 */
export async function upcomingBookingCount(db: FirebaseFirestore.Firestore, uid: string, nowMs = Date.now()): Promise<number> {
  const sides = await Promise.all(['studentUid', 'instructorUid'].map((f) => db.collection('bookings').where(f, '==', uid).get()));
  return sides.flatMap((s) => s.docs)
    .filter((d) => d.get('status') === 'confirmed' && d.get('startAt').toMillis() > nowMs).length;
}

/**
 * Money still open on either side (plan v2 §9.4, P9): a no-show report or a
 * card dispute not resolved yet, and — for the instructor — a held lesson not
 * paid out yet (`payoutReleaseAt` is set until releaseInstructorPayouts
 * transfers it). deleteUserAccount refuses while there are any.
 */
export async function unsettledBookingCount(db: FirebaseFirestore.Firestore, uid: string): Promise<number> {
  const [asStudent, asInstructor] = await Promise.all(['studentUid', 'instructorUid'].map((f) => db.collection('bookings').where(f, '==', uid).get()));
  const disputed = (d: FirebaseFirestore.QueryDocumentSnapshot) => d.get('status') === 'disputed' || d.get('disputeStatus') === 'open';
  return asStudent.docs.filter(disputed).length
    + asInstructor.docs.filter((d) => disputed(d) || d.get('payoutReleaseAt') != null).length;
}
