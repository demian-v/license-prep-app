import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { requirePaidSubscriber } from './entitlement';
import { RELEASED_STATES, timezoneForZip } from './zip-timezone';
import { stripJpegMetadata } from './jpeg-metadata';

/**
 * Instructors marketplace — the student-side read path (plan v2 §3, §13).
 *
 * Students never read instructors/{uid} directly (firestore.rules allows only
 * the owner): the trial/paid distinction lives on subscriptions docs, which a
 * rule cannot query, so every student read goes through a callable gated on
 * requirePaidSubscriber. The callable also decides WHICH fields leave the
 * server — anything not listed here stays private.
 */
const PUBLIC_FIELDS = [
  'kind', 'name', 'schoolName', 'schoolLicenseNumber', 'schoolAddress',
  'fleetSize', 'instructorCount', 'state', 'city', 'languages',
  'carModel', 'carYear', 'hasDualControls', 'bio', 'hourlyRateCents',
  'lessonDurations', 'stage', 'ratingAvg', 'ratingCount', 'payoutsEnabled',
] as const;

export function publicInstructor(id: string, data: FirebaseFirestore.DocumentData) {
  const out: Record<string, unknown> = { id };
  for (const field of PUBLIC_FIELDS) {
    if (data[field] !== undefined) out[field] = data[field];
  }
  // A photo is shown only once moderation approved it; until then the app
  // draws the placeholder avatar (plan v2 §5 — nobody is hidden for it).
  // A Storage path, which the app resolves under storage.rules.
  out.photoPath = data.photoApproved === true ? data.photoPath ?? null : null;
  // A private instructor's price only after a licence number is checked
  // (owner, 2026-09-30): until then the listing is "message me", not an
  // advertised paid lesson (625 ILCS 5/6-401 covers instruction "for hire").
  out.priceHidden = data.kind === 'schoolInstructor' && data.licenseCheck !== 'passed';
  if (out.priceHidden) delete out.hourlyRateCents;
  return out;
}

/**
 * Every listed instructor in one state. No page cap: a state holds tens of
 * listings, and the app filters and orders them itself (plan v2 §13). The
 * query is equality-only, so it needs no composite index (risk #15).
 */
export const listInstructors = functions.https.onCall(async (data, context) => {
  await requirePaidSubscriber(context);

  const state = typeof data?.state === 'string' ? data.state.trim().toUpperCase() : '';
  if (!/^[A-Z]{2}$/.test(state)) {
    throw new functions.https.HttpsError('invalid-argument', 'A two-letter state code is required.');
  }

  const db = admin.firestore();
  const config = await db.collection('config').doc('instructors').get();
  const launchStates: unknown = config.get('launchStates');
  if (!Array.isArray(launchStates) || !launchStates.includes(state)) {
    return { launched: false, instructors: [] };
  }

  const snap = await db.collection('instructors')
    .where('state', '==', state)
    .where('listed', '==', true)
    .get();
  return { launched: true, instructors: snap.docs.map((doc) => publicInstructor(doc.id, doc.data())) };
});

// ── Registration and listing (plan v2 §4.3, §5, §6.4) ────────────────────────

/** Languages an instructor can teach in (plan v2 §4.3 step 1). */
export const TEACHING_LANGUAGES = [
  'en', 'es', 'zh', 'vi', 'ko', 'tl', 'ar', 'ru', 'uk', 'pl',
  'pt', 'fr', 'ht', 'hi', 'ur', 'fa', 'so', 'hmn', 'am', 'de',
] as const;

const LESSON_DURATIONS = [60, 90, 120];

/**
 * The one place that decides whether a profile is in search and at which
 * verification stage it stands (plan v2 §5, §6.4). Owner decision
 * 2026-09-30: verification may be skipped at signup, so a complete, active
 * profile is listed at stage 0 («Не проверен») — nobody is held back for a
 * pending photo or check.
 */
export function computeListing(p: FirebaseFirestore.DocumentData, nowMs = Date.now()) {
  const profileComplete = typeof p.name === 'string' && p.name.length > 0
    && typeof p.state === 'string' && typeof p.city === 'string' && p.city.length > 0
    && Array.isArray(p.languages) && p.languages.length > 0
    && Number.isInteger(p.hourlyRateCents)
    && Array.isArray(p.lessonDurations) && p.lessonDurations.length > 0;
  const listed = p.status === 'active' && profileComplete;

  const idPassed = p.idCheck === 'passed';
  const licenseLive = p.licenseCheck === 'passed'
    && (p.licenseExpiresAt == null || p.licenseExpiresAt.toMillis() > nowMs);
  const hasHours = p.availability != null
    && Object.values(p.availability).some((day) => Array.isArray(day) && day.length > 0);
  const stage = idPassed && licenseLive && p.payoutsEnabled === true && hasHours ? 2 : idPassed ? 1 : 0;
  return { listed, stage };
}

function str(v: unknown, min: number, max: number): string | null {
  if (typeof v !== 'string') return null;
  const t = v.trim();
  return t.length >= min && t.length <= max ? t : null;
}
function int(v: unknown, min: number, max: number): number | null {
  return Number.isInteger(v) && (v as number) >= min && (v as number) <= max ? (v as number) : null;
}
function bad(field: string): never {
  throw new functions.https.HttpsError('invalid-argument', `Invalid or missing field: ${field}`);
}

/**
 * The end of the instructor wizard: creates the public profile and its
 * private companion, and grants the role (users.userType, server-owned by
 * firestore.rules). Photo, licence review and the ID check all come later.
 */
/**
 * Who is signing up (instructors plan v2 §4.1). Owner, 2026-09-30: the Sign
 * Up page («Create Student / Instructor Account») knows the role, so it is
 * saved when the account is made; an instructor's kind follows after the
 * email code («How do you teach?»). The role is set once: the same answer
 * again is accepted, a different one is refused, so it cannot be switched to
 * reach a trial. The kind may change until registerAsInstructor. Only the intent — `userType` stays granted by
 * registerAsInstructor. A student's trial is started by the client after the
 * code; createTrialSubscription refuses an instructor.
 */
export const setSignupRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not logged in');
  const role = data?.signupRole;
  if (role !== 'student' && role !== 'instructor') {
    throw new functions.https.HttpsError('invalid-argument', 'signupRole must be student or instructor');
  }
  const kind = role === 'instructor' && data?.signupKind != null ? data.signupKind : null;
  if (kind !== null && kind !== 'school' && kind !== 'schoolInstructor') {
    throw new functions.https.HttpsError('invalid-argument', 'signupKind must be school or schoolInstructor');
  }
  const db = admin.firestore();
  const ref = db.collection('users').doc(context.auth.uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const existingRole = snap.get('signupRole') ?? null;
    const existingKind = snap.get('signupKind') ?? null;
    if (existingRole !== null && existingRole !== role) {
      throw new functions.https.HttpsError('failed-precondition', 'signup-role-already-set');
    }
    // The kind may still change until the instructor registers — the
    // wizard's first Back reopens «How do you teach?» (owner, 2026-09-30).
    // It grants nothing; the role, which gates the trial, never changes.
    if (kind !== null && existingKind !== null && existingKind !== kind && snap.get('userType') === 'instructor') {
      throw new functions.https.HttpsError('failed-precondition', 'signup-kind-already-set');
    }
    if (existingRole === role && (kind === null || existingKind === kind)) return; // a retry
    tx.set(ref, {
      signupRole: role,
      ...(kind ? { signupKind: kind } : {}),
      lastUpdated: FieldValue.serverTimestamp(),
    }, { merge: true });
  });
  return { signupRole: role, signupKind: kind };
});

export const registerAsInstructor = functions.https.onCall(async (data, context) => {
  if (!context?.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to register as an instructor.');
  }
  if (context.auth.token?.firebase?.sign_in_provider === 'anonymous') {
    throw new functions.https.HttpsError('permission-denied', 'Anonymous sessions cannot register.');
  }
  const uid: string = context.auth.uid;
  const d = data ?? {};

  const kind = d.kind === 'school' || d.kind === 'schoolInstructor' ? d.kind : bad('kind');
  const name = str(d.name, 2, 80) ?? bad('name');
  // A private instructor may add their school later (owner, 2026-09-30).
  const schoolName = kind === 'school' ? name
    : d.schoolName == null || d.schoolName === '' ? null : (str(d.schoolName, 2, 80) ?? bad('schoolName'));
  const languages: string[] = Array.isArray(d.languages)
    && d.languages.length >= 1 && d.languages.length <= 10
    && d.languages.every((l: unknown) => (TEACHING_LANGUAGES as readonly string[]).includes(l as string))
    ? Array.from(new Set(d.languages as string[])) : bad('languages');
  const state = (RELEASED_STATES as readonly string[]).includes(d.state) ? (d.state as string) : bad('state');
  const city = str(d.city, 2, 60) ?? bad('city');
  const zipCode = typeof d.zipCode === 'string' && /^\d{5}$/.test(d.zipCode) ? d.zipCode : bad('zipCode');
  const timezone = timezoneForZip(state, zipCode) ?? bad('zipCode');
  const carModel = str(d.carModel, 2, 60) ?? bad('carModel');
  const carYear = int(d.carYear, 1995, new Date().getFullYear() + 1) ?? bad('carYear');
  const hasDualControls = typeof d.hasDualControls === 'boolean' ? d.hasDualControls : bad('hasDualControls');
  const hourlyRateCents = int(d.hourlyRateCents, 2000, 20000) ?? bad('hourlyRateCents');
  const lessonDurations: number[] = Array.isArray(d.lessonDurations) && d.lessonDurations.length > 0
    && d.lessonDurations.every((m: unknown) => LESSON_DURATIONS.includes(m as number))
    ? Array.from(new Set(d.lessonDurations as number[])).sort((a, b) => a - b) : bad('lessonDurations');
  const bio = d.bio == null || d.bio === '' ? '' : (str(d.bio, 0, 600) ?? bad('bio'));
  const phoneDigits = typeof d.phone === 'string' ? d.phone.replace(/\D/g, '') : '';
  if (phoneDigits.length < 10 || phoneDigits.length > 15) bad('phone');
  const contactEmail = typeof d.contactEmail === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(d.contactEmail.trim())
    ? d.contactEmail.trim() : bad('contactEmail');
  // Licence numbers are optional at signup (owner, 2026-09-30): the profile is
  // listed as «Не проверен» and the numbers can be added later in Профиль.
  const schoolLicenseNumber = d.schoolLicenseNumber ? (str(d.schoolLicenseNumber, 2, 40) ?? bad('schoolLicenseNumber')) : null;
  const instructorLicenseNumber = kind === 'schoolInstructor' && d.instructorLicenseNumber
    ? (str(d.instructorLicenseNumber, 2, 40) ?? bad('instructorLicenseNumber')) : null;
  const school = kind === 'school' ? {
    schoolAddress: str(d.schoolAddress, 5, 120) ?? bad('schoolAddress'),
    fleetSize: int(d.fleetSize, 1, 200) ?? bad('fleetSize'),
    instructorCount: int(d.instructorCount, 1, 500) ?? bad('instructorCount'),
  } : {};

  const db = admin.firestore();
  const ref = db.collection('instructors').doc(uid);
  const now = Timestamp.now();
  const publicDoc: FirebaseFirestore.DocumentData = {
    kind, name, schoolName, schoolLicenseNumber, ...school,
    photoPath: null, photoApproved: false, photoStatus: 'none',
    state, city, cityKey: city.toLowerCase(), zipCode, timezone,
    languages, carModel, carYear, hasDualControls, bio, hourlyRateCents, lessonDurations,
    idCheck: 'none',
    licenseCheck: schoolLicenseNumber || instructorLicenseNumber ? 'pending' : 'none',
    licenseState: state, licenseExpiresAt: null,
    payoutsEnabled: false, availability: {},
    ratingSum: 0, ratingCount: 0, ratingAvg: 0,
    status: 'active', createdAt: now, updatedAt: now,
  };
  Object.assign(publicDoc, computeListing(publicDoc));

  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) {
      throw new functions.https.HttpsError('already-exists', 'This account is already registered as an instructor.');
    }
    tx.create(ref, publicDoc);
    tx.set(db.collection('instructorPrivate').doc(uid), {
      phone: d.phone.trim(), contactEmail, licenseNumber: instructorLicenseNumber,
      stripeAccountId: null, stripePendingAccountId: null,
      identitySessionIds: [], biometricConsentAt: null,
      moderation: { photo: { status: 'none' } },
    });
    tx.set(db.collection('users').doc(uid), { userType: 'instructor', state, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });

  return { state, listed: publicDoc.listed, stage: publicDoc.stage };
});

/**
 * Adds or changes the licence numbers later, from Профиль (owner,
 * 2026-09-30: verification can be done after signup). A changed number goes
 * back to 'pending' for the admin review (plan v2 §6.4).
 */
export const submitLicenseNumber = functions.https.onCall(async (data, context) => {
  if (!context?.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  const uid: string = context.auth.uid;
  const db = admin.firestore();
  const ref = db.collection('instructors').doc(uid);
  const snap = await ref.get();
  if (!snap.exists) throw new functions.https.HttpsError('failed-precondition', 'Not an instructor account.');

  // A school must give its school licence. A private instructor may give
  // either number, or both (owner, 2026-09-30): an Illinois instructor
  // licence is only issued to someone associated with a licensed school
  // (92 Ill. Adm. Code 1060.120(a)(8)), so it already implies one.
  const isPrivate = snap.get('kind') === 'schoolInstructor';
  const schoolLicenseNumber = data?.schoolLicenseNumber
    ? (str(data.schoolLicenseNumber, 2, 40) ?? bad('schoolLicenseNumber')) : null;
  const instructorLicenseNumber = isPrivate && data?.instructorLicenseNumber
    ? (str(data.instructorLicenseNumber, 2, 40) ?? bad('instructorLicenseNumber')) : null;
  if (!isPrivate && !schoolLicenseNumber) bad('schoolLicenseNumber');
  if (!schoolLicenseNumber && !instructorLicenseNumber) bad('licenseNumber');

  const ownBefore = isPrivate
    ? (await db.collection('instructorPrivate').doc(uid).get()).get('licenseNumber') ?? null : null;
  const changed = (snap.get('schoolLicenseNumber') ?? null) !== schoolLicenseNumber
    || (instructorLicenseNumber !== null && instructorLicenseNumber !== ownBefore);
  await db.runTransaction(async (tx) => {
    tx.update(ref, {
      schoolLicenseNumber,
      ...(changed ? { licenseCheck: 'pending', licenseExpiresAt: null } : {}),
      updatedAt: Timestamp.now(),
    });
    if (instructorLicenseNumber) {
      tx.set(db.collection('instructorPrivate').doc(uid), { licenseNumber: instructorLicenseNumber }, { merge: true });
    }
  });
  return { licenseCheck: changed ? 'pending' : snap.get('licenseCheck') };
});

/**
 * Profile editing from Профиль (plan v2 §14.2, P3b): what the wizard skipped
 * or the instructor wants to change, one section per call. The same checks
 * as registerAsInstructor, plus the weekly hours from Календарь. Every edit comes through here, not a direct
 * write: the contacts live in instructorPrivate, which no client can touch,
 * and the rules allowlist no longer carries these fields (it checked the
 * rate and bio but not their neighbours' types or sizes). Kind, role,
 * location and licence data are not editable here.
 */
export const updateInstructorProfile = functions.https.onCall(async (data, context) => {
  if (!context?.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  const uid: string = context.auth.uid;
  const d = data ?? {};
  const db = admin.firestore();
  const ref = db.collection('instructors').doc(uid);
  const snap = await ref.get();
  if (!snap.exists) throw new functions.https.HttpsError('failed-precondition', 'Not an instructor account.');
  // Suspension is an admin decision (plan v2 §7); the profile stays as it was.
  if (snap.get('status') === 'suspended') throw new functions.https.HttpsError('failed-precondition', 'suspended');

  let fields: FirebaseFirestore.DocumentData;
  switch (d.section) {
    case 'bio':
      fields = { bio: d.bio == null || d.bio === '' ? '' : (str(d.bio, 0, 600) ?? bad('bio')) };
      break;
    case 'school':
      // A school's name IS its profile name; only a private instructor names
      // the school they teach at, and may clear it (owner, 2026-09-30).
      if (snap.get('kind') !== 'schoolInstructor') bad('section');
      fields = { schoolName: d.schoolName == null || d.schoolName === '' ? null : (str(d.schoolName, 2, 80) ?? bad('schoolName')) };
      break;
    case 'price':
      fields = {
        hourlyRateCents: int(d.hourlyRateCents, 2000, 20000) ?? bad('hourlyRateCents'),
        lessonDurations: Array.isArray(d.lessonDurations) && d.lessonDurations.length > 0
          && d.lessonDurations.every((m: unknown) => LESSON_DURATIONS.includes(m as number))
          ? Array.from(new Set(d.lessonDurations as number[])).sort((a, b) => a - b) : bad('lessonDurations'),
      };
      break;
    case 'car':
      fields = {
        carModel: str(d.carModel, 2, 60) ?? bad('carModel'),
        carYear: int(d.carYear, 1995, new Date().getFullYear() + 1) ?? bad('carYear'),
        hasDualControls: typeof d.hasDualControls === 'boolean' ? d.hasDualControls : bad('hasDualControls'),
      };
      break;
    case 'availability':
      fields = { availability: cleanAvailability(d.availability) ?? bad('availability') };
      break;
    case 'contacts': {
      const phoneDigits = typeof d.phone === 'string' ? d.phone.replace(/\D/g, '') : '';
      if (phoneDigits.length < 10 || phoneDigits.length > 15) bad('phone');
      const contactEmail = typeof d.contactEmail === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(d.contactEmail.trim())
        ? d.contactEmail.trim() : bad('contactEmail');
      await db.runTransaction(async (tx) => {
        tx.set(db.collection('instructorPrivate').doc(uid), { phone: d.phone.trim(), contactEmail }, { merge: true });
        tx.update(ref, { updatedAt: Timestamp.now() });
      });
      return { section: 'contacts' };
    }
    default:
      bad('section');
  }
  await ref.update({ ...fields, updatedAt: Timestamp.now() });
  return { section: d.section };
});

// ── Weekly hours (plan v2 §14.2 Календарь) ──────────────────────────────────

export const WEEK_DAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] as const;
const DAY_START = 6 * 60;
const DAY_END = 22 * 60;
const SLOT = 30;

function minutes(v: unknown): number | null {
  if (typeof v !== 'string' || !/^\d{2}:\d{2}$/.test(v)) return null;
  const m = Number(v.slice(0, 2)) * 60 + Number(v.slice(3));
  return Number(v.slice(3)) < 60 && m % SLOT === 0 && m >= DAY_START && m <= DAY_END ? m : null;
}
const hhmm = (m: number) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;

/**
 * Wall-clock hours in the instructor's timezone, `{mon: [{start, end}], …}`.
 * Each interval sits on the 30-minute grid between 06:00 and 22:00 (the
 * Календарь grid). The result is canonical — sorted and merged, so
 * overlapping or touching intervals become one — and empty days are dropped.
 * Null when anything is malformed.
 */
export function cleanAvailability(v: unknown): Record<string, { start: string; end: string }[]> | null {
  if (v == null || typeof v !== 'object' || Array.isArray(v)) return null;
  const out: Record<string, { start: string; end: string }[]> = {};
  for (const [day, list] of Object.entries(v as Record<string, unknown>)) {
    if (!(WEEK_DAYS as readonly string[]).includes(day) || !Array.isArray(list) || list.length > 32) return null;
    const slots = new Set<number>();
    for (const item of list) {
      if (item == null || typeof item !== 'object') return null;
      const keys = Object.keys(item);
      if (keys.length !== 2 || !keys.includes('start') || !keys.includes('end')) return null;
      const start = minutes((item as any).start);
      const end = minutes((item as any).end);
      if (start === null || end === null || start >= end) return null;
      for (let m = start; m < end; m += SLOT) slots.add(m);
    }
    const intervals: { start: string; end: string }[] = [];
    for (const m of [...slots].sort((a, b) => a - b)) {
      const last = intervals[intervals.length - 1];
      if (last && minutes(last.end) === m) last.end = hhmm(m + SLOT);
      else intervals.push({ start: hhmm(m), end: hhmm(m + SLOT) });
    }
    if (intervals.length > 0) out[day] = intervals;
  }
  return out;
}

/** The owner's own phone and contact email, for the Профиль edit sheet. */
export const getInstructorContacts = functions.https.onCall(async (_data, context) => {
  if (!context?.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  const snap = await admin.firestore().collection('instructorPrivate').doc(context.auth.uid).get();
  if (!snap.exists) throw new functions.https.HttpsError('failed-precondition', 'Not an instructor account.');
  return { phone: snap.get('phone') ?? '', contactEmail: snap.get('contactEmail') ?? '' };
});

// ── Profile photo (plan v2 §8) ───────────────────────────────────────────────

const PHOTO_UPLOAD = /^instructorUploads\/([^/]+)\/photo\/([A-Za-z0-9_-]{1,64})\.jpg$/;
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

/**
 * A finished upload to the private pending path. The client never writes
 * photoPath: this trigger decides what students see. Until P10's SafeSearch
 * check exists, production keeps the photo `pending` (fail-closed — nothing
 * unmoderated is shown, and an approved older photo stays); only the
 * emulator auto-approves, so the flow can be built and tested end to end.
 * Approving writes the file, stripped of its metadata (the phone's GPS
 * position travels in EXIF), to a versioned public name (no stale cache)
 * and removes the upload and the previous photo. A file that is not a JPEG
 * the stripper can read is refused. One pending upload is kept per
 * instructor, so repeated tries don't pile up.
 */
export const onInstructorUpload = functions.storage.object().onFinalize(async (object) => {
  const match = PHOTO_UPLOAD.exec(object.name ?? '');
  if (!match) return;
  const [, uid, uploadId] = match;
  const bucket = admin.storage().bucket(object.bucket);
  const upload = bucket.file(object.name!);
  // A redelivered event after the upload was already handled.
  if (!(await upload.exists())[0]) return;

  const db = admin.firestore();
  const ref = db.collection('instructors').doc(uid);
  const privateRef = db.collection('instructorPrivate').doc(uid);
  const snap = await ref.get();
  // storage.rules checks the same; this is the server's own word.
  if (!snap.exists || object.contentType !== 'image/jpeg' || Number(object.size) >= MAX_PHOTO_BYTES) {
    await upload.delete({ ignoreNotFound: true });
    return;
  }

  const now = Timestamp.now();
  if (process.env.FUNCTIONS_EMULATOR !== 'true') {
    const before = (await privateRef.get()).get('moderation.photo');
    if (before?.status === 'pending' && before.uploadId && before.uploadId !== uploadId) {
      await bucket.file(`instructorUploads/${uid}/photo/${before.uploadId}.jpg`).delete({ ignoreNotFound: true });
    }
    await privateRef.set({ moderation: { photo: { status: 'pending', uploadId, updatedAt: now } } }, { merge: true });
    await ref.update({ photoStatus: 'pending', updatedAt: now });
    return;
  }

  // Published without the phone's metadata (GPS position, device, time).
  const [original] = await upload.download();
  const clean = stripJpegMetadata(original);
  if (!clean) {
    await upload.delete({ ignoreNotFound: true });
    await ref.update({ photoStatus: 'rejected', updatedAt: now });
    return;
  }
  const photoPath = `instructorPhotos/${uid}/${uploadId}.jpg`;
  const previous = snap.get('photoPath');
  await bucket.file(photoPath).save(clean, { contentType: 'image/jpeg', resumable: false });
  await ref.update({ photoPath, photoApproved: true, photoStatus: 'approved', updatedAt: now });
  await privateRef.set({ moderation: { photo: { status: 'approved', uploadId, updatedAt: now } } }, { merge: true });
  await upload.delete({ ignoreNotFound: true });
  if (typeof previous === 'string' && previous !== photoPath) {
    await bucket.file(previous).delete({ ignoreNotFound: true });
  }
});

/**
 * Keeps `listed` / `stage` true to computeListing whatever wrote the doc
 * (owner edits, admin actions, webhooks), and the public per-state count in
 * step. The count is RECOUNTED, not incremented: triggers can be delivered
 * more than once, and an increment would drift.
 */
export const onInstructorWrite = functions.firestore
  .document('instructors/{uid}')
  .onWrite(async (change) => {
    const before = change.before.exists ? change.before.data()! : null;
    const after = change.after.exists ? change.after.data()! : null;
    const db = admin.firestore();

    if (after) {
      const { listed, stage } = computeListing(after);
      if (after.listed !== listed || after.stage !== stage) {
        await change.after.ref.update({ listed, stage });
        return; // the update re-fires this trigger, which recounts
      }
    }

    const states = new Set<string>();
    if (before?.state && before.listed === true) states.add(before.state);
    if (after?.state && after.listed === true) states.add(after.state);
    if (before && after && before.listed === after.listed && before.state === after.state) return;
    for (const state of states) {
      const count = await db.collection('instructors')
        .where('state', '==', state).where('listed', '==', true).count().get();
      await db.collection('instructorStats').doc(state)
        .set({ listedCount: count.data().count, updatedAt: Timestamp.now() }, { merge: true });
    }
  });
