import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { requirePaidSubscriber } from './entitlement';
import { listedInstructor } from './instructors';
import { sendTextPushToUser } from './push';

/**
 * Chat before booking, with contacts masked (instructors plan v2 §10, P6).
 *
 * conversations/{studentUid_instructorUid} and their messages are written only
 * here (firestore.rules: participants read, nobody writes), so the masking,
 * the paywall and the new-thread limit cannot be skipped by a client.
 *
 * Owner decisions (2026-10-05):
 * - A student whose paid plan has ended keeps READING their threads but
 *   cannot send until they subscribe again.
 * - Listing and stage gate only the first message. An existing thread goes on
 *   when the instructor is unlisted or deactivated; it closes only when the
 *   instructor is suspended or either side deleted their account.
 * - Dates (12.10.2026) are not masked as phone numbers; a list of small
 *   numbers («60 90 120») is, and that false positive is accepted.
 */

export const MASK = '•••';
export const MAX_MESSAGE_LENGTH = 2000;
export const PREVIEW_LENGTH = 80;
export const NEW_THREADS_PER_DAY = 5;

// A date the masking must leave alone: dd.mm.yyyy or mm/dd/yyyy, both parts
// a plausible day/month and a 19xx/20xx year — so «77.35.5501» is still a
// phone. A two-digit year has six digits and is never masked anyway.
const DATE = /(?<!\d)(\d{1,2})[./-](\d{1,2})[./-]((?:19|20)\d{2})(?!\d)/g;
const EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)*\.[A-Z]{2,}/gi;
const URL = /(?:https?:\/\/|www\.)\S+/gi;
const DOMAIN = /(?<![\p{L}\p{N}@-])[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:com|net|org|io|app|info|biz|site|online|link|dev|xyz|ru|ua|pl|us|co|me|ly|gl)(?![\p{L}\p{N}])(?:\/\S*)?/giu;
// A messenger named next to digits («telegram 555 12»), even when the digits
// are too few to look like a phone on their own.
const MESSENGER = /(?<![\p{L}\p{N}])(?:whats\s?app|telegram|viber|signal|ватсап|вотсап|вацап|телеграм|телега|вайбер)\p{L}*[^\p{N}\n]{0,15}\p{N}(?:[\s.\-()]*\p{N})*/giu;
// Seven or more digits, allowing up to two spaces, dots, dashes or brackets
// between them: 3125550123, (312) 555-0123, 3 1 2 5 5 5 0.
const PHONE = /\+?\(?\d(?:[\s.\-()]{0,2}\d){6,}/g;
const HANDLE = /(?<![\p{L}\p{N}_.])@[A-Za-z0-9_.]{2,}/gu;

/**
 * The text with contact details replaced by •••. Server-side, so every
 * client and every direct call gets the same treatment. Spelled-out numbers
 * («three one two…») get through; that is accepted (plan v2 §10).
 */
export function maskContacts(text: string): { text: string; masked: boolean } {
  // Dates are set aside as private-use markers that hold no digit, so the
  // phone pattern cannot see them, and put back at the end.
  const dates: string[] = [];
  let out = text.replace(DATE, (whole, a: string, b: string) => {
    const [x, y] = [Number(a), Number(b)];
    if (x < 1 || y < 1 || x > 31 || y > 31 || (x > 12 && y > 12)) return whole;
    dates.push(whole);
    return `${String.fromCharCode(0xE100 + dates.length - 1)}`;
  });
  for (const pattern of [EMAIL, URL, DOMAIN, MESSENGER, PHONE, HANDLE]) {
    out = out.replace(pattern, MASK);
  }
  out = out.replace(/(.)/g, (_, c: string) => dates[c.charCodeAt(0) - 0xE100]);
  return { text: out, masked: out !== text };
}

/** One line of at most [PREVIEW_LENGTH] characters, for the list and a push. */
export function preview(text: string): string {
  const line = text.replace(/\s+/g, ' ').trim();
  return line.length <= PREVIEW_LENGTH ? line : `${line.slice(0, PREVIEW_LENGTH - 1).trimEnd()}…`;
}

/** "Anna Kowalska" → "Anna K." — what an instructor sees of a student. */
export function studentDisplayName(name: unknown): string {
  const parts = typeof name === 'string' ? name.trim().split(/\s+/).filter(Boolean) : [];
  if (parts.length === 0) return '';
  return parts.length === 1 ? parts[0] : `${parts[0]} ${parts[parts.length - 1][0].toUpperCase()}.`;
}

const ID = /^[A-Za-z0-9_-]{1,128}$/;

function signedIn(context: any): string {
  if (!context?.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  if (context.auth.token?.firebase?.sign_in_provider === 'anonymous') {
    throw new functions.https.HttpsError('permission-denied', 'Anonymous sessions cannot chat.');
  }
  return context.auth.uid;
}

/** The conversation the caller is in, or permission-denied. */
async function ownConversation(uid: string, conversationId: unknown) {
  if (typeof conversationId !== 'string' || !ID.test(conversationId)) {
    throw new functions.https.HttpsError('invalid-argument', 'A conversation id is required.');
  }
  const snap = await admin.firestore().collection('conversations').doc(conversationId).get();
  if (!snap.exists || !(snap.get('participantUids') ?? []).includes(uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Not your conversation.');
  }
  return snap;
}

/**
 * Sends one text message (plan v2 §10). A student passes `instructorUid` (the
 * first message creates the thread) or `conversationId`; an instructor
 * replies with `conversationId` only — instructors cannot start a thread.
 */
export const sendMessage = functions.https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const raw = typeof data?.text === 'string' ? data.text.trim() : '';
  if (raw.length === 0 || raw.length > MAX_MESSAGE_LENGTH) {
    throw new functions.https.HttpsError('invalid-argument', `Text must be 1–${MAX_MESSAGE_LENGTH} characters.`);
  }

  const db = admin.firestore();
  let conversationId: string;
  let existing: FirebaseFirestore.DocumentSnapshot | null = null;
  if (data?.conversationId != null) {
    existing = await ownConversation(uid, data.conversationId);
    conversationId = existing.id;
  } else {
    const instructorUid = data?.instructorUid;
    if (typeof instructorUid !== 'string' || !ID.test(instructorUid) || instructorUid === uid) {
      throw new functions.https.HttpsError('invalid-argument', 'An instructor id is required.');
    }
    conversationId = `${uid}_${instructorUid}`;
    const snap = await db.collection('conversations').doc(conversationId).get();
    if (snap.exists) existing = snap;
  }

  const asStudent = existing ? existing.get('studentUid') === uid : true;
  const studentUid: string = asStudent ? uid : existing!.get('studentUid');
  const instructorUid: string = existing ? existing.get('instructorUid') : data.instructorUid;

  if (existing && (existing.get('studentDeleted') === true || existing.get('instructorDeleted') === true)) {
    throw new functions.https.HttpsError('failed-precondition', 'conversation-closed');
  }

  let instructor: FirebaseFirestore.DocumentSnapshot;
  if (asStudent && !existing) {
    // The first message: the detail page's gates (paid student, listed, a
    // launched state) plus stage ≥ 1 (ID checked, plan v2 §6.4), so a fake
    // profile cannot collect leads.
    instructor = await listedInstructor({ id: instructorUid }, context);
    if ((instructor.get('stage') ?? 0) < 1) {
      throw new functions.https.HttpsError('failed-precondition', 'instructor-not-verified');
    }
  } else {
    // Chat is a paid feature: a lapsed student reads but does not send.
    if (asStudent) await requirePaidSubscriber(context);
    instructor = await db.collection('instructors').doc(instructorUid).get();
  }
  if (!instructor.exists || instructor.get('status') === 'suspended') {
    throw new functions.https.HttpsError('failed-precondition', 'conversation-closed');
  }

  const student = await db.collection('users').doc(studentUid).get();
  if (!existing && student.get('userType') === 'instructor') {
    throw new functions.https.HttpsError('permission-denied', 'Instructors cannot start a conversation.');
  }

  const unlocked = existing?.get('contactUnlocked') === true;
  const { text, masked } = unlocked ? { text: raw, masked: false } : maskContacts(raw);
  const ref = db.collection('conversations').doc(conversationId);
  const now = Timestamp.now();
  const displayName = studentDisplayName(student.get('name'));
  const last = { lastMessageText: preview(text), lastMessageAt: now, lastMessageSender: uid };

  const created = await db.runTransaction(async (tx) => {
    // Reads first (a transaction cannot read after it writes).
    const current = await tx.get(ref);
    const mine = current.exists ? null : await tx.get(db.collection('conversations').where('studentUid', '==', uid));
    const messageRef = ref.collection('messages').doc();
    if (current.exists) {
      tx.create(messageRef, { senderUid: uid, text, masked, createdAt: now });
      tx.update(ref, {
        ...last,
        ...(asStudent ? { studentDisplayName: displayName } : {}),
        [asStudent ? 'instructorUnread' : 'studentUnread']: FieldValue.increment(1),
      });
      return false;
    }
    // Five new threads per student per rolling day (plan v2 §10). Counted
    // from the student's own conversations, filtered here, so no composite
    // index is needed (risk #15).
    const dayAgo = now.toMillis() - 24 * 3600 * 1000;
    if (mine!.docs.filter((d) => (d.get('createdAt')?.toMillis() ?? 0) > dayAgo).length >= NEW_THREADS_PER_DAY) {
      throw new functions.https.HttpsError('resource-exhausted', 'thread-limit');
    }
    tx.create(ref, {
      studentUid: uid,
      instructorUid,
      participantUids: [uid, instructorUid],
      instructorName: instructor.get('name') ?? '',
      // A Storage path, not a URL (P3b); onInstructorUpload keeps it current.
      instructorPhotoPath: instructor.get('photoApproved') === true ? instructor.get('photoPath') ?? null : null,
      instructorKind: instructor.get('kind') ?? null,
      studentDisplayName: displayName,
      contactUnlocked: false,
      ...last,
      studentUnread: 0,
      instructorUnread: 1,
      createdAt: now,
    });
    tx.create(messageRef, { senderUid: uid, text, masked, createdAt: now });
    return true;
  });

  // Title: the sender's first name (a school's whole name). Body: the
  // masked text, so a push never carries what the thread hides.
  const senderName = asStudent
    ? displayName.split(' ')[0]
    : instructor.get('kind') === 'school' ? instructor.get('name') : String(instructor.get('name') ?? '').split(' ')[0];
  await sendTextPushToUser(asStudent ? instructorUid : studentUid, 'chat_message', {
    title: senderName || 'DriveUSA',
    body: preview(text),
    route: `chat/${conversationId}`,
  });

  return { conversationId, created, masked };
});

/** Resets the caller's unread count in one conversation (plan v2 §10). */
export const markConversationRead = functions.https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const snap = await ownConversation(uid, data?.conversationId);
  const field = snap.get('studentUid') === uid ? 'studentUnread' : 'instructorUnread';
  if ((snap.get(field) ?? 0) !== 0) await snap.ref.update({ [field]: 0 });
  return { conversationId: snap.id };
});

/**
 * The instructor's phone and contact email for the student's thread header,
 * only once the thread is unlocked by the first confirmed booking (P7 sets
 * `contactUnlocked`). They live in instructorPrivate, which no client reads.
 */
export const getInstructorContactInfo = functions.https.onCall(async (data, context) => {
  const uid = signedIn(context);
  const snap = await ownConversation(uid, data?.conversationId);
  if (snap.get('studentUid') !== uid || snap.get('contactUnlocked') !== true) {
    throw new functions.https.HttpsError('permission-denied', 'contacts-locked');
  }
  const priv = await admin.firestore().collection('instructorPrivate').doc(snap.get('instructorUid')).get();
  if (!priv.exists) throw new functions.https.HttpsError('not-found', 'This profile is not available.');
  return { phone: priv.get('phone') ?? '', contactEmail: priv.get('contactEmail') ?? '' };
});
