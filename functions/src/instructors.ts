import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { requirePaidSubscriber } from './entitlement';
import { RELEASED_STATES, timezoneForZip } from './zip-timezone';

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
  out.photoUrl = data.photoApproved === true ? data.photoUrl ?? null : null;
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
 * email code («How do you teach?»). Each is set once: the same answer again
 * is accepted, a different one is refused, so the answer cannot be switched
 * to reach a trial. Only the intent — `userType` stays granted by
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
    if (kind !== null && existingKind !== null && existingKind !== kind) {
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
    photoUrl: null, photoApproved: false,
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
