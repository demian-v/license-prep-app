/**
 * Instructors plan v2 §12 (P5) — sendPushToUser. The functions emulator cannot
 * deliver FCM, so the transport is replaced with a recorder that answers with
 * the error codes a test chooses.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import '../index';
import { sendPushToUser, setPushTransport, pushText } from '../push';

const db = () => admin.firestore();
const UID = 'push-1';
const tokens = () => db().collection('users').doc(UID).collection('fcmTokens');

let sent: admin.messaging.TokenMessage[] = [];
let answer: (m: admin.messaging.TokenMessage) => string | null = () => null;

async function wipe() {
  const snap = await tokens().get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
  await db().collection('users').doc(UID).delete().catch(() => {});
}

beforeEach(async () => {
  await wipe();
  sent = [];
  answer = () => null;
  setPushTransport({
    async send(messages) {
      sent.push(...messages);
      return messages.map((m) => answer(m));
    },
  });
  await db().collection('users').doc(UID).set({ language: 'ru' });
});
afterAll(async () => {
  setPushTransport(null);
  await wipe();
  testEnv.cleanup();
});

describe('sendPushToUser', () => {
  it('sends notification + data to every device, in the user language', async () => {
    await tokens().doc('a').set({ token: 'tok-a', platform: 'ios' });
    await tokens().doc('b').set({ token: 'tok-b', platform: 'android' });
    await sendPushToUser(UID, 'photo_approved', 'profile');
    expect(sent.map((m) => m.token).sort()).toEqual(['tok-a', 'tok-b']);
    expect(sent[0]).toMatchObject({
      notification: { title: 'Фото опубликовано', body: 'Ученики уже видят его в вашем профиле.' },
      data: { route: 'profile', kind: 'photo_approved' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  });

  it('falls back to English for a missing or unknown language', async () => {
    await db().collection('users').doc(UID).set({ language: 'zz' });
    await tokens().doc('a').set({ token: 'tok-a', platform: 'ios' });
    await sendPushToUser(UID, 'photo_rejected', 'profile');
    expect(sent[0].notification).toEqual(pushText('photo_rejected', 'en'));
    expect(pushText('photo_rejected', undefined).title).toBe("Photo wasn't accepted");
  });

  it('has a text in all 5 app languages for every kind', () => {
    for (const kind of ['photo_approved', 'photo_rejected'] as const) {
      const titles = ['en', 'es', 'uk', 'ru', 'pl'].map((l) => pushText(kind, l).title);
      expect(new Set(titles).size).toBe(5);
    }
  });

  it('sends nothing when the user has no device', async () => {
    await sendPushToUser(UID, 'photo_approved', 'profile');
    expect(sent).toHaveLength(0);
  });

  it('prunes tokens FCM says are gone, and keeps the rest', async () => {
    await tokens().doc('gone').set({ token: 'tok-gone', platform: 'ios' });
    await tokens().doc('bad').set({ token: 'tok-bad', platform: 'ios' });
    await tokens().doc('busy').set({ token: 'tok-busy', platform: 'ios' });
    await tokens().doc('ok').set({ token: 'tok-ok', platform: 'android' });
    answer = (m) => ({
      'tok-gone': 'messaging/registration-token-not-registered',
      'tok-bad': 'messaging/invalid-registration-token',
      'tok-busy': 'messaging/server-unavailable',
    } as Record<string, string>)[m.token] ?? null;
    await sendPushToUser(UID, 'photo_approved', 'profile');
    expect((await tokens().get()).docs.map((d) => d.id).sort()).toEqual(['busy', 'ok']);
  });

  it('never throws when the transport fails', async () => {
    await tokens().doc('a').set({ token: 'tok-a', platform: 'ios' });
    setPushTransport({ send: async () => { throw new Error('fcm down'); } });
    await expect(sendPushToUser(UID, 'photo_approved', 'profile')).resolves.toBeUndefined();
    expect((await tokens().get()).size).toBe(1);
  });
});
