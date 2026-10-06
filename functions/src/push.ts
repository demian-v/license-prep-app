import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

/**
 * Push notifications (instructors plan v2 §12, P5).
 *
 * The app writes one doc per device to users/{uid}/fcmTokens/{sha256(token)}
 * (firestore.rules: owner only, keys token / platform / updatedAt). A sender
 * calls sendPushToUser; the text is chosen here, in the user's app language,
 * so a message reads the same whichever function sends it.
 *
 * Every message is notification + data: the `notification` block becomes
 * `aps.alert` on iOS, which a data-only message would not get, and
 * `data.route` tells the app where a tap goes (`profile`, `chat/<id>`,
 * `booking/<id>`).
 *
 * A push is never worth failing the caller for: errors are logged, not thrown.
 */

export type PushKind = 'photo_approved' | 'photo_rejected'
  | 'booking_new' | 'booking_cancelled_student' | 'booking_cancelled_instructor';

export type Lang = 'en' | 'es' | 'uk' | 'ru' | 'pl';
const LANGS: readonly Lang[] = ['en', 'es', 'uk', 'ru', 'pl'];

// Worded like the app's own Профиль strings (iprof_photo_*), so the push and
// the screen it opens agree.
const TEXTS: Record<PushKind, Record<Lang, { title: string; body: string }>> = {
  photo_approved: {
    en: { title: 'Photo published', body: 'Students can now see it on your profile.' },
    es: { title: 'Foto publicada', body: 'Los alumnos ya la ven en tu perfil.' },
    uk: { title: 'Фото опубліковано', body: 'Учні вже бачать його у вашому профілі.' },
    ru: { title: 'Фото опубликовано', body: 'Ученики уже видят его в вашем профиле.' },
    pl: { title: 'Zdjęcie opublikowane', body: 'Kursanci widzą je już w Twoim profilu.' },
  },
  photo_rejected: {
    en: { title: "Photo wasn't accepted", body: 'Please choose another one in Profile.' },
    es: { title: 'La foto no fue aceptada', body: 'Elige otra en Perfil.' },
    uk: { title: 'Фото не прийнято', body: 'Виберіть інше у Профілі.' },
    ru: { title: 'Фото не принято', body: 'Выберите другое в Профиле.' },
    pl: { title: 'Zdjęcie nie zostało przyjęte', body: 'Wybierz inne w Profilu.' },
  },
  // Bookings (P7): {name} is the other side (a student's «Anna K.», a
  // school's name), {time} the lesson in the instructor's timezone.
  booking_new: {
    en: { title: 'New booking', body: '{name} · {time}' },
    es: { title: 'Nueva reserva', body: '{name} · {time}' },
    uk: { title: 'Нове бронювання', body: '{name} · {time}' },
    ru: { title: 'Новая бронь', body: '{name} · {time}' },
    pl: { title: 'Nowa rezerwacja', body: '{name} · {time}' },
  },
  booking_cancelled_student: {
    en: { title: 'A student cancelled a lesson', body: '{name} · {time}' },
    es: { title: 'Un alumno canceló una clase', body: '{name} · {time}' },
    uk: { title: 'Учень скасував урок', body: '{name} · {time}' },
    ru: { title: 'Ученик отменил урок', body: '{name} · {time}' },
    pl: { title: 'Kursant odwołał lekcję', body: '{name} · {time}' },
  },
  booking_cancelled_instructor: {
    en: { title: 'Your lesson was cancelled', body: '{name} · {time}' },
    es: { title: 'Tu clase fue cancelada', body: '{name} · {time}' },
    uk: { title: 'Ваш урок скасовано', body: '{name} · {time}' },
    ru: { title: 'Ваш урок отменён', body: '{name} · {time}' },
    pl: { title: 'Twoja lekcja została odwołana', body: '{name} · {time}' },
  },
};

/** The user's app language, English when unknown. */
export function pushLang(language: unknown): Lang {
  return LANGS.includes(language as Lang) ? (language as Lang) : 'en';
}

export function pushText(kind: PushKind, language: unknown, vars: Record<string, string> = {}) {
  const { title, body } = TEXTS[kind][pushLang(language)];
  return { title, body: body.replace(/\{(\w+)\}/g, (whole, key: string) => vars[key] ?? whole) };
}

/**
 * Sends the messages; one result per message, in order: null when FCM took
 * it, otherwise the error code (`messaging/...`).
 */
export interface PushTransport {
  send(messages: admin.messaging.TokenMessage[]): Promise<(string | null)[]>;
}

const fcmTransport: PushTransport = {
  async send(messages) {
    const res = await admin.messaging().sendEach(messages);
    return res.responses.map((r) => (r.success ? null : r.error?.code ?? 'unknown'));
  },
};

// The functions emulator cannot deliver through FCM. It logs the message
// instead, so a simulator can be handed the same payload with `xcrun simctl push`.
const emulatorTransport: PushTransport = {
  async send(messages) {
    for (const m of messages) functions.logger.info('push (emulator, not sent)', JSON.stringify(m));
    return messages.map(() => null);
  },
};

let override: PushTransport | null = null;
/** Tests only: replace the transport (null restores the default). */
export function setPushTransport(transport: PushTransport | null) {
  override = transport;
}

// The two codes that mean the token will never work again (app deleted,
// token rotated or deleted on logout). Anything else may be transient.
const DEAD_TOKEN = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/**
 * `vars` fills the text's placeholders; it is given the reader's language,
 * so a date can be written the way they read it.
 */
export async function sendPushToUser(
  uid: string,
  kind: PushKind,
  route: string,
  vars?: (lang: Lang) => Record<string, string>,
): Promise<void> {
  await deliver(uid, kind, route, async (userRef) => {
    const lang = pushLang((await userRef.get()).get('language'));
    return pushText(kind, lang, vars?.(lang));
  });
}

/**
 * A push whose words come from the sender, not from TEXTS: a chat message
 * («Anna: …», plan v2 §12). The caller has already masked the body.
 */
export async function sendTextPushToUser(
  uid: string,
  kind: 'chat_message',
  { title, body, route }: { title: string; body: string; route: string },
): Promise<void> {
  await deliver(uid, kind, route, async () => ({ title, body }));
}

async function deliver(
  uid: string,
  kind: string,
  route: string,
  text: (userRef: FirebaseFirestore.DocumentReference) => Promise<{ title: string; body: string }>,
): Promise<void> {
  try {
    const userRef = admin.firestore().collection('users').doc(uid);
    const tokens = await userRef.collection('fcmTokens').get();
    if (tokens.empty) return;
    const { title, body } = await text(userRef);
    const messages: admin.messaging.TokenMessage[] = tokens.docs.map((doc) => ({
      token: doc.get('token'),
      notification: { title, body },
      data: { route, kind },
      apns: { payload: { aps: { sound: 'default' } } },
      android: { priority: 'high' },
    }));
    const transport = override ?? (process.env.FUNCTIONS_EMULATOR === 'true' ? emulatorTransport : fcmTransport);
    const results = await transport.send(messages);
    const dead = tokens.docs.filter((_, i) => DEAD_TOKEN.has(results[i] ?? ''));
    await Promise.all(dead.map((doc) => doc.ref.delete()));
    const failed = results.filter((r) => r !== null).length;
    if (failed > 0) functions.logger.warn('push: some sends failed', { kind, failed, pruned: dead.length });
  } catch (e) {
    functions.logger.warn('push failed', { kind, error: String(e) });
  }
}
