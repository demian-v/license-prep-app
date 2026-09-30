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
 *   users/{uid}                 userType:'instructor' (no Auth accounts — added when P2 needs sign-in)
 * Idempotent: a re-run overwrites the same ids.
 *
 * EMULATORS ONLY. Refuses to run unless FIRESTORE_EMULATOR_HOST is a local address.
 *
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp \
 *   node scripts/local/seed-instructors.js
 */
const admin = require('../../functions/node_modules/firebase-admin');

if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  console.error('REFUSING: FIRESTORE_EMULATOR_HOST is not a local address.');
  process.exit(1);
}

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
      photoUrl: null, photoApproved: false,
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
  console.log(`Seeded ${ROWS.length} instructors; listed per state:`, stats, '; launchStates: IL, TX');
})().catch((e) => { console.error(e); process.exit(1); });
