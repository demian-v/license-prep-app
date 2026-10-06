/**
 * Instructors plan v2 §9 (P7) — bookings without money. The pure parts
 * (zone maths across DST, the fee table, first vs later), then the callables
 * against the emulator: who may book, slot locking (two parallel bookings →
 * one wins), the gateway, cancellation rules, both sweeps, deletion.
 */
import * as fs from 'fs';
import * as path from 'path';
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import {
  computeFees, feeKindFor, slotKey, setPaymentGateway, confirmBooking,
  runExpirePendingBookings, runMarkBookingsCompleted, upcomingBookingCount,
} from '../bookings';
import { collectUserDataForDeletion } from '../account-deletion';
import { setPushTransport } from '../push';
import { wallClock, wallToUtc, weekDay, addDays } from '../zone';

describe('zone maths (Intl, DST-safe)', () => {
  const at = (iso: string) => Date.parse(iso);

  it('converts Chicago wall clock across both DST changes', () => {
    expect(wallToUtc('2026-03-07', 600, 'America/Chicago')).toBe(at('2026-03-07T16:00:00Z')); // CST
    expect(wallToUtc('2026-03-08', 600, 'America/Chicago')).toBe(at('2026-03-08T15:00:00Z')); // CDT
    expect(wallToUtc('2026-10-31', 600, 'America/Chicago')).toBe(at('2026-10-31T15:00:00Z')); // CDT
    expect(wallToUtc('2026-11-01', 600, 'America/Chicago')).toBe(at('2026-11-01T16:00:00Z')); // CST
    expect(wallToUtc('2026-11-01', 6 * 60, 'America/Chicago')).toBe(at('2026-11-01T12:00:00Z'));
  });

  it('handles a zone without DST and the other US zones', () => {
    expect(wallToUtc('2026-07-01', 600, 'America/Phoenix')).toBe(at('2026-07-01T17:00:00Z'));
    expect(wallToUtc('2026-01-15', 600, 'America/Phoenix')).toBe(at('2026-01-15T17:00:00Z'));
    expect(wallToUtc('2026-07-01', 600, 'America/New_York')).toBe(at('2026-07-01T14:00:00Z'));
    expect(wallToUtc('2026-07-01', 21 * 60 + 30, 'America/Denver')).toBe(at('2026-07-02T03:30:00Z'));
  });

  it('a skipped time does not exist; an ambiguous one maps back to itself', () => {
    expect(wallToUtc('2026-03-08', 150, 'America/New_York')).toBeNull();
    const ms = wallToUtc('2026-11-01', 90, 'America/Denver')!;
    expect(wallClock(ms, 'America/Denver')).toEqual({ date: '2026-11-01', minutes: 90 });
  });

  it('reads the local date and minutes of an instant', () => {
    expect(wallClock(at('2026-10-06T03:30:00Z'), 'America/Chicago')).toEqual({ date: '2026-10-05', minutes: 22 * 60 + 30 });
    expect(weekDay('2026-10-05')).toBe('mon');
    expect(weekDay('2026-10-11')).toBe('sun');
    expect(addDays('2026-10-30', 3)).toBe('2026-11-02');
    expect(slotKey(at('2026-10-07T15:30:00Z'))).toBe('20261007T1530');
  });
});

describe('fees (plan v2 §9.1)', () => {
  it('matches the plan table with the default settings', () => {
    expect(computeFees(6000, 60, 'first')).toEqual({ lessonCents: 6000, platformFeeCents: 1500, totalCents: 7500, feeKind: 'first' });
    expect(computeFees(6000, 60, 'later')).toEqual({ lessonCents: 6000, platformFeeCents: 300, totalCents: 6300, feeKind: 'later' });
    expect(computeFees(6000, 30, 'later')).toEqual({ lessonCents: 3000, platformFeeCents: 150, totalCents: 3150, feeKind: 'later' });
    expect(computeFees(5500, 90, 'first')).toEqual({ lessonCents: 8250, platformFeeCents: 2063, totalCents: 10313, feeKind: 'first' });
  });

  it('a pair has had its first lesson only through a fee-bearing booking', () => {
    const now = Date.now();
    const b = (status: string, over: Record<string, unknown> = {}) => ({ instructorUid: 'i', status, ...over });
    const live = admin.firestore.Timestamp.fromMillis(now + 60000);
    const dead = admin.firestore.Timestamp.fromMillis(now - 60000);
    expect(feeKindFor([], 'i', now)).toBe('first');
    for (const s of ['confirmed', 'completed', 'late_cancelled', 'disputed', 'payout_released']) {
      expect(feeKindFor([b(s)], 'i', now)).toBe('later');
    }
    expect(feeKindFor([b('pending_payment', { expiresAt: live })], 'i', now)).toBe('later');
    expect(feeKindFor([b('pending_payment', { expiresAt: dead })], 'i', now)).toBe('first');
    expect(feeKindFor([b('expired'), b('refunded')], 'i', now)).toBe('first');
    expect(feeKindFor([b('completed', { instructorUid: 'other' })], 'i', now)).toBe('first');
  });
});

// ── Callables ────────────────────────────────────────────────────────────────

const db = () => admin.firestore();
const TZ = 'America/Chicago';
const STUDENT = 'bk-student';
const STUDENT2 = 'bk-student2';
const TRIAL = 'bk-trial';
const SCHOOL = 'bk-i1';
const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' }, auth_time: Math.floor(Date.now() / 1000) } } });
const call = (fn: any) => (data: unknown, uid: string) => testEnv.wrap(fn)(data as any, ctx(uid) as any);
const options = call(fns.getBookingOptions);
const book = call(fns.createBooking);
const cancel = call(fns.cancelBooking);
const inDays = (d: number) => admin.firestore.Timestamp.fromMillis(Date.now() + d * 864e5);
const allDay = Object.fromEntries(['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].map((d) => [d, [{ start: '06:00', end: '22:00' }]]));

/** 10:00 Chicago time, `days` local days from today. */
const tenAm = (days: number, minutes = 600) => wallToUtc(addDays(wallClock(Date.now(), TZ).date, days), minutes, TZ)!;

const school = (over: Record<string, unknown> = {}) => ({
  kind: 'school', name: 'Lakeview Driving School', state: 'ZB', listed: true, status: 'active', stage: 2,
  timezone: TZ, hourlyRateCents: 6000, lessonDurations: [60, 90], availability: allDay,
  schoolAddress: '1 Lake St, Chicago', ...over,
});

let pushes: { token: string; title?: string; body?: string; route?: string }[] = [];

async function wipe() {
  for (const coll of ['bookings', 'bookingSlots']) {
    const snap = await db().collection(coll).get();
    await Promise.all(snap.docs.filter((d) => {
      const x = d.data();
      return [x.studentUid, x.instructorUid].some((u) => typeof u === 'string' && (u.startsWith('bk-') || u.startsWith('deleted_bk-')));
    }).map((d) => d.ref.delete()));
  }
  for (const id of [`${STUDENT}_${SCHOOL}`, `${STUDENT2}_${SCHOOL}`]) {
    const ref = db().collection('conversations').doc(id);
    for (const m of (await ref.collection('messages').get()).docs) await m.ref.delete();
    await ref.delete();
  }
}

beforeAll(async () => {
  for (const [id, uid, planType, days] of [['bk-paid', STUDENT, 'monthly', 20], ['bk-paid2', STUDENT2, 'monthly', 20], ['bk-trial', TRIAL, 'trial', 2]] as const) {
    await db().collection('subscriptions').doc(id).set({ userId: uid, isActive: true, planType, nextBillingDate: inDays(days) });
  }
  // ZB is a fixture-only state code, so seeded data never mixes in.
  await db().collection('config').doc('instructors').set({ launchStates: ['ZB'] });
  await db().collection('users').doc(STUDENT).set({ name: 'Anna Kowalska', language: 'en' });
  await db().collection('users').doc(STUDENT2).set({ name: 'Ben Ortiz', language: 'en' });
  await db().collection('users').doc(SCHOOL).set({ name: 'Lakeview', userType: 'instructor', language: 'ru' });
  await db().collection('users').doc(SCHOOL).collection('fcmTokens').doc('t').set({ token: 'tok-i1', platform: 'ios' });
  await db().collection('users').doc(STUDENT).collection('fcmTokens').doc('t').set({ token: 'tok-s', platform: 'ios' });
});

beforeEach(async () => {
  await wipe();
  pushes = [];
  setPushTransport({
    async send(messages) {
      pushes.push(...messages.map((m) => ({ token: m.token, ...m.notification, route: m.data?.route })));
      return messages.map(() => null);
    },
  });
  // The emulator gateway: "pays" at once.
  setPaymentGateway({ begin: async (id) => { await confirmBooking(id); } });
  await db().collection('instructors').doc(SCHOOL).set(school());
  await db().collection('instructors').doc('bk-private').set(school({ kind: 'schoolInstructor', name: 'Maria' }));
  await db().collection('instructors').doc('bk-stage1').set(school({ stage: 1 }));
});

afterAll(async () => {
  await wipe();
  setPushTransport(null);
  setPaymentGateway(undefined);
  testEnv.cleanup();
});

describe('getBookingOptions', () => {
  it('lists free half-hour starts by local date, 12 h to 60 days ahead, with first-lesson prices', async () => {
    const res: any = await options({ instructorUid: SCHOOL }, STUDENT);
    expect(res.timezone).toBe(TZ);
    expect(res.quotes).toEqual([
      { durationMinutes: 60, lessonCents: 6000, platformFeeCents: 1500, totalCents: 7500, feeKind: 'first' },
      { durationMinutes: 90, lessonCents: 9000, platformFeeCents: 2250, totalCents: 11250, feeKind: 'first' },
    ]);
    const day3 = res.days.find((d: any) => d.date === addDays(wallClock(Date.now(), TZ).date, 3));
    expect(day3.slots).toHaveLength(32);
    expect(day3.slots[0]).toEqual({ time: '06:00', startAtMs: tenAm(3, 360) });
    expect(day3.slots[31]).toEqual({ time: '21:30', startAtMs: tenAm(3, 21 * 60 + 30) });
    expect(res.days[0].slots[0].startAtMs).toBeGreaterThanOrEqual(Date.now() + 12 * 3600e3);
    expect(res.days.length).toBeLessThanOrEqual(61);
  });

  it('leaves out booked half hours and prices the next lesson as later', async () => {
    await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    const res: any = await options({ instructorUid: SCHOOL }, STUDENT);
    const day3 = res.days.find((d: any) => d.date === addDays(wallClock(Date.now(), TZ).date, 3));
    const times = day3.slots.map((x: any) => x.time);
    expect(times).not.toContain('10:00');
    expect(times).not.toContain('10:30');
    expect(times).toContain('11:00');
    expect(res.quotes[0]).toMatchObject({ feeKind: 'later', platformFeeCents: 300, totalCents: 6300 });
    // Another student still pays the first-lesson fee with this school.
    expect(((await options({ instructorUid: SCHOOL }, STUDENT2)) as any).quotes[0].feeKind).toBe('first');
  });

  it('refuses a trial student, a private instructor and a stage-1 school', async () => {
    await expect(options({ instructorUid: SCHOOL }, TRIAL)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(options({ instructorUid: 'bk-private' }, STUDENT)).rejects.toMatchObject({ code: 'failed-precondition', message: 'not-bookable' });
    await expect(options({ instructorUid: 'bk-stage1' }, STUDENT)).rejects.toMatchObject({ code: 'failed-precondition', message: 'not-bookable' });
  });
});

describe('createBooking', () => {
  it('locks the half hours, confirms through the gateway, unlocks contacts and tells the school', async () => {
    const start = tenAm(3);
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: start, durationMinutes: 60 }, STUDENT);
    expect(res).toMatchObject({ status: 'confirmed', lessonCents: 6000, platformFeeCents: 1500, totalCents: 7500, feeKind: 'first' });

    const b = (await db().collection('bookings').doc(res.bookingId).get()).data()!;
    expect(b).toMatchObject({
      studentUid: STUDENT, instructorUid: SCHOOL, studentDisplayName: 'Anna K.', instructorName: 'Lakeview Driving School',
      schoolAddress: '1 Lake St, Chicago', durationMinutes: 60, timezone: TZ, status: 'confirmed',
      localDate: addDays(wallClock(Date.now(), TZ).date, 3), localTime: '10:00',
    });
    expect(b.startAt.toMillis()).toBe(start);
    expect(b.completeAfter.toMillis()).toBe(start + 3600e3);
    expect(b.expiresAt).toBeUndefined();

    const slots = await Promise.all([start, start + 1800e3, start + 3600e3].map((ms) =>
      db().collection('bookingSlots').doc(`${SCHOOL}_${slotKey(ms)}`).get()));
    expect(slots.map((s) => s.exists)).toEqual([true, true, false]);
    expect(slots[0].get('bookingId')).toBe(res.bookingId);

    const conv = (await db().collection('conversations').doc(`${STUDENT}_${SCHOOL}`).get()).data()!;
    expect(conv).toMatchObject({
      studentUid: STUDENT, instructorUid: SCHOOL, participantUids: [STUDENT, SCHOOL], contactUnlocked: true,
      instructorName: 'Lakeview Driving School', studentDisplayName: 'Anna K.', studentUnread: 0, instructorUnread: 0,
    });
    expect(pushes).toEqual([expect.objectContaining({ token: 'tok-i1', title: 'Новая бронь', route: `booking/${res.bookingId}` })]);
    expect(pushes[0].body).toMatch(/^Anna K\. · /);
  });

  it('unlocks an existing thread without touching its messages', async () => {
    const ref = db().collection('conversations').doc(`${STUDENT}_${SCHOOL}`);
    await ref.set({ studentUid: STUDENT, instructorUid: SCHOOL, participantUids: [STUDENT, SCHOOL], contactUnlocked: false, lastMessageText: 'Hi', studentUnread: 2 });
    await ref.collection('messages').doc('m1').set({ senderUid: STUDENT, text: 'Hi' });
    await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    expect((await ref.get()).data()).toMatchObject({ contactUnlocked: true, lastMessageText: 'Hi', studentUnread: 2 });
    expect((await ref.collection('messages').get()).size).toBe(1);
  });

  it('two students racing for the same time: exactly one wins', async () => {
    const start = tenAm(4);
    const results = await Promise.allSettled([
      book({ instructorUid: SCHOOL, startAtMs: start, durationMinutes: 60 }, STUDENT),
      book({ instructorUid: SCHOOL, startAtMs: start + 1800e3, durationMinutes: 60 }, STUDENT2),
    ]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const lost = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
    expect(lost.reason).toMatchObject({ code: 'already-exists', message: 'slot-taken' });
    const bookings = await db().collection('bookings').where('instructorUid', '==', SCHOOL).get();
    expect(bookings.size).toBe(1);
  });

  it('refuses outside the window, off the half-hour grid, outside hours and an unoffered length', async () => {
    await db().collection('instructors').doc(SCHOOL).update({ availability: { ...allDay, [weekDay(addDays(wallClock(Date.now(), TZ).date, 5))]: [{ start: '09:00', end: '10:00' }] } });
    const cases: [Record<string, unknown>, string, string?][] = [
      [{ startAtMs: Date.now() + 3600e3 - ((Date.now() + 3600e3) % 1800e3), durationMinutes: 60 }, 'failed-precondition', 'outside-booking-window'],
      [{ startAtMs: tenAm(61), durationMinutes: 60 }, 'failed-precondition', 'outside-booking-window'],
      [{ startAtMs: tenAm(3) + 15 * 60e3, durationMinutes: 60 }, 'invalid-argument'],
      [{ startAtMs: tenAm(3), durationMinutes: 120 }, 'invalid-argument'],
      [{ startAtMs: tenAm(3), durationMinutes: '60' }, 'invalid-argument'],
      [{ startAtMs: tenAm(5, 9 * 60 + 30), durationMinutes: 60 }, 'failed-precondition', 'outside-hours'],
      [{ startAtMs: tenAm(3, 21 * 60 + 30), durationMinutes: 60 }, 'failed-precondition', 'outside-hours'],
    ];
    for (const [data, code, message] of cases) {
      await expect(book({ instructorUid: SCHOOL, ...data }, STUDENT)).rejects.toMatchObject({ code, ...(message ? { message } : {}) });
    }
    expect((await db().collection('bookings').where('instructorUid', '==', SCHOOL).get()).size).toBe(0);
  });

  it('refuses before locking anything when there is no payment gateway (outside the emulator before P9)', async () => {
    setPaymentGateway(null);
    const start = tenAm(3);
    await expect(book({ instructorUid: SCHOOL, startAtMs: start, durationMinutes: 60 }, STUDENT))
      .rejects.toMatchObject({ code: 'failed-precondition', message: 'payments-unavailable' });
    expect((await db().collection('bookingSlots').doc(`${SCHOOL}_${slotKey(start)}`).get()).exists).toBe(false);
  });

  it('a pending booking whose payment never comes stays pending until the sweep', async () => {
    setPaymentGateway({ begin: async () => undefined });
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    expect(res.status).toBe('pending_payment');
    const b = await db().collection('bookings').doc(res.bookingId).get();
    expect(b.get('expiresAt').toMillis()).toBeGreaterThan(Date.now() + 14 * 60e3);
    expect(pushes).toEqual([]);
  });
});

describe('cancelBooking', () => {
  /** A confirmed booking `hours` from now, written directly. */
  async function confirmedIn(hours: number) {
    const start = Math.ceil((Date.now() + hours * 3600e3) / 1800e3) * 1800e3;
    const ref = db().collection('bookings').doc();
    await ref.set({
      studentUid: STUDENT, instructorUid: SCHOOL, studentDisplayName: 'Anna K.', instructorName: 'Lakeview Driving School',
      startAt: admin.firestore.Timestamp.fromMillis(start), durationMinutes: 60, timezone: TZ, status: 'confirmed',
      completeAfter: admin.firestore.Timestamp.fromMillis(start + 3600e3),
    });
    for (const ms of [start, start + 1800e3]) {
      await db().collection('bookingSlots').doc(`${SCHOOL}_${slotKey(ms)}`).set({ instructorUid: SCHOOL, bookingId: ref.id });
    }
    return { ref, start };
  }
  const slotExists = async (start: number) => (await db().collection('bookingSlots').doc(`${SCHOOL}_${slotKey(start)}`).get()).exists;

  it('a student 24 h or more ahead: refunded, slots freed, the school is told', async () => {
    const { ref, start } = await confirmedIn(30);
    expect(await cancel({ bookingId: ref.id }, STUDENT)).toEqual({ bookingId: ref.id, status: 'refunded' });
    expect((await ref.get()).data()).toMatchObject({ status: 'refunded', cancelledBy: 'student' });
    expect((await ref.get()).get('completeAfter')).toBeUndefined();
    expect(await slotExists(start)).toBe(false);
    expect(pushes).toEqual([expect.objectContaining({ token: 'tok-i1', title: 'Ученик отменил урок', route: `booking/${ref.id}` })]);
  });

  it('a student under 24 h: late_cancelled, the time stays blocked', async () => {
    const { ref, start } = await confirmedIn(5);
    expect(await cancel({ bookingId: ref.id }, STUDENT)).toMatchObject({ status: 'late_cancelled' });
    expect(await slotExists(start)).toBe(true);
  });

  it('the school, any time: refunded, slots freed, the student is told', async () => {
    const { ref, start } = await confirmedIn(2);
    expect(await cancel({ bookingId: ref.id }, SCHOOL)).toMatchObject({ status: 'refunded' });
    expect((await ref.get()).get('cancelledBy')).toBe('instructor');
    expect(await slotExists(start)).toBe(false);
    expect(pushes).toEqual([expect.objectContaining({ token: 'tok-s', title: 'Your lesson was cancelled' })]);
    expect(pushes[0].body).toMatch(/^Lakeview Driving School · /);
  });

  it('refuses a stranger, a second cancel and a lesson that has started', async () => {
    const { ref } = await confirmedIn(30);
    await expect(cancel({ bookingId: ref.id }, STUDENT2)).rejects.toMatchObject({ code: 'permission-denied' });
    await cancel({ bookingId: ref.id }, STUDENT);
    await expect(cancel({ bookingId: ref.id }, STUDENT)).rejects.toMatchObject({ code: 'failed-precondition', message: 'not-cancellable' });
    const past = await confirmedIn(-1);
    await expect(cancel({ bookingId: past.ref.id }, SCHOOL)).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(cancel({ bookingId: 'nope' }, STUDENT)).rejects.toMatchObject({ code: 'permission-denied' });
  });
});

describe('sweeps', () => {
  it('expires a pending booking past its 15 minutes and frees its half hours; a live hold stays', async () => {
    setPaymentGateway({ begin: async () => undefined });
    const late: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    const live: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(4), durationMinutes: 60 }, STUDENT2);
    await db().collection('bookings').doc(late.bookingId).update({ expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000) });

    await runExpirePendingBookings();
    const b = await db().collection('bookings').doc(late.bookingId).get();
    expect(b.get('status')).toBe('expired');
    expect(b.get('expiresAt')).toBeUndefined();
    expect((await db().collection('bookingSlots').doc(`${SCHOOL}_${slotKey(tenAm(3))}`).get()).exists).toBe(false);
    expect((await db().collection('bookings').doc(live.bookingId).get()).get('status')).toBe('pending_payment');
    // The freed time can be booked again, as a first lesson.
    setPaymentGateway({ begin: async (id) => { await confirmBooking(id); } });
    expect(await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT)).toMatchObject({ status: 'confirmed' });
    // A confirm for the expired one is ignored.
    expect(await confirmBooking(late.bookingId)).toBe(false);
  });

  it('completes a confirmed lesson whose end has passed, and only that', async () => {
    const done = db().collection('bookings').doc();
    const ahead = db().collection('bookings').doc();
    for (const [ref, endMs] of [[done, Date.now() - 60e3], [ahead, Date.now() + 3600e3]] as const) {
      await ref.set({ studentUid: STUDENT, instructorUid: SCHOOL, status: 'confirmed', completeAfter: admin.firestore.Timestamp.fromMillis(endMs) });
    }
    await runMarkBookingsCompleted();
    expect((await done.get()).get('status')).toBe('completed');
    expect((await done.get()).get('completeAfter')).toBeUndefined();
    expect((await ahead.get()).get('status')).toBe('confirmed');
  });
});

describe('account deletion (plan v2 §9.4, §17)', () => {
  it('counts upcoming confirmed lessons on either side, and deleteUserAccount refuses with the count', async () => {
    await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    expect(await upcomingBookingCount(db(), STUDENT)).toBe(1);
    expect(await upcomingBookingCount(db(), SCHOOL)).toBe(1);
    expect(await upcomingBookingCount(db(), STUDENT2)).toBe(0);
    await expect(call(fns.deleteUserAccount)({}, STUDENT))
      .rejects.toMatchObject({ code: 'failed-precondition', message: 'upcoming-bookings', details: { count: 1 } });
  });

  it('anonymises bookings: the deleted side loses its uid and name, amounts stay', async () => {
    const res: any = await book({ instructorUid: SCHOOL, startAtMs: tenAm(3), durationMinutes: 60 }, STUDENT);
    const targets = await collectUserDataForDeletion(db(), STUDENT);
    const t = targets.find((x) => x.collection === 'bookings')!;
    expect(t).toMatchObject({ action: 'redact', fields: { studentUid: 'deleted_bk-stude', studentDeleted: true, studentDisplayName: null } });
    expect(t.ref.id).toBe(res.bookingId);
    const forSchool = (await collectUserDataForDeletion(db(), SCHOOL)).find((x) => x.collection === 'bookings')!;
    expect(forSchool.fields).toEqual({ instructorUid: 'deleted_bk-i1', instructorDeleted: true, instructorName: null });
  });
});

describe('code guards', () => {
  it('uses the modular FieldPath: admin.firestore.FieldPath is undefined in the functions emulator', () => {
    // Found on the simulator 2026-10-05: jest resolves the namespace, the
    // emulator's runtime does not, so getBookingOptions threw there only.
    const src = fs.readFileSync(path.join(__dirname, '../bookings.ts'), 'utf8');
    expect(src).not.toMatch(/admin\.firestore\.FieldPath/);
  });
});
