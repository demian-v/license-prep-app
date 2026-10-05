/**
 * LOCAL TOOLING — seed the Instructors marketplace into the Firestore EMULATOR.
 *
 * Plan v2 P1 (vault raw/drive_usa/2026-09-30-Instructors Plan v2.md). Writes:
 *   config/instructors          { launchStates: ['IL', 'TX'] }   (owner decision 2026-09-30)
 *   instructors/{uid}           24 profiles across IL / TX / MD, every stage and kind,
 *                               plus one deactivated and one suspended (listed:false)
 *   instructorPrivate/{uid}     fictional 555-01xx phones, example.com emails
 *   instructors/{uid}/reviews   a few reviews, with ratingSum/Count/Avg kept consistent
 *   instructorStats/{state}     listedCount per state
 *   users/{uid}                 userType:'instructor'
 *   Auth accounts               seed-instr-NN@example.com / SEED_PASSWORD below, when
 *                               FIREBASE_AUTH_EMULATOR_HOST is set (sign in as an instructor),
 *                               plus seed-signup-school@ / seed-signup-instructor@example.com, instructors mid-signup,
 *                               and students seed-student-paid@ (IL) / -trial@ (IL) / -md@ (MD, paid)
 *   conversations/{id}          P6 chat: seed-student-paid with Lakeview (unlocked, as if
 *                               booked: contacts in the header) and Olena (one unread reply,
 *                               one masked message); reset on every run
 * Idempotent: a re-run overwrites the same ids.
 *
 * EMULATORS ONLY. Refuses to run unless FIRESTORE_EMULATOR_HOST is a local address.
 *
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *   GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-instructors.js
 */
const admin = require('../../functions/node_modules/firebase-admin');

if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  console.error('REFUSING: FIRESTORE_EMULATOR_HOST is not a local address.');
  process.exit(1);
}

const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '';
if (AUTH_HOST && !/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(AUTH_HOST)) {
  console.error('REFUSING: FIREBASE_AUTH_EMULATOR_HOST is not a local address.');
  process.exit(1);
}
// Emulator-only test credential for the seeded instructor accounts.
const SEED_PASSWORD = 'seed-instructor-2026';

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'licenseprepapp' });
const db = admin.firestore();
const { Timestamp } = admin.firestore;

const WEEKDAYS = { mon: [{ start: '09:00', end: '12:00' }, { start: '14:00', end: '18:00' }],
  tue: [{ start: '09:00', end: '17:00' }], wed: [{ start: '12:00', end: '20:00' }],
  thu: [{ start: '09:00', end: '17:00' }], fri: [{ start: '09:00', end: '15:00' }] };
const WEEKENDS = { sat: [{ start: '08:00', end: '14:00' }], sun: [{ start: '10:00', end: '16:00' }] };

// [state, city, tz, kind, name, schoolName, languages, rateUsd, stage, status, reviews[]]
const ROWS = [
  ['IL', 'Chicago', 'America/Chicago', 'school', 'Lakeview Driving School', null, ['en', 'pl'], 65, 2, 'active', [5, 5, 4]],
  ['IL', 'Chicago', 'America/Chicago', 'schoolInstructor', 'Marek Nowak', 'Lakeview Driving School', ['pl', 'en'], 60, 2, 'active', [5, 4]],
  ['IL', 'Chicago', 'America/Chicago', 'schoolInstructor', 'Olena Kovalenko', 'Lakeview Driving School', ['uk', 'ru', 'en'], 60, 1, 'active', []],
  ['IL', 'Chicago', 'America/Chicago', 'school', 'Northside Auto Academy', null, ['en', 'es'], 75, 2, 'active', [4, 4, 5, 3]],
  ['IL', 'Evanston', 'America/Chicago', 'schoolInstructor', 'Carlos Ramirez', 'Northside Auto Academy', ['es', 'en'], 70, 0, 'active', []],
  ['IL', 'Naperville', 'America/Chicago', 'school', 'Prairie Road School', null, ['en'], 80, 2, 'active', [5, 5, 5, 5, 4]],
  ['IL', 'Schaumburg', 'America/Chicago', 'schoolInstructor', 'Anna Wiśniewska', 'Prairie Road School', ['pl', 'en'], 70, 1, 'active', [5]],
  ['IL', 'Skokie', 'America/Chicago', 'schoolInstructor', 'Dmytro Shevchenko', 'Lakeview Driving School', ['uk', 'en'], 55, 0, 'active', []],
  ['IL', 'Chicago', 'America/Chicago', 'schoolInstructor', 'Irina Petrova', 'Northside Auto Academy', ['ru', 'en'], 65, 2, 'deactivated', [4]],
  ['IL', 'Cicero', 'America/Chicago', 'schoolInstructor', 'Luis Herrera', 'Prairie Road School', ['es'], 50, 0, 'suspended', []],
  ['TX', 'Houston', 'America/Chicago', 'school', 'Bayou City Driving School', null, ['en', 'es'], 60, 2, 'active', [5, 4, 4]],
  ['TX', 'Houston', 'America/Chicago', 'schoolInstructor', 'María González', 'Bayou City Driving School', ['es', 'en'], 55, 2, 'active', [5, 5]],
  ['TX', 'Houston', 'America/Chicago', 'schoolInstructor', 'Nguyen Van An', 'Bayou City Driving School', ['vi', 'en'], 55, 1, 'active', []],
  ['TX', 'Dallas', 'America/Chicago', 'school', 'Lone Star Road Academy', null, ['en', 'es'], 70, 2, 'active', [4, 3, 4]],
  ['TX', 'Dallas', 'America/Chicago', 'schoolInstructor', 'Oksana Bondar', 'Lone Star Road Academy', ['uk', 'ru', 'en'], 65, 1, 'active', [5]],
  ['TX', 'Austin', 'America/Chicago', 'school', 'Capitol Driving Lessons', null, ['en'], 85, 2, 'active', [5, 5, 4, 5]],
  ['TX', 'Austin', 'America/Chicago', 'schoolInstructor', 'Jordan Lee', 'Capitol Driving Lessons', ['en', 'zh'], 80, 0, 'active', []],
  ['TX', 'San Antonio', 'America/Chicago', 'schoolInstructor', 'José Martínez', 'Alamo Driver Training', ['es', 'en'], 50, 0, 'active', []],
  ['TX', 'El Paso', 'America/Denver', 'school', 'Sun City Driving School', null, ['es', 'en'], 55, 2, 'active', [4, 5]],
  ['TX', 'Plano', 'America/Chicago', 'schoolInstructor', 'Piotr Zieliński', 'Lone Star Road Academy', ['pl', 'en'], 65, 2, 'active', []],
  ['MD', 'Baltimore', 'America/New_York', 'school', 'Harbor Driving School', null, ['en', 'es'], 70, 2, 'active', [5, 4]],
  ['MD', 'Silver Spring', 'America/New_York', 'schoolInstructor', 'Amir Haddad', 'Harbor Driving School', ['ar', 'en'], 65, 1, 'active', []],
  ['MD', 'Rockville', 'America/New_York', 'school', 'Montgomery Road School', null, ['en', 'ko'], 75, 0, 'active', []],
  ['MD', 'Towson', 'America/New_York', 'schoolInstructor', 'Svitlana Melnyk', 'Harbor Driving School', ['uk', 'en'], 60, 2, 'active', [5]],
];

const REVIEWERS = ['Anna K.', 'Jake M.', 'Sofia R.', 'Taras P.', 'Emily W.'];
const COMMENTS = ['Very patient, passed on the first try.', 'Clear explanations of the road test route.',
  'Good lessons, sometimes late.', 'Explained everything in my language.', 'Calm and professional.'];

(async () => {
  const now = Timestamp.now();
  const stats = {};
  const batch = db.batch();

  ROWS.forEach(([state, city, timezone, kind, name, schoolName, languages, rateUsd, stage, status, reviews], i) => {
    const n = String(i + 1).padStart(2, '0');
    const uid = `seed-instr-${n}`;
    const listed = status === 'active';
    const ratingSum = reviews.reduce((a, b) => a + b, 0);
    const ratingCount = reviews.length;
    if (listed) stats[state] = (stats[state] || 0) + 1;

    batch.set(db.collection('instructors').doc(uid), {
      kind, name, schoolName: kind === 'school' ? name : schoolName,
      schoolLicenseNumber: `${state}-DS-${1000 + i}`,
      ...(kind === 'school' ? { schoolAddress: `${100 + i} Main St, ${city}, ${state}`, fleetSize: 3 + (i % 5), instructorCount: 2 + (i % 4) } : {}),
      photoPath: null, photoApproved: false, photoStatus: 'none',
      state, city, cityKey: city.toLowerCase(), zipCode: null, timezone,
      languages, carModel: ['Toyota Corolla', 'Honda Civic', 'Hyundai Elantra'][i % 3],
      carYear: 2019 + (i % 6), hasDualControls: true,
      bio: `${kind === 'school' ? 'Licensed driving school' : 'Instructor'} in ${city}. Road test preparation, highway and parking practice.`,
      hourlyRateCents: rateUsd * 100, lessonDurations: [60, 90, 120],
      idCheck: stage >= 1 ? 'passed' : 'none',
      licenseCheck: stage === 2 ? 'passed' : 'pending',
      licenseState: state,
      licenseExpiresAt: stage === 2 ? Timestamp.fromMillis(Date.now() + 365 * 864e5) : null,
      stage, payoutsEnabled: stage === 2,
      availability: i % 3 === 0 ? { ...WEEKDAYS, ...WEEKENDS } : i % 3 === 1 ? WEEKDAYS : {},
      ratingSum, ratingCount, ratingAvg: ratingCount ? Math.round((ratingSum / ratingCount) * 10) / 10 : 0,
      status, listed, createdAt: now, updatedAt: now,
    });
    batch.set(db.collection('instructorPrivate').doc(uid), {
      phone: `+1 312 555 01${n}`, contactEmail: `${uid}@example.com`,
      stripeAccountId: null, stripePendingAccountId: null,
      identitySessionIds: [], biometricConsentAt: stage >= 1 ? now : null,
      licenseNumber: kind === 'schoolInstructor' ? `${state}-DI-${5000 + i}` : null,
      moderation: { photo: { status: 'none' } },
    });
    batch.set(db.collection('users').doc(uid), {
      name, email: `${uid}@example.com`, userType: 'instructor', signupRole: 'instructor',
      signupKind: kind, state, language: 'en', createdAt: now, status: 'active',
    });
    reviews.forEach((rating, r) => {
      batch.set(db.collection('instructors').doc(uid).collection('reviews').doc(`seed-student-${r + 1}`), {
        studentDisplayName: REVIEWERS[r % REVIEWERS.length], rating,
        comment: COMMENTS[(i + r) % COMMENTS.length], lastBookingId: `seed-booking-${n}-${r + 1}`,
        createdAt: now, updatedAt: now,
      });
    });
  });

  batch.set(db.collection('config').doc('instructors'), { launchStates: ['IL', 'TX'], updatedAt: now });
  for (const state of ['IL', 'TX', 'MD']) {
    batch.set(db.collection('instructorStats').doc(state), { listedCount: stats[state] || 0, updatedAt: now });
  }
  await batch.commit();

  if (AUTH_HOST) {
    for (let i = 0; i < ROWS.length; i++) {
      const uid = `seed-instr-${String(i + 1).padStart(2, '0')}`;
      const account = { email: `${uid}@example.com`, password: SEED_PASSWORD, displayName: ROWS[i][4], emailVerified: true };
      // Create only: updateUser with a password would revoke the sessions of
      // an app already signed in as this account.
      await admin.auth().getUser(uid).catch(() => admin.auth().createUser({ uid, ...account }));
    }
    console.log(`Auth accounts: seed-instr-01..${ROWS.length}@example.com`);

    // Instructors mid-signup (P3 wizard), one per kind: email verified, no
    // profile yet. Re-seeding resets them so the wizard can be replayed.
    for (const [uid, name, kind] of [
      ['seed-signup-school', 'Signup School', 'school'],
      ['seed-signup-instructor', 'Signup Instructor', 'schoolInstructor'],
    ]) {
      const account = { email: `${uid}@example.com`, password: SEED_PASSWORD, displayName: name, emailVerified: true };
      await admin.auth().getUser(uid).catch(() => admin.auth().createUser({ uid, ...account }));
      await db.collection('instructors').doc(uid).delete();
      await db.collection('instructorPrivate').doc(uid).delete();
      await db.collection('users').doc(uid).set({
        name, email: account.email, language: 'en', state: null,
        signupRole: 'instructor', signupKind: kind, createdAt: Timestamp.now(),
      });
      console.log(`Mid-signup instructor (${kind}): ${account.email}`);
    }

    // Students who open Инструкторы (P4). The simulator can't buy a plan, so
    // the subscription is written the way validatePurchaseReceipt /
    // createTrialSubscription would. Paid IL sees the listing, trial IL the
    // locked preview, paid MD «Скоро в Maryland». Dates are renewed on every
    // seed, so the plans never run out.
    for (const [uid, name, state, planType] of [
      ['seed-student-paid', 'Paid Student', 'IL', 'monthly'],
      ['seed-student-trial', 'Trial Student', 'IL', 'trial'],
      ['seed-student-md', 'Maryland Student', 'MD', 'monthly'],
    ]) {
      const account = { email: `${uid}@example.com`, password: SEED_PASSWORD, displayName: name, emailVerified: true };
      await admin.auth().getUser(uid).catch(() => admin.auth().createUser({ uid, ...account }));
      const trial = planType === 'trial';
      const ends = Timestamp.fromMillis(Date.now() + (trial ? 3 : 30) * 864e5);
      await db.collection('users').doc(uid).set({
        name, email: account.email, language: 'ru', state, signupRole: 'student',
        isActive: true, nextBillingDate: ends, createdAt: Timestamp.now(),
      }, { merge: true });
      await db.collection('subscriptions').doc(`${uid}-sub`).set({
        id: `${uid}-sub`, userId: uid, status: 'active', isActive: true, planType,
        packageId: trial ? 3 : 1, duration: trial ? 3 : 30, price: trial ? 0 : 9.99,
        ...(trial ? { trialUsed: 0, trialEndsAt: ends } : { platform: 'ios', environment: 'sandbox' }),
        nextBillingDate: ends, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
      console.log(`Student (${state}, ${planType}): ${account.email}`);
    }
  }
  // Chat threads (P6), written the way sendMessage would. Two days old, so
  // they don't count against the student's 5 new threads a day.
  const ago = (min) => Timestamp.fromMillis(Date.now() - min * 60e3);
  for (const [instructorUid, instructorName, kind, unlocked, messages] of [
    ['seed-instr-01', 'Lakeview Driving School', 'school', true, [
      ['seed-student-paid', 'Hello! Do you have a lesson on Saturday morning?', false, 2900],
      ['seed-instr-01', 'Yes, 9:00 works. Booked you in.', false, 2890],
      ['seed-instr-01', 'Call us any time: +1 312 555 0101', false, 2880],
    ]],
    ['seed-instr-03', 'Olena Kovalenko', 'schoolInstructor', false, [
      ['seed-student-paid', 'Здравствуйте! Можно урок на этой неделе?', false, 2950],
      ['seed-student-paid', 'Мой номер •••', true, 2949],
      ['seed-instr-03', 'Добрый день! Да, в четверг после 14:00.', false, 30],
    ]],
  ]) {
    const id = `seed-student-paid_${instructorUid}`;
    const ref = db.collection('conversations').doc(id);
    await db.recursiveDelete(ref);
    const last = messages[messages.length - 1];
    await ref.set({
      studentUid: 'seed-student-paid', instructorUid, participantUids: ['seed-student-paid', instructorUid],
      instructorName, instructorPhotoPath: null, instructorKind: kind, studentDisplayName: 'Paid S.',
      contactUnlocked: unlocked, lastMessageText: last[1], lastMessageAt: ago(last[3]), lastMessageSender: last[0],
      studentUnread: last[0] === instructorUid ? 1 : 0, instructorUnread: 0, createdAt: ago(2 * 1440),
    });
    for (const [senderUid, text, masked, min] of messages) {
      await ref.collection('messages').add({ senderUid, text, masked, createdAt: ago(min) });
    }
  }
  console.log('Chat threads: seed-student-paid with seed-instr-01 (unlocked) and seed-instr-03 (1 unread)');

  console.log(`Seeded ${ROWS.length} instructors; listed per state:`, stats, '; launchStates: IL, TX');
})().catch((e) => { console.error(e); process.exit(1); });
