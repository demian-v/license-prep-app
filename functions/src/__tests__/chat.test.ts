/**
 * Instructors plan v2 §10 (P6) — chat. The masking table (§16), then the
 * callables: who may start a thread, the daily limit, the paywall on sending,
 * closed threads, unread counts, the push, and contacts after unlocking.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { maskContacts, preview, studentDisplayName, MASK, NEW_THREADS_PER_DAY } from '../chat';
import { setPushTransport } from '../push';

describe('maskContacts — the table', () => {
  const masked: [string, string][] = [
    ['call me 312 555 0123', `call me ${MASK}`],
    ['(312) 555-0123', MASK],
    ['+1 (312) 555-0123 thanks', `${MASK} thanks`],
    ['312.555.0123', MASK],
    ['3125550123', MASK],
    ['555-0123 after 6', `${MASK} after 6`],
    ['3 1 2 5 5 5 0 1', MASK],
    ['write anna.k@gmail.com', `write ${MASK}`],
    ['ANNA@EXAMPLE.ORG', MASK],
    ['see https://example.com/me', `see ${MASK}`],
    ['www.lakeview-school.com/prices', MASK],
    ['lakeview.com', MASK],
    ['t.me/annak', MASK],
    ['wa.me/13125550123', MASK],
    ['insta @anna_drives', `insta ${MASK}`],
    ['telegram 555 12', MASK],
    ['WhatsApp: 12345', MASK],
    ['пиши в телеграм 555', `пиши в ${MASK}`],
    ['вайбер 0501', MASK],
    ['мой номер 773 555 01 23', `мой номер ${MASK}`],
    // Accepted false positive (owner, 2026-10-05): seven small numbers.
    ['lessons of 60 90 120 min', `lessons of ${MASK} min`],
  ];
  it.each(masked)('masks %j', (input, expected) => {
    expect(maskContacts(input)).toEqual({ text: expected, masked: true });
  });

  const kept = [
    'See you on 12.10.2026 at 10:30',
    'Lesson 10/12/2026, 2 hours',
    'Toyota Corolla 2019, $60 per hour',
    'Meet at 1200 Main St',
    'Signal before turning left',
    'Telegram me later',
    'e.g. parallel parking, i.e. the hard part',
    'Привет! Урок в 9:00, сигнал поворота обязательно',
    'Spelled out: three one two, five five five',
  ];
  it.each(kept)('leaves %j alone', (input) => {
    expect(maskContacts(input)).toEqual({ text: input, masked: false });
  });

  it('a date-shaped phone is still a phone', () => {
    expect(maskContacts('77.35.5501 23').masked).toBe(true);
  });

  it('keeps the rest of a mixed message', () => {
    expect(maskContacts('Hi! On 12.10.2026 call 312-555-0123 or mail a@b.co').text)
      .toBe(`Hi! On 12.10.2026 call ${MASK} or mail ${MASK}`);
  });
});

describe('preview and studentDisplayName', () => {
  it('is one line of at most 80 characters', () => {
    expect(preview('a\n\nb   c')).toBe('a b c');
    const long = preview('x'.repeat(200));
    expect(long).toHaveLength(80);
    expect(long.endsWith('…')).toBe(true);
  });

  it('is the first name and the last initial', () => {
    expect(studentDisplayName('Anna Kowalska')).toBe('Anna K.');
    expect(studentDisplayName('  maria  de la cruz ')).toBe('maria C.');
    expect(studentDisplayName('Anna')).toBe('Anna');
    expect(studentDisplayName(undefined)).toBe('');
  });
});

// ── Callables ────────────────────────────────────────────────────────────────

const db = () => admin.firestore();
const ctx = (uid: string, provider = 'password') => ({ auth: { uid, token: { firebase: { sign_in_provider: provider } } } });
const inDays = (d: number) => admin.firestore.Timestamp.fromMillis(Date.now() + d * 864e5);
const send = (data: unknown, uid: string) => testEnv.wrap(fns.sendMessage as any)(data as any, ctx(uid) as any);
const markRead = (data: unknown, uid: string) => testEnv.wrap(fns.markConversationRead as any)(data as any, ctx(uid) as any);
const contacts = (data: unknown, uid: string) => testEnv.wrap(fns.getInstructorContactInfo as any)(data as any, ctx(uid) as any);

const STUDENT = 'ct-student';
const TRIAL = 'ct-trial';
const conv = (s: string, i: string) => db().collection('conversations').doc(`${s}_${i}`);
const instructor = (over: Record<string, unknown> = {}) => ({
  kind: 'schoolInstructor', name: 'Maria Lopez', state: 'ZC', listed: true, status: 'active', stage: 1,
  photoPath: 'instructorPhotos/ct-i1/p1.jpg', photoApproved: true, ...over,
});

let pushes: { token: string; title?: string; body?: string; route?: string }[] = [];

async function wipe() {
  for (const coll of ['conversations']) {
    const snap = await db().collection(coll).where('participantUids', 'array-contains-any', [STUDENT, TRIAL, 'ct-i1', 'ct-i2']).get();
    for (const d of snap.docs) {
      for (const m of (await d.ref.collection('messages').get()).docs) await m.ref.delete();
      await d.ref.delete();
    }
  }
}

beforeAll(async () => {
  await db().collection('subscriptions').doc('ct-paid').set({
    userId: STUDENT, isActive: true, planType: 'monthly', nextBillingDate: inDays(20),
  });
  await db().collection('subscriptions').doc('ct-trial').set({
    userId: TRIAL, isActive: true, planType: 'trial', nextBillingDate: inDays(2),
  });
  // ZC is a fixture-only state code, so seeded data never mixes in.
  await db().collection('config').doc('instructors').set({ launchStates: ['ZC', 'ZI'] }, { merge: true });
  await db().collection('users').doc(STUDENT).set({ name: 'Anna Kowalska', language: 'ru' });
  await db().collection('users').doc('ct-i1').set({ name: 'Maria Lopez', userType: 'instructor' });
  await db().collection('users').doc('ct-i1').collection('fcmTokens').doc('t').set({ token: 'tok-i1', platform: 'ios' });
  await db().collection('users').doc(STUDENT).collection('fcmTokens').doc('t').set({ token: 'tok-s', platform: 'ios' });
  await db().collection('instructorPrivate').doc('ct-i1').set({ phone: '+1 312 555 0100', contactEmail: 'maria@example.com' });
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
  await db().collection('instructors').doc('ct-i1').set(instructor());
  await db().collection('instructors').doc('ct-i2').set(instructor({ name: 'Unverified', stage: 0 }));
});

afterAll(async () => {
  await wipe();
  setPushTransport(null);
  testEnv.cleanup();
});

describe('sendMessage — starting a thread', () => {
  it('a paid student starts a thread with a stage-1 instructor', async () => {
    const res = await send({ instructorUid: 'ct-i1', text: 'Hello! Free on Saturday?' }, STUDENT);
    expect(res).toEqual({ conversationId: `${STUDENT}_ct-i1`, created: true, masked: false });
    const c = (await conv(STUDENT, 'ct-i1').get()).data()!;
    expect(c).toMatchObject({
      studentUid: STUDENT, instructorUid: 'ct-i1', participantUids: [STUDENT, 'ct-i1'],
      instructorName: 'Maria Lopez', instructorPhotoPath: 'instructorPhotos/ct-i1/p1.jpg',
      studentDisplayName: 'Anna K.', contactUnlocked: false,
      lastMessageText: 'Hello! Free on Saturday?', lastMessageSender: STUDENT,
      studentUnread: 0, instructorUnread: 1,
    });
    const msgs = await conv(STUDENT, 'ct-i1').collection('messages').get();
    expect(msgs.docs.map((m) => m.data())).toEqual([
      expect.objectContaining({ senderUid: STUDENT, text: 'Hello! Free on Saturday?', masked: false }),
    ]);
  });

  it('masks contacts before storing, in the message, the preview and the push', async () => {
    const res = await send({ instructorUid: 'ct-i1', text: 'call 312 555 0123' }, STUDENT);
    expect(res.masked).toBe(true);
    const msg = (await conv(STUDENT, 'ct-i1').collection('messages').get()).docs[0].data();
    expect(msg).toMatchObject({ text: `call ${MASK}`, masked: true });
    expect((await conv(STUDENT, 'ct-i1').get()).get('lastMessageText')).toBe(`call ${MASK}`);
    expect(pushes).toEqual([{ token: 'tok-i1', title: 'Anna', body: `call ${MASK}`, route: `chat/${STUDENT}_ct-i1` }]);
  });

  it('refuses a trial student', async () => {
    await expect(send({ instructorUid: 'ct-i1', text: 'Hi' }, TRIAL)).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('refuses an instructor below stage 1', async () => {
    await expect(send({ instructorUid: 'ct-i2', text: 'Hi' }, STUDENT))
      .rejects.toMatchObject({ code: 'failed-precondition', message: 'instructor-not-verified' });
  });

  it('refuses an unlisted instructor for a NEW thread', async () => {
    await db().collection('instructors').doc('ct-i1').update({ listed: false, status: 'deactivated' });
    await expect(send({ instructorUid: 'ct-i1', text: 'Hi' }, STUDENT)).rejects.toMatchObject({ code: 'not-found' });
  });

  it('refuses empty, over-long and non-text messages', async () => {
    for (const text of ['', '   ', 'x'.repeat(2001), 42]) {
      await expect(send({ instructorUid: 'ct-i1', text }, STUDENT)).rejects.toMatchObject({ code: 'invalid-argument' });
    }
    await expect(send({ instructorUid: 'ct-i1', text: 'x'.repeat(2000) }, STUDENT)).resolves.toMatchObject({ created: true });
  });

  it('an instructor cannot start a thread', async () => {
    await db().collection('subscriptions').doc('ct-i1-paid').set({
      userId: 'ct-i1', isActive: true, planType: 'monthly', nextBillingDate: inDays(20),
    });
    try {
      await expect(send({ instructorUid: 'ct-i2', text: 'Hi' }, 'ct-i1')).rejects.toBeTruthy();
      await db().collection('instructors').doc('ct-i2').update({ stage: 1 });
      await expect(send({ instructorUid: 'ct-i2', text: 'Hi' }, 'ct-i1')).rejects.toMatchObject({ code: 'permission-denied' });
    } finally {
      await db().collection('subscriptions').doc('ct-i1-paid').delete();
    }
  });

  it(`allows ${NEW_THREADS_PER_DAY} new threads a day, then refuses the next`, async () => {
    const ids = Array.from({ length: NEW_THREADS_PER_DAY + 1 }, (_, n) => `ct-lim-${n}`);
    for (const id of ids) await db().collection('instructors').doc(id).set(instructor({ name: `I ${id}` }));
    try {
      for (const id of ids.slice(0, NEW_THREADS_PER_DAY)) {
        await expect(send({ instructorUid: id, text: 'Hi' }, STUDENT)).resolves.toMatchObject({ created: true });
      }
      await expect(send({ instructorUid: ids[NEW_THREADS_PER_DAY], text: 'Hi' }, STUDENT))
        .rejects.toMatchObject({ code: 'resource-exhausted', message: 'thread-limit' });
      // Writing in an existing thread is not a new thread.
      await expect(send({ instructorUid: ids[0], text: 'Again' }, STUDENT)).resolves.toMatchObject({ created: false });
      // Threads older than a day do not count.
      for (const id of ids.slice(0, NEW_THREADS_PER_DAY)) {
        await conv(STUDENT, id).update({ createdAt: inDays(-2) });
      }
      await expect(send({ instructorUid: ids[NEW_THREADS_PER_DAY], text: 'Hi' }, STUDENT)).resolves.toMatchObject({ created: true });
    } finally {
      for (const id of ids) {
        const c = conv(STUDENT, id);
        for (const m of (await c.collection('messages').get()).docs) await m.ref.delete();
        await c.delete();
        await db().collection('instructors').doc(id).delete();
      }
    }
  });
});

describe('sendMessage — an existing thread', () => {
  beforeEach(async () => {
    await send({ instructorUid: 'ct-i1', text: 'Hello' }, STUDENT);
    pushes = [];
  });
  const id = `${STUDENT}_ct-i1`;

  it('the instructor replies; the student gets the unread count and a push', async () => {
    const res = await send({ conversationId: id, text: 'Hi Anna, yes!' }, 'ct-i1');
    expect(res).toEqual({ conversationId: id, created: false, masked: false });
    const c = (await conv(STUDENT, 'ct-i1').get()).data()!;
    expect(c).toMatchObject({ studentUnread: 1, instructorUnread: 1, lastMessageSender: 'ct-i1' });
    expect(pushes).toEqual([{ token: 'tok-s', title: 'Maria', body: 'Hi Anna, yes!', route: `chat/${id}` }]);
  });

  it('a school sends under its whole name', async () => {
    await db().collection('instructors').doc('ct-i1').update({ kind: 'school', name: 'Lakeview Driving School' });
    await send({ conversationId: id, text: 'Welcome' }, 'ct-i1');
    expect(pushes[0].title).toBe('Lakeview Driving School');
  });

  it('an outsider cannot write in it', async () => {
    await expect(send({ conversationId: id, text: 'Hi' }, 'ct-i2')).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('a lapsed student reads but cannot send (owner, 2026-10-05)', async () => {
    // Past the store grace window too: requirePaidSubscriber honours it.
    await db().collection('subscriptions').doc('ct-paid').update({ isActive: false, nextBillingDate: inDays(-30) });
    try {
      await expect(send({ conversationId: id, text: 'Hi' }, STUDENT)).rejects.toMatchObject({ code: 'permission-denied' });
      // The instructor can still reply.
      await expect(send({ conversationId: id, text: 'Hi' }, 'ct-i1')).resolves.toMatchObject({ created: false });
    } finally {
      await db().collection('subscriptions').doc('ct-paid').update({ isActive: true, nextBillingDate: inDays(20) });
    }
  });

  it('goes on after the instructor is unlisted or drops below stage 1', async () => {
    await db().collection('instructors').doc('ct-i1').update({ listed: false, status: 'deactivated', stage: 0 });
    await expect(send({ instructorUid: 'ct-i1', text: 'Still there?' }, STUDENT)).resolves.toMatchObject({ created: false });
  });

  it('closes when the instructor is suspended or either side is deleted', async () => {
    await db().collection('instructors').doc('ct-i1').update({ status: 'suspended' });
    await expect(send({ conversationId: id, text: 'Hi' }, STUDENT)).rejects.toMatchObject({ message: 'conversation-closed' });
    await expect(send({ conversationId: id, text: 'Hi' }, 'ct-i1')).rejects.toMatchObject({ message: 'conversation-closed' });
    await db().collection('instructors').doc('ct-i1').update({ status: 'active' });
    await conv(STUDENT, 'ct-i1').update({ instructorDeleted: true });
    await expect(send({ conversationId: id, text: 'Hi' }, STUDENT)).rejects.toMatchObject({ message: 'conversation-closed' });
  });

  it('stops masking once contacts are unlocked', async () => {
    await conv(STUDENT, 'ct-i1').update({ contactUnlocked: true });
    const res = await send({ conversationId: id, text: 'My number: 312 555 0100' }, 'ct-i1');
    expect(res.masked).toBe(false);
    expect((await conv(STUDENT, 'ct-i1').get()).get('lastMessageText')).toBe('My number: 312 555 0100');
  });
});

describe('markConversationRead', () => {
  const id = `${STUDENT}_ct-i1`;
  beforeEach(async () => {
    await send({ instructorUid: 'ct-i1', text: 'Hello' }, STUDENT);
    await send({ conversationId: id, text: 'Hi' }, 'ct-i1');
  });

  it('resets only the caller\'s own count', async () => {
    await markRead({ conversationId: id }, 'ct-i1');
    expect((await conv(STUDENT, 'ct-i1').get()).data()).toMatchObject({ instructorUnread: 0, studentUnread: 1 });
    await markRead({ conversationId: id }, STUDENT);
    expect((await conv(STUDENT, 'ct-i1').get()).data()).toMatchObject({ instructorUnread: 0, studentUnread: 0 });
  });

  it('refuses an outsider and a malformed id', async () => {
    await expect(markRead({ conversationId: id }, 'ct-i2')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(markRead({ conversationId: '../x' }, STUDENT)).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});

describe('getInstructorContactInfo', () => {
  const id = `${STUDENT}_ct-i1`;
  beforeEach(() => send({ instructorUid: 'ct-i1', text: 'Hello' }, STUDENT));

  it('is refused until the thread is unlocked by a booking', async () => {
    await expect(contacts({ conversationId: id }, STUDENT)).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('gives the student the phone and email once unlocked', async () => {
    await conv(STUDENT, 'ct-i1').update({ contactUnlocked: true });
    await expect(contacts({ conversationId: id }, STUDENT))
      .resolves.toEqual({ phone: '+1 312 555 0100', contactEmail: 'maria@example.com' });
  });

  it('is never served to the instructor side or an outsider', async () => {
    await conv(STUDENT, 'ct-i1').update({ contactUnlocked: true });
    await expect(contacts({ conversationId: id }, 'ct-i1')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(contacts({ conversationId: id }, 'ct-i2')).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
