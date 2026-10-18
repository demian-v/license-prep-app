/**
 * Instructors plan v2 §9.2–§9.4 (P9) — Stripe Connect with a fake client:
 * no request leaves jest. The PaymentIntent, the holds cap, the webhook
 * (signature, dedupe, the payment that arrives after its hold expired),
 * refunds and their retry, payout release, no-show reports, disputes,
 * payouts onboarding, and the deletion blockers.
 */
import Stripe from 'stripe';
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { setPaymentGateway, slotKey, runExpirePendingBookings, runMarkBookingsCompleted, unsettledBookingCount, PAYOUT_HOLD_MS } from '../bookings';
import { runReleaseInstructorPayouts, runRetryRefunds, runCloseConnectedAccounts, applyAccountState } from '../payments';
import { setStripeClient, stripeConfigured } from '../stripe-client';
import { setPushTransport } from '../push';
import { wallClock, wallToUtc, addDays } from '../zone';

const db = () => admin.firestore();
const TZ = 'America/Chicago';
const STUDENT = 'pay-student';
const STUDENT2 = 'pay-student2';
const SCHOOL = 'pay-school';
const PRIVATE = 'pay-private';
const ACCT = 'acct_test_school';
const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' }, auth_time: Math.floor(Date.now() / 1000) } } });
const call = (fn: any) => (data: unknown, uid: string) => testEnv.wrap(fn)(data as any, ctx(uid) as any);
const book = call(fns.createBooking);
const cancel = call(fns.cancelBooking);
const releaseHold = call(fns.releaseBookingHold);
const noShow = call(fns.reportNoShow);
const startPayouts = call(fns.startInstructorPayouts);
const payoutsState = call(fns.getInstructorPayouts);
const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const inDays = (d: number) => ts(Date.now() + d * 864e5);
const allDay = Object.fromEntries(['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].map((d) => [d, [{ start: '06:00', end: '22:00' }]]));
const tenAm = (days: number) => wallToUtc(addDays(wallClock(Date.now(), TZ).date, days), 600, TZ)!;
const bookingRef = (id: string) => db().collection('bookings').doc(id);
const slot = (ms: number) => db().collection('bookingSlots').doc(`${SCHOOL}_${slotKey(ms)}`);

// ── The fake Stripe client ───────────────────────────────────────────────────

type Call = { params: any; options?: any; id?: string };
let calls: Record<string, Call[]> = {};
let failNext: Record<string, any> = {};
let account: Record<string, unknown> = {};
/** What paymentIntents.retrieve reports (the sheet's own result can be wrong). */
let piStatus = 'requires_payment_method';
/** A v2 account's recipient capabilities, as `include: ['configuration.recipient']` returns them. */
const recipient = (transfers: string, payouts = transfers) => ({
  recipient: { applied: true, capabilities: { stripe_balance: { stripe_transfers: { status: transfers, status_details: [] }, payouts: { status: payouts, status_details: [] } } } },
});

function record(name: string, c: Call) {
  (calls[name] ??= []).push(c);
  if (failNext[name]) {
    const e = failNext[name];
    delete failNext[name];
    throw e;
  }
}

const fake = {
  paymentIntents: {
    async create(params: any, options: any) {
      record('paymentIntents.create', { params, options });
      return { id: `pi_${params.metadata.bookingId}`, client_secret: `pi_${params.metadata.bookingId}_secret_test` };
    },
    async retrieve(id: string) {
      record('paymentIntents.retrieve', { params: null, id });
      return { id, status: piStatus, latest_charge: `ch_${id.slice(3)}` };
    },
    async cancel(id: string, params: any, options: any) {
      record('paymentIntents.cancel', { id, params, options });
      return { id, status: 'canceled' };
    },
  },
  refunds: {
    async create(params: any, options: any) {
      record('refunds.create', { params, options });
      return { id: 're_test' };
    },
  },
  transfers: {
    async create(params: any, options: any) {
      record('transfers.create', { params, options });
      return { id: `tr_${params.metadata.bookingId}` };
    },
    async createReversal(id: string, params: any, options: any) {
      record('transfers.createReversal', { id, params, options });
      return { id: 'trr_test' };
    },
  },
  accounts: {
    async update(id: string, params: any, options: any) {
      record('accounts.update', { id, params, options });
      return { id };
    },
  },
  v2: {
    core: {
      accounts: {
        async create(params: any, options: any) {
          record('v2.accounts.create', { params, options });
          return { id: ACCT, metadata: params.metadata };
        },
        async retrieve(id: string, params: any) {
          record('v2.accounts.retrieve', { id, params });
          return { id, ...account };
        },
        async close(id: string, params: any) {
          record('v2.accounts.close', { id, params });
          return { id, closed: true };
        },
      },
      accountLinks: {
        async create(params: any) {
          record('v2.accountLinks.create', { params });
          return { url: 'https://connect.stripe.com/setup/e/test_link' };
        },
      },
    },
  },
};

/** A signed webhook delivery, through the real HTTPS handler. */
async function deliver(event: Record<string, unknown>, secret = 'whsec_test_platform_dummy', signature?: string) {
  const payload = JSON.stringify({ object: 'event', livemode: false, ...event });
  const header = signature ?? Stripe.webhooks.generateTestHeaderString({ payload, secret });
  const out: { status?: number; body?: unknown } = {};
  const res: any = {
    status(code: number) { out.status = code; return res; },
    json(body: unknown) { out.body = body; return res; },
    send(body: unknown) { out.body = body; return res; },
  };
  const req: any = { method: 'POST', rawBody: Buffer.from(payload), header: (n: string) => (n.toLowerCase() === 'stripe-signature' ? header : undefined) };
  await (fns.stripeWebhook as any)(req, res);
  return out;
}

const paid = (bookingId: string, id = `evt_paid_${bookingId}`) => ({
  id, type: 'payment_intent.succeeded',
  data: { object: { id: `pi_${bookingId}`, object: 'payment_intent', latest_charge: `ch_${bookingId}`, metadata: { bookingId } } },
});

// ── Fixtures ─────────────────────────────────────────────────────────────────

const school = (over: Record<string, unknown> = {}) => ({
  kind: 'school', name: 'Lakeview Driving School', state: 'ZP', listed: true, status: 'active', stage: 2, payoutsEnabled: true,
  timezone: TZ, hourlyRateCents: 6000, lessonDurations: [60, 90], availability: allDay, schoolAddress: '1 Lake St', ...over,
});

let pushes: { token: string; title?: string; body?: string; route?: string }[] = [];

async function wipe() {
  for (const coll of ['bookings', 'bookingSlots']) {
    const snap = await db().collection(coll).get();
    await Promise.all(snap.docs.filter((d) => {
      const x = d.data();
      return [x.studentUid, x.instructorUid].some((u) => typeof u === 'string' && (u.startsWith('pay-') || u.startsWith('deleted_pay-')));
    }).map((d) => d.ref.delete()));
  }
  for (const coll of ['processedWebhooks', 'stripeAccountClosures', 'webhookDeadLetter']) {
    const snap = await db().collection(coll).get();
    await Promise.all(snap.docs.filter((d) => /evt_|acct_test|stripe_/.test(d.id)).map((d) => d.ref.delete()));
  }
  for (const id of [`${STUDENT}_${SCHOOL}`, `${STUDENT2}_${SCHOOL}`]) await db().collection('conversations').doc(id).delete();
}

beforeAll(async () => {
  for (const [id, uid] of [['pay-sub1', STUDENT], ['pay-sub2', STUDENT2]] as const) {
    await db().collection('subscriptions').doc(id).set({ userId: uid, isActive: true, planType: 'monthly', nextBillingDate: inDays(20) });
  }
  await db().collection('config').doc('instructors').set({ launchStates: ['ZP'] });
  await db().collection('users').doc(STUDENT).set({ name: 'Anna Kowalska', language: 'en' });
  await db().collection('users').doc(STUDENT2).set({ name: 'Ben Ortiz', language: 'en' });
  await db().collection('users').doc(SCHOOL).set({ name: 'Lakeview', userType: 'instructor', language: 'ru' });
  await db().collection('users').doc(SCHOOL).collection('fcmTokens').doc('t').set({ token: 'tok-school', platform: 'ios' });
  await db().collection('users').doc(STUDENT).collection('fcmTokens').doc('t').set({ token: 'tok-student', platform: 'ios' });
});

beforeEach(async () => {
  await wipe();
  calls = {};
  failNext = {};
  account = {};
  piStatus = 'requires_payment_method';
  pushes = [];
  setPushTransport({
    async send(messages) {
      pushes.push(...messages.map((m) => ({ token: m.token, ...m.notification, route: m.data?.route })));
      return messages.map(() => null);
    },
  });
  // The default gateway: Stripe, because a client is configured.
  setPaymentGateway(undefined);
  setStripeClient(fake);
  await db().collection('instructors').doc(SCHOOL).set(school());
  await db().collection('instructorPrivate').doc(SCHOOL).set({ contactEmail: 'school@example.com', stripeAccountId: ACCT, stripePendingAccountId: ACCT });
  await db().collection('instructors').doc(PRIVATE).set(school({ kind: 'schoolInstructor', name: 'Maria', stage: 1, payoutsEnabled: false }));
  await db().collection('instructorPrivate').doc(PRIVATE).set({ stripeAccountId: null, stripePendingAccountId: null });
});

afterAll(async () => {
  await wipe();
  setPushTransport(null);
  setStripeClient(null);
  setPaymentGateway(undefined);
  testEnv.cleanup();
});

/** A Stripe booking paid through the webhook: the student's view after the PaymentSheet. */
async function paidBooking(days = 3, uid = STUDENT) {
  const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(days), durationMinutes: 60 }, uid);
  expect((await deliver(paid(res.bookingId))).status).toBe(200);
  return res.bookingId as string;
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('the Stripe gateway (plan v2 §9.2 step 1)', () => {
  it('holds the time and returns what the PaymentSheet needs; the PaymentIntent is on the platform with the booking as transfer group', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    expect(res).toMatchObject({
      status: 'pending_payment', totalCents: 7500, feeKind: 'first',
      payment: { clientSecret: `pi_${res.bookingId}_secret_test`, publishableKey: 'pk_test_dummy' },
    });
    expect(calls['paymentIntents.create']).toEqual([{
      params: { amount: 7500, currency: 'usd', payment_method_types: ['card'], transfer_group: res.bookingId, description: 'Driving lesson', metadata: { bookingId: res.bookingId } },
      options: { idempotencyKey: `booking-pi-${res.bookingId}` },
    }]);
    const b = (await bookingRef(res.bookingId).get()).data()!;
    expect(b).toMatchObject({ status: 'pending_payment', paymentProvider: 'stripe', stripePaymentIntentId: `pi_${res.bookingId}` });
    expect(JSON.stringify(b)).not.toContain('secret');
    expect((await slot(tenAm(3)).get()).exists).toBe(true);
    expect(pushes).toEqual([]);
  });

  it('a student may hold two unpaid lessons at once, not three; an expired hold no longer counts', async () => {
    const a: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    await book({ instructorUid: SCHOOL, startAtMs: tenAm(4), durationMinutes: 60 }, STUDENT);
    await expect(book({ instructorUid: SCHOOL, startAtMs: tenAm(5), durationMinutes: 60 }, STUDENT))
      .rejects.toMatchObject({ code: 'resource-exhausted', message: 'too-many-holds' });
    expect((await slot(tenAm(5)).get()).exists).toBe(false);
    // Another student is not affected.
    await book({ instructorUid: SCHOOL, startAtMs: tenAm(6), durationMinutes: 60 }, STUDENT2);
    await bookingRef(a.bookingId).update({ expiresAt: ts(Date.now() - 1000) });
    await book({ instructorUid: SCHOOL, startAtMs: tenAm(5), durationMinutes: 60 }, STUDENT);
  });

  it('a PaymentIntent that cannot be created gives the time back at once', async () => {
    failNext['paymentIntents.create'] = Object.assign(new Error('api down'), { code: 'api_error' });
    await expect(book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT))
      .rejects.toMatchObject({ code: 'unavailable', message: 'payment-start-failed' });
    expect((await slot(tenAm(3)).get()).exists).toBe(false);
    const mine = await db().collection('bookings').where('studentUid', '==', STUDENT).get();
    expect(mine.docs.map((d) => d.get('status'))).toEqual(['expired']);
  });

  it('closing the PaymentSheet releases the hold and cancels the PaymentIntent; only the student can', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    await expect(releaseHold({ bookingId: res.bookingId }, STUDENT2)).rejects.toMatchObject({ code: 'permission-denied' });
    expect(await releaseHold({ bookingId: res.bookingId }, STUDENT)).toEqual({ bookingId: res.bookingId, status: 'expired' });
    expect((await slot(tenAm(3)).get()).exists).toBe(false);
    expect(calls['paymentIntents.cancel']).toEqual([{ id: `pi_${res.bookingId}`, params: {}, options: { idempotencyKey: `booking-pi-cancel-${res.bookingId}` } }]);
    // A second release changes nothing.
    expect(await releaseHold({ bookingId: res.bookingId }, STUDENT)).toMatchObject({ status: 'expired' });
    expect(calls['paymentIntents.cancel']).toHaveLength(1);
  });

  it('a sheet that reported a failure for a payment that went through: the release confirms it instead, and the webhook later changes nothing', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    piStatus = 'succeeded';
    expect(await releaseHold({ bookingId: res.bookingId }, STUDENT)).toEqual({ bookingId: res.bookingId, status: 'confirmed' });
    expect((await bookingRef(res.bookingId).get()).data()).toMatchObject({ status: 'confirmed', stripeChargeId: `ch_${res.bookingId}` });
    expect((await slot(tenAm(3)).get()).exists).toBe(true);
    expect(calls['paymentIntents.cancel']).toBeUndefined();
    expect(pushes.filter((p) => p.token === 'tok-school')).toHaveLength(1);
    expect((await deliver(paid(res.bookingId))).status).toBe(200);
    expect(pushes.filter((p) => p.token === 'tok-school')).toHaveLength(1);
  });

  it('a payment still processing keeps the hold for the webhook', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    piStatus = 'processing';
    expect(await releaseHold({ bookingId: res.bookingId }, STUDENT)).toEqual({ bookingId: res.bookingId, status: 'pending_payment' });
    expect((await slot(tenAm(3)).get()).exists).toBe(true);
    expect(calls['paymentIntents.cancel']).toBeUndefined();
  });

  it('the expiry sweep cancels the PaymentIntent of a dead hold', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    await bookingRef(res.bookingId).update({ expiresAt: ts(Date.now() - 1000) });
    await runExpirePendingBookings();
    expect((await bookingRef(res.bookingId).get()).get('status')).toBe('expired');
    expect(calls['paymentIntents.cancel']?.map((c) => c.id)).toEqual([`pi_${res.bookingId}`]);
  });

  it('a live key is never used on the emulator', () => {
    setStripeClient(null);
    const was = { key: process.env.STRIPE_SECRET_KEY, emu: process.env.FUNCTIONS_EMULATOR };
    try {
      process.env.FUNCTIONS_EMULATOR = 'true';
      process.env.STRIPE_SECRET_KEY = 'sk_live_not_a_real_key';
      expect(stripeConfigured()).toBe(false);
      process.env.STRIPE_SECRET_KEY = 'sk_test_not_a_real_key';
      expect(stripeConfigured()).toBe(true);
      delete process.env.STRIPE_SECRET_KEY;
      expect(stripeConfigured()).toBe(false);
    } finally {
      if (was.key === undefined) delete process.env.STRIPE_SECRET_KEY; else process.env.STRIPE_SECRET_KEY = was.key;
      if (was.emu === undefined) delete process.env.FUNCTIONS_EMULATOR; else process.env.FUNCTIONS_EMULATOR = was.emu;
    }
  });
});

describe('stripeWebhook (plan v2 §9.3)', () => {
  it('refuses a bad, missing or replayed (older than 5 minutes) signature and changes nothing', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    expect((await deliver(paid(res.bookingId), 'whsec_wrong')).status).toBe(400);
    expect((await deliver(paid(res.bookingId), undefined, '')).status).toBe(400);
    const old = JSON.stringify({ object: 'event', livemode: false, ...paid(res.bookingId) });
    const stale = Stripe.webhooks.generateTestHeaderString({ payload: old, secret: 'whsec_test_platform_dummy', timestamp: Math.floor(Date.now() / 1000) - 600 });
    expect((await deliver(paid(res.bookingId), undefined, stale)).status).toBe(400);
    expect((await bookingRef(res.bookingId).get()).get('status')).toBe('pending_payment');
  });

  it('payment_intent.succeeded confirms, keeps the charge, unlocks contacts and tells the school — once, however often it arrives', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    expect(await deliver(paid(res.bookingId))).toEqual({ status: 200, body: { received: true } });
    // The connected-accounts endpoint's secret is accepted too; a redelivery does nothing.
    expect((await deliver(paid(res.bookingId), 'whsec_test_connect_dummy')).status).toBe(200);
    const b = (await bookingRef(res.bookingId).get()).data()!;
    expect(b).toMatchObject({ status: 'confirmed', stripeChargeId: `ch_${res.bookingId}`, stripePaymentIntentId: `pi_${res.bookingId}` });
    expect(b.expiresAt).toBeUndefined();
    expect((await db().collection('conversations').doc(`${STUDENT}_${SCHOOL}`).get()).get('contactUnlocked')).toBe(true);
    expect((await db().collection('processedWebhooks').doc(`stripe_evt_paid_${res.bookingId}`).get()).exists).toBe(true);
    expect(pushes.filter((p) => p.title === 'Новая бронь')).toHaveLength(1);
  });

  it('paid in the last second of an expired hold: the time is locked again when still free', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    await bookingRef(res.bookingId).update({ expiresAt: ts(Date.now() - 1000) });
    await runExpirePendingBookings();
    await deliver(paid(res.bookingId));
    expect((await bookingRef(res.bookingId).get()).get('status')).toBe('confirmed');
    expect((await slot(tenAm(3)).get()).get('bookingId')).toBe(res.bookingId);
    expect(calls['refunds.create']).toBeUndefined();
  });

  it('paid after its hold expired and the time was taken meanwhile: refunded in full, the student told', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    await bookingRef(res.bookingId).update({ expiresAt: ts(Date.now() - 1000) });
    await runExpirePendingBookings();
    const other = await paidBooking(3, STUDENT2);
    await deliver(paid(res.bookingId));
    const b = (await bookingRef(res.bookingId).get()).data()!;
    expect(b).toMatchObject({ status: 'refunded', cancelledBy: 'system', cancelReason: 'slot-taken', refundStatus: 'succeeded', stripeRefundId: 're_test' });
    expect(b.refundDueAt).toBeUndefined();
    expect((await slot(tenAm(3)).get()).get('bookingId')).toBe(other);
    expect(calls['refunds.create']).toEqual([{ params: { payment_intent: `pi_${res.bookingId}`, metadata: { bookingId: res.bookingId } }, options: { idempotencyKey: `booking-refund-${res.bookingId}` } }]);
    expect(pushes).toContainEqual(expect.objectContaining({ token: 'tok-student', title: 'Refund issued', route: `booking/${res.bookingId}` }));
  });

  it('ignores a payment for another PaymentIntent than the booking’s and an unknown event type', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    const wrong = paid(res.bookingId, 'evt_wrong');
    (wrong.data.object as any).id = 'pi_someone_else';
    expect((await deliver(wrong)).status).toBe(200);
    expect((await deliver({ id: 'evt_other', type: 'customer.created', data: { object: {} } })).status).toBe(200);
    expect((await bookingRef(res.bookingId).get()).get('status')).toBe('pending_payment');
  });

  it('a dispute holds the payout while open; won lets it go', async () => {
    const id = await paidBooking();
    const dispute = (status: string, eventId: string) => ({
      id: eventId, type: status === 'needs_response' ? 'charge.dispute.created' : 'charge.dispute.closed',
      data: { object: { id: 'dp_test', object: 'dispute', payment_intent: `pi_${id}`, charge: `ch_${id}`, status, reason: 'fraudulent', amount: 7500 } },
    });
    await deliver(dispute('needs_response', 'evt_dp1'));
    expect((await bookingRef(id).get()).data()).toMatchObject({ disputeStatus: 'open', stripeDisputeId: 'dp_test', disputeReason: 'fraudulent', disputeAmountCents: 7500 });
    await bookingRef(id).update({ status: 'completed', payoutReleaseAt: ts(Date.now() - 1000) });
    await runReleaseInstructorPayouts();
    expect((await bookingRef(id).get()).get('status')).toBe('completed');
    expect(await unsettledBookingCount(db(), STUDENT)).toBe(1);
    await deliver(dispute('won', 'evt_dp2'));
    await runReleaseInstructorPayouts();
    expect((await bookingRef(id).get()).get('status')).toBe('payout_released');
  });

  it('an inquiry closed without a chargeback lets the payout go; a lost or prevented one cancels it (the school is not paid, nothing blocks deletion)', async () => {
    const dispute = (id: string, status: string, eventId: string) => ({
      id: eventId, type: 'charge.dispute.closed',
      data: { object: { id: `dp_${id}`, object: 'dispute', payment_intent: `pi_${id}`, charge: `ch_${id}`, status, reason: 'fraudulent', amount: 7500 } },
    });
    const kept = await paidBooking(3);
    await bookingRef(kept).update({ status: 'completed', payoutReleaseAt: ts(Date.now() - 1000) });
    await deliver(dispute(kept, 'warning_closed', 'evt_dpk'));
    await runReleaseInstructorPayouts();
    expect((await bookingRef(kept).get()).get('status')).toBe('payout_released');
    for (const [days, status] of [[4, 'lost'], [5, 'prevented']] as const) {
      const id = await paidBooking(days);
      await bookingRef(id).update({ status: 'completed', payoutReleaseAt: ts(Date.now() - 1000) });
      await deliver(dispute(id, status, `evt_dp_${status}`));
      const b = (await bookingRef(id).get()).data()!;
      expect(b).toMatchObject({ status: 'completed', disputeStatus: status });
      expect(b.payoutReleaseAt).toBeUndefined();
      expect(b.payoutCancelledAt).toBeDefined();
    }
    await runReleaseInstructorPayouts();
    expect(calls['transfers.create']).toHaveLength(1);
    expect(await unsettledBookingCount(db(), SCHOOL)).toBe(0);
  });

  it('a failure is dead-lettered and Stripe asked to retry', async () => {
    const event = { id: 'evt_broken', type: 'payment_intent.succeeded', data: { object: { id: 'pi_x', metadata: { bookingId: 'has/slash' }, latest_charge: null } } };
    const out = await deliver(event);
    expect(out.status).toBe(500);
    const dl = await db().collection('webhookDeadLetter').doc('stripe_evt_broken').get();
    expect(dl.data()).toMatchObject({ source: 'stripe', notificationType: 'payment_intent.succeeded', attempts: 1, status: 'pending' });
  });
});

describe('refunds (plan v2 §9.2 step 5, §9.3)', () => {
  it('a free cancel returns the whole total, the fee included, and tells the student', async () => {
    const id = await paidBooking(3);
    expect(await cancel({ bookingId: id }, STUDENT)).toEqual({ bookingId: id, status: 'refunded' });
    expect(calls['refunds.create']?.map((c) => c.params)).toEqual([{ payment_intent: `pi_${id}`, metadata: { bookingId: id } }]);
    expect((await bookingRef(id).get()).data()).toMatchObject({ refundStatus: 'succeeded', stripeRefundId: 're_test' });
    expect(pushes).toContainEqual(expect.objectContaining({ token: 'tok-student', title: 'Refund issued' }));
  });

  it('a school cancel refunds too; a late cancel refunds nothing and pays the school 48 h after the start', async () => {
    const a = await paidBooking(3);
    await cancel({ bookingId: a }, SCHOOL);
    expect(calls['refunds.create']).toHaveLength(1);
    // A lesson 10 hours ahead (the 12 h lead is checked at booking, so move it).
    const b = await paidBooking(4);
    const start = Date.now() + 10 * 3600e3;
    await bookingRef(b).update({ startAt: ts(start) });
    expect(await cancel({ bookingId: b }, STUDENT)).toMatchObject({ status: 'late_cancelled' });
    expect(calls['refunds.create']).toHaveLength(1);
    expect((await bookingRef(b).get()).get('payoutReleaseAt').toMillis()).toBe(start + PAYOUT_HOLD_MS);
  });

  it('a refund Stripe refused stays due and the hourly job retries it with the same key', async () => {
    const id = await paidBooking(3);
    failNext['refunds.create'] = Object.assign(new Error('rate limited'), { code: 'rate_limit' });
    await cancel({ bookingId: id }, STUDENT);
    let b = (await bookingRef(id).get()).data()!;
    expect(b).toMatchObject({ status: 'refunded', refundStatus: 'failed', refundAttempts: 1 });
    expect(b.refundDueAt).toBeDefined();
    expect(pushes.some((p) => p.title === 'Refund issued')).toBe(false);
    await runRetryRefunds(Date.now() + 11 * 60000);
    b = (await bookingRef(id).get()).data()!;
    expect(b).toMatchObject({ refundStatus: 'succeeded' });
    expect(b.refundDueAt).toBeUndefined();
    expect(calls['refunds.create'].map((c) => c.options.idempotencyKey)).toEqual([`booking-refund-${id}`, `booking-refund-${id}`]);
  });

  it('after a transfer: the transfer is reversed first, then the charge refunded', async () => {
    const id = await paidBooking(3);
    await bookingRef(id).update({ stripeTransferId: 'tr_done', refundDueAt: ts(Date.now() - 3600e3), status: 'refunded' });
    await runRetryRefunds();
    expect(calls['transfers.createReversal']).toEqual([{ id: 'tr_done', params: { metadata: { bookingId: id } }, options: { idempotencyKey: `booking-reversal-${id}` } }]);
    expect(calls['refunds.create']).toHaveLength(1);
    expect((await bookingRef(id).get()).get('stripeTransferReversalId')).toBe('trr_test');
  });

  it('an emulator-paid booking has no money to return', async () => {
    setPaymentGateway({ provider: 'emulator', begin: async (id) => { await (await import('../bookings')).confirmBooking(id); } });
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    await cancel({ bookingId: res.bookingId }, STUDENT);
    expect(calls['refunds.create']).toBeUndefined();
    expect((await bookingRef(res.bookingId).get()).get('refundDueAt')).toBeUndefined();
  });
});

describe('payout release (plan v2 §9.2 steps 3–4)', () => {
  it('completion makes a lesson due 48 h after its end', async () => {
    const id = await paidBooking(3);
    const end = Date.now() - 60e3;
    await bookingRef(id).update({ completeAfter: ts(end) });
    await runMarkBookingsCompleted();
    expect((await bookingRef(id).get()).get('payoutReleaseAt').toMillis()).toBe(end + PAYOUT_HOLD_MS);
  });

  it('transfers the lesson price, tied to the charge, once due; not before; the fee stays', async () => {
    const due = await paidBooking(3);
    const early = await paidBooking(4);
    await bookingRef(due).update({ status: 'completed', payoutReleaseAt: ts(Date.now() - 1000) });
    await bookingRef(early).update({ status: 'completed', payoutReleaseAt: ts(Date.now() + 3600e3) });
    await runReleaseInstructorPayouts();
    expect(calls['transfers.create']).toEqual([{
      params: { amount: 6000, currency: 'usd', destination: ACCT, source_transaction: `ch_${due}`, transfer_group: due, metadata: { bookingId: due } },
      options: { idempotencyKey: `booking-transfer-${due}` },
    }]);
    const b = (await bookingRef(due).get()).data()!;
    expect(b).toMatchObject({ status: 'payout_released', stripeTransferId: `tr_${due}` });
    expect(b.payoutReleaseAt).toBeUndefined();
    expect((await bookingRef(early).get()).get('status')).toBe('completed');
    // A second run pays nothing twice.
    await runReleaseInstructorPayouts();
    expect(calls['transfers.create']).toHaveLength(1);
  });

  it('a late-cancelled lesson pays out after its start + 48 h, and stays a late cancel (not «held», not reviewable)', async () => {
    const id = await paidBooking(3);
    await bookingRef(id).update({ status: 'late_cancelled', payoutReleaseAt: ts(Date.now() - 1000) });
    await runReleaseInstructorPayouts();
    const b = (await bookingRef(id).get()).data()!;
    expect(b).toMatchObject({ status: 'late_cancelled', stripeTransferId: `tr_${id}` });
    expect(b.payoutReleasedAt).toBeDefined();
    expect(b.payoutReleaseAt).toBeUndefined();
    await expect(call(fns.submitReview)({ bookingId: id, rating: 5, comment: '' }, STUDENT))
      .rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('waits while the school has no connected account; an emulator-paid lesson is released without Stripe', async () => {
    const id = await paidBooking(3);
    await bookingRef(id).update({ status: 'completed', payoutReleaseAt: ts(Date.now() - 1000) });
    await db().collection('instructorPrivate').doc(SCHOOL).update({ stripeAccountId: null });
    await runReleaseInstructorPayouts();
    expect((await bookingRef(id).get()).get('status')).toBe('completed');
    await bookingRef(id).update({ paymentProvider: 'emulator' });
    await runReleaseInstructorPayouts();
    expect((await bookingRef(id).get()).data()).toMatchObject({ status: 'payout_released', stripeTransferId: null });
    expect(calls['transfers.create']).toBeUndefined();
  });
});

describe('reportNoShow (plan v2 §9.3)', () => {
  it('within 48 h of the end: completed → disputed, and the payout is held', async () => {
    const id = await paidBooking(3);
    const end = Date.now() - 3600e3;
    await bookingRef(id).update({ status: 'completed', startAt: ts(end - 3600e3), payoutReleaseAt: ts(Date.now() - 1000) });
    await expect(noShow({ bookingId: id }, STUDENT2)).rejects.toMatchObject({ code: 'permission-denied' });
    expect(await noShow({ bookingId: id, reason: 'instructor_no_show' }, STUDENT)).toEqual({ bookingId: id, status: 'disputed' });
    expect((await bookingRef(id).get()).data()).toMatchObject({ status: 'disputed', noShowReason: 'instructor_no_show' });
    await runReleaseInstructorPayouts();
    expect(calls['transfers.create']).toBeUndefined();
    expect(await unsettledBookingCount(db(), SCHOOL)).toBe(1);
  });

  it('refuses a lesson not held yet and one that ended more than 48 h ago', async () => {
    const id = await paidBooking(3);
    await expect(noShow({ bookingId: id }, STUDENT)).rejects.toMatchObject({ code: 'failed-precondition', message: 'not-reportable' });
    await bookingRef(id).update({ status: 'completed', startAt: ts(Date.now() - 50 * 3600e3) });
    await expect(noShow({ bookingId: id }, STUDENT)).rejects.toMatchObject({ message: 'not-reportable' });
  });
});

describe('payouts onboarding (plan v2 §9.2, §14.2)', () => {
  beforeEach(async () => {
    await db().collection('instructors').doc(SCHOOL).update({ payoutsEnabled: false, stage: 1 });
    await db().collection('instructorPrivate').doc(SCHOOL).set({ contactEmail: 'school@example.com', stripeAccountId: null, stripePendingAccountId: null });
  });

  it('creates the school’s v2 account once (recipient only, Express dashboard, weekly payouts) and returns a link; a retry reuses it', async () => {
    expect(await payoutsState({}, SCHOOL)).toEqual({ state: 'none' });
    expect(await startPayouts({}, SCHOOL)).toEqual({ url: 'https://connect.stripe.com/setup/e/test_link' });
    expect(calls['v2.accounts.create']).toEqual([{
      params: {
        contact_email: 'school@example.com', display_name: 'Lakeview Driving School',
        dashboard: 'express', identity: { country: 'us' },
        defaults: {
          responsibilities: { fees_collector: 'application', losses_collector: 'application' },
          profile: { product_description: 'Driving lessons booked through the DriveUSA app' },
        },
        configuration: { recipient: { capabilities: { stripe_balance: { stripe_transfers: { requested: true } } } } },
        metadata: { uid: SCHOOL },
      },
      options: { idempotencyKey: `instructor-account-${SCHOOL}` },
    }]);
    expect(calls['accounts.update']).toEqual([{
      id: ACCT,
      params: { settings: { payouts: { schedule: { interval: 'weekly', weekly_anchor: 'monday' } } } },
      options: { idempotencyKey: `instructor-payout-schedule-${ACCT}` },
    }]);
    const link = calls['v2.accountLinks.create'][0].params;
    expect(link).toMatchObject({ account: ACCT, use_case: { type: 'account_onboarding', account_onboarding: { configurations: ['recipient'] } } });
    expect(link.use_case.account_onboarding.return_url).toMatch(/\/stripeOnboardingReturn$/);
    expect(link.use_case.account_onboarding.refresh_url).toMatch(/\/stripeOnboardingReturn\?expired=1$/);
    expect((await db().collection('instructorPrivate').doc(SCHOOL).get()).get('stripePendingAccountId')).toBe(ACCT);
    await startPayouts({}, SCHOOL);
    expect(calls['v2.accounts.create']).toHaveLength(1);
    expect(calls['v2.accountLinks.create']).toHaveLength(2);
  });

  it('a payout schedule Stripe refused keeps no account id, so the next tap does the whole step again', async () => {
    failNext['accounts.update'] = Object.assign(new Error('rate'), { code: 'rate_limit' });
    await expect(startPayouts({}, SCHOOL)).rejects.toBeTruthy();
    expect((await db().collection('instructorPrivate').doc(SCHOOL).get()).get('stripePendingAccountId')).toBeNull();
    await startPayouts({}, SCHOOL);
    expect(calls['v2.accounts.create'].map((c) => c.options.idempotencyKey)).toEqual([`instructor-account-${SCHOOL}`, `instructor-account-${SCHOOL}`]);
    expect((await db().collection('instructorPrivate').doc(SCHOOL).get()).get('stripePendingAccountId')).toBe(ACCT);
  });

  it('only a driving school takes payments', async () => {
    await expect(startPayouts({}, PRIVATE)).rejects.toMatchObject({ code: 'failed-precondition', message: 'not-a-school' });
    await expect(startPayouts({}, STUDENT)).rejects.toMatchObject({ message: 'not-an-instructor' });
  });

  it('a v2 account event: ready → payouts enabled and the school told once; a stranger’s account is ignored; not ready again → off', async () => {
    await startPayouts({}, SCHOOL);
    // Thin events carry only the account id; the state is read fresh.
    const thin = (id: string, type = 'v2.core.account[configuration.recipient].capability_status_updated') => ({
      id, object: 'v2.core.event', type, related_object: { id: ACCT, type: 'v2.core.account', url: `/v2/core/accounts/${ACCT}` },
    });
    account = { metadata: { uid: SCHOOL }, configuration: recipient('active', 'pending') };
    await deliver(thin('evt_acct0'));
    expect((await db().collection('instructors').doc(SCHOOL).get()).get('payoutsEnabled')).toBe(false);
    expect(calls['v2.accounts.retrieve'][0]).toEqual({ id: ACCT, params: { include: ['configuration.recipient', 'requirements'] } });
    account = { metadata: { uid: SCHOOL }, configuration: recipient('active') };
    await deliver(thin('evt_acct1'));
    await deliver(thin('evt_acct1'));
    expect((await db().collection('instructors').doc(SCHOOL).get()).get('payoutsEnabled')).toBe(true);
    expect((await db().collection('instructorPrivate').doc(SCHOOL).get()).get('stripeAccountId')).toBe(ACCT);
    expect(pushes.filter((p) => p.title === 'Выплаты подключены')).toEqual([expect.objectContaining({ token: 'tok-school', route: 'profile' })]);
    // Another account claiming the same uid changes nothing.
    await applyAccountState({ id: 'acct_other', metadata: { uid: SCHOOL }, configuration: recipient('restricted') } as any);
    expect((await db().collection('instructors').doc(SCHOOL).get()).get('payoutsEnabled')).toBe(true);
    // Stripe restricts the account later (new requirements), reported through v1's account.updated too: off again.
    account = { metadata: { uid: SCHOOL }, configuration: recipient('restricted') };
    await deliver({ id: 'evt_acct2', type: 'account.updated', account: ACCT, data: { object: { id: ACCT, object: 'account' } } }, 'whsec_test_connect_dummy');
    expect((await db().collection('instructors').doc(SCHOOL).get()).get('payoutsEnabled')).toBe(false);
    expect((await db().collection('instructorPrivate').doc(SCHOOL).get()).get('stripeAccountId')).toBe(ACCT);
    // Another v2 event type reads nothing.
    const reads = calls['v2.accounts.retrieve'].length;
    await deliver(thin('evt_acct3', 'v2.core.account_person.updated'));
    expect(calls['v2.accounts.retrieve']).toHaveLength(reads);
  });

  it('the app’s status read catches up without the webhook; details are «submitted» once nothing waits on the school', async () => {
    await startPayouts({}, SCHOOL);
    account = { metadata: { uid: SCHOOL }, configuration: recipient('pending'), requirements: { entries: [{ awaiting_action_from: 'user' }] } };
    expect(await payoutsState({}, SCHOOL)).toEqual({ state: 'pending', detailsSubmitted: false });
    account = { metadata: { uid: SCHOOL }, configuration: recipient('pending'), requirements: { entries: [{ awaiting_action_from: 'stripe' }] } };
    expect(await payoutsState({}, SCHOOL)).toEqual({ state: 'pending', detailsSubmitted: true });
    account = { metadata: { uid: SCHOOL }, configuration: recipient('active'), requirements: { entries: [] } };
    expect(await payoutsState({}, SCHOOL)).toEqual({ state: 'enabled', detailsSubmitted: true });
  });
});

describe('account deletion (plan v2 §9.4, §17)', () => {
  it('refuses while a school has a lesson not paid out yet', async () => {
    const id = await paidBooking(3);
    await bookingRef(id).update({ status: 'completed', payoutReleaseAt: ts(Date.now() + 3600e3), startAt: ts(Date.now() - 7200e3) });
    expect(await unsettledBookingCount(db(), SCHOOL)).toBe(1);
    expect(await unsettledBookingCount(db(), STUDENT)).toBe(0);
    await expect(call(fns.deleteUserAccount)({}, SCHOOL))
      .rejects.toMatchObject({ code: 'failed-precondition', message: 'unsettled-bookings', details: { count: 1 } });
  });

  it('a connected account Stripe will not delete yet is retried hourly', async () => {
    const { closeConnectedAccount } = await import('../payments');
    failNext['v2.accounts.close'] = Object.assign(new Error('balance'), { code: 'account_invalid' });
    expect(await closeConnectedAccount('acct_test_close')).toBe(false);
    expect((await db().collection('stripeAccountClosures').doc('acct_test_close').get()).get('attempts')).toBe(1);
    await runCloseConnectedAccounts(Date.now() + 2 * 3600e3);
    expect((await db().collection('stripeAccountClosures').doc('acct_test_close').get()).exists).toBe(false);
    expect(calls['v2.accounts.close']).toEqual([
      { id: 'acct_test_close', params: { applied_configurations: ['recipient'] } },
      { id: 'acct_test_close', params: { applied_configurations: ['recipient'] } },
    ]);
  });
});
