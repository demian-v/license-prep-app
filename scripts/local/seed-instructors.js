/**
 * LOCAL TOOLING — seed the Instructors marketplace into the Firestore EMULATOR.
 *
 * Plan v2 P1 (vault raw/drive_usa/2026-09-30-Instructors Plan v2.md). Writes:
 *   config/instructors          { launchStates: ['IL', 'TX'] }   (owner decision 2026-09-30)
 *   instructors/{uid}           24 profiles across IL / TX / MD, every stage and kind,
 *                               plus one deactivated and one suspended (listed:false)
 *   instructorPrivate/{uid}     fictional 555-01xx phones, example.com emails
 *   instructors/{uid}/reviews   a few reviews, with ratingSum/Count/Avg kept consistent and an
 *                               opaque reviewId each (P8); seed-student-paid's own reviews are
 *                               removed on every run, so the numbers stay exact
 *   instructorStats/{state}     listedCount per state
 *   users/{uid}                 userType:'instructor'
 *   Auth accounts               seed-instr-NN@example.com / SEED_PASSWORD below, when
 *                               FIREBASE_AUTH_EMULATOR_HOST is set (sign in as an instructor),
 *                               plus seed-signup-school@ / seed-signup-instructor@example.com, instructors mid-signup,
 *                               and students seed-student-paid@ (IL) / -trial@ (IL) / -md@ (MD, paid)
 *   conversations/{id}          P6 chat: seed-student-paid with Lakeview (unlocked, as if
 *                               booked: contacts in the header) and Olena (one unread reply,
 *                               one masked message); reset on every run
 *   bookings/{id}, bookingSlots P7: seed-student-paid's lessons with Lakeview (completed, late-cancelled,
 *                               refunded by the school, two upcoming) and Northside (one upcoming,
 *                               contacts unlocked, no messages yet), plus a pending hold past its
 *                               15 minutes for the expiry sweep and a Northside lesson that ended
 *                               yesterday but is still confirmed (fire markBookingsCompleted → the
 *                               review push); reset on every run. P9: every seed lesson is
 *                               `paymentProvider: 'emulator'` (no Stripe money): the oldest Lakeview
 *                               lesson is paid out, one held yesterday waits for its payout (48 h;
 *                               the student can still report a no-show), and the late cancel is due
 *                               (fire releaseInstructorPayouts → paid out without Stripe)
 *   admins/seed-admin, reports  P10a: the dashboard's admin (seed-admin@example.com, Auth emulator only),
 *                               reports of every kind, two no-show reports, two card disputes, a
 *                               school-cancellations alert, ~150 past lessons for Insights (a student
 *                               with no account; schools the app demos don't use); reset on every run
 *   SEED_STRIPE_ACCOUNT_ID      optional, P9: a Stripe TEST connected account (acct_…) already
 *                               onboarded through the app as seed-instr-01. Emulator data does not
 *                               survive a restart, so this re-attaches it to Lakeview on every seed
 *                               instead of onboarding again. Never commit the id.
 * Idempotent: a re-run overwrites the same ids.
 *
 * EMULATORS ONLY. Refuses to run unless FIRESTORE_EMULATOR_HOST is a local address.
 *
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *   GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-instructors.js
 */
const admin = require('../../functions/node_modules/firebase-admin');
// Built by `npm run build` in functions/ — the same wall-clock maths as the server.
const { wallClock, wallToUtc, weekDay, addDays, minutesOf } = require('../../functions/lib/zone');

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
    // P9: re-attach a test connected account onboarded once in the app.
    const stripeAccountId = uid === 'seed-instr-01' && /^acct_[A-Za-z0-9]+$/.test(process.env.SEED_STRIPE_ACCOUNT_ID || '')
      ? process.env.SEED_STRIPE_ACCOUNT_ID : null;
    batch.set(db.collection('instructorPrivate').doc(uid), {
      phone: `+1 312 555 01${n}`, contactEmail: `${uid}@example.com`,
      stripeAccountId, stripePendingAccountId: stripeAccountId,
      identitySessionIds: [], biometricConsentAt: stage >= 1 ? now : null,
      licenseNumber: kind === 'schoolInstructor' ? `${state}-DI-${5000 + i}` : null,
      moderation: { photo: { status: 'none' } },
    });
    batch.set(db.collection('users').doc(uid), {
      name, email: `${uid}@example.com`, userType: 'instructor', signupRole: 'instructor',
      signupKind: kind, state, language: 'en', createdAt: now, status: 'active',
    });
    // A review the paid student wrote in the app would no longer match the
    // numbers just reset above.
    batch.delete(db.collection('instructors').doc(uid).collection('reviews').doc('seed-student-paid'));
    reviews.forEach((rating, r) => {
      batch.set(db.collection('instructors').doc(uid).collection('reviews').doc(`seed-student-${r + 1}`), {
        reviewId: `seedrev${n}x${r + 1}`, studentDisplayName: REVIEWERS[r % REVIEWERS.length], rating,
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

  // Bookings (P7), written the way createBooking / confirmBooking /
  // cancelBooking would. Each starts at the first open half hour of its day
  // in the school's hours, Chicago time; fees as in plan v2 §9.1 (the first
  // fee-bearing lesson with a school is 'first', later ones 5%, min $1.50).
  // Only the seed's own bookings and their slots; lessons booked in the app stay.
  for (const [coll, field] of [['bookings', admin.firestore.FieldPath.documentId()], ['bookingSlots', 'bookingId']]) {
    const old = await db.collection(coll).where(field, '>=', 'seed-booking-').where(field, '<', 'seed-booking.').get();
    await Promise.all(old.docs.map((d) => d.ref.delete()));
  }
  const tz = 'America/Chicago';
  const today = wallClock(Date.now(), tz).date;
  const availabilityOf = (i) => (i % 3 === 0 ? { ...WEEKDAYS, ...WEEKENDS } : i % 3 === 1 ? WEEKDAYS : {});
  // The first local day `days` from today (or later) that has hours.
  const lessonStart = (row, days) => {
    for (let d = days; ; d += Math.sign(days) || 1) {
      const date = addDays(today, d);
      const first = (availabilityOf(row)[weekDay(date)] || [])[0];
      if (first) return wallToUtc(date, minutesOf(first.start), tz);
    }
  };
  const fees = (rateUsd, minutes, feeKind) => {
    const lessonCents = Math.round((rateUsd * 100 * minutes) / 60);
    const platformFeeCents = feeKind === 'first' ? Math.round(lessonCents * 0.25) : Math.max(Math.round(lessonCents * 0.05), 150);
    return { lessonCents, platformFeeCents, totalCents: lessonCents + platformFeeCents, feeKind };
  };
  const SCHOOLS = { 'seed-instr-01': 0, 'seed-instr-04': 3 }; // ROWS index
  for (const [id, instructorUid, days, minutes, feeKind, status, extra] of [
    // P9: paid out 48 h after it ended.
    ['seed-booking-lv-1', 'seed-instr-01', -12, 60, 'first', 'payout_released', {}],
    // Held yesterday: its payout waits 48 h, and a no-show can still be reported.
    ['seed-booking-lv-6', 'seed-instr-01', -1, 60, 'later', 'completed', {}],
    ['seed-booking-lv-2', 'seed-instr-01', -5, 60, 'later', 'late_cancelled', { cancelledBy: 'student' }],
    ['seed-booking-lv-3', 'seed-instr-01', -3, 90, 'later', 'refunded', { cancelledBy: 'instructor' }],
    ['seed-booking-lv-4', 'seed-instr-01', 2, 90, 'later', 'confirmed', {}],
    ['seed-booking-lv-5', 'seed-instr-01', 6, 60, 'later', 'confirmed', {}],
    // Ended yesterday, not yet swept: firing markBookingsCompleted completes
    // it and sends «Как прошёл урок?» (P8).
    ['seed-booking-ns-0', 'seed-instr-04', -1, 60, 'first', 'confirmed', {}],
    ['seed-booking-ns-1', 'seed-instr-04', 3, 60, 'later', 'confirmed', {}],
    ['seed-booking-ns-2', 'seed-instr-04', 4, 60, 'later', 'pending_payment', {}],
  ]) {
    const row = ROWS[SCHOOLS[instructorUid]];
    const startMs = lessonStart(SCHOOLS[instructorUid], days);
    const endMs = startMs + minutes * 60e3;
    const at = Timestamp.fromMillis(Math.min(Date.now(), startMs) - 2 * 864e5);
    await db.collection('bookings').doc(id).set({
      studentUid: 'seed-student-paid', instructorUid, studentDisplayName: 'Paid S.', instructorName: row[4],
      schoolAddress: `${100 + SCHOOLS[instructorUid]} Main St, ${row[1]}, ${row[0]}`,
      startAt: Timestamp.fromMillis(startMs), durationMinutes: minutes, timezone: tz,
      localDate: wallClock(startMs, tz).date,
      localTime: new Date(Date.UTC(2000, 0, 1, 0, wallClock(startMs, tz).minutes)).toISOString().slice(11, 16),
      ...fees(row[7], minutes, feeKind), status, paymentProvider: 'emulator',
      ...(status === 'confirmed' ? { completeAfter: Timestamp.fromMillis(endMs), confirmedAt: at } : {}),
      ...(status === 'completed' ? { confirmedAt: at, completedAt: Timestamp.fromMillis(endMs), payoutReleaseAt: Timestamp.fromMillis(endMs + 48 * 3600e3) } : {}),
      ...(status === 'payout_released' ? { confirmedAt: at, completedAt: Timestamp.fromMillis(endMs), payoutReleasedAt: Timestamp.fromMillis(endMs + 48 * 3600e3), stripeTransferId: null } : {}),
      ...(status === 'late_cancelled' ? { payoutReleaseAt: Timestamp.fromMillis(startMs + 48 * 3600e3) } : {}),
      // A hold that ran out a minute ago: the 5-minute sweep expires it.
      ...(status === 'pending_payment' ? { expiresAt: Timestamp.fromMillis(Date.now() - 60e3) } : {}),
      ...(extra.cancelledBy ? { cancelledBy: extra.cancelledBy, cancelledAt: Timestamp.fromMillis(startMs - (extra.cancelledBy === 'student' ? 5 : 30) * 3600e3) } : {}),
      createdAt: at, updatedAt: at,
    });
    // Locked half hours: upcoming and pending lessons, and a late cancel (kept).
    if (['confirmed', 'pending_payment', 'late_cancelled'].includes(status)) {
      for (let ms = startMs; ms < endMs; ms += 30 * 60e3) {
        const key = new Date(ms).toISOString().slice(0, 16).replace(/[-:]/g, '');
        await db.collection('bookingSlots').doc(`${instructorUid}_${key}`).set({ instructorUid, bookingId: id, startAt: Timestamp.fromMillis(ms) });
      }
    }
  }
  // Northside was booked without a message first: confirmBooking made the
  // thread, unlocked, with nothing in it yet.
  const ns = db.collection('conversations').doc('seed-student-paid_seed-instr-04');
  await db.recursiveDelete(ns);
  await ns.set({
    studentUid: 'seed-student-paid', instructorUid: 'seed-instr-04', participantUids: ['seed-student-paid', 'seed-instr-04'],
    instructorName: 'Northside Auto Academy', instructorPhotoPath: null, instructorKind: 'school', studentDisplayName: 'Paid S.',
    contactUnlocked: true, lastMessageText: '', lastMessageAt: ago(3 * 1440), lastMessageSender: null,
    studentUnread: 0, instructorUnread: 0, createdAt: ago(3 * 1440),
  });
  console.log('Bookings: seed-student-paid with seed-instr-01 (6: paid out, awaiting payout, late cancel due, refunded, 2 upcoming) and seed-instr-04 (1 ended but confirmed, 1 upcoming, 1 expiring hold)');

  // P10a — the admin dashboard (admin/). An admin account, and something on
  // every column of its board. All ids start with seed-booking- /
  // seed-report-, so a re-run resets them; nothing here is real data.
  if (AUTH_HOST) {
    const account = { email: 'seed-admin@example.com', password: SEED_PASSWORD, displayName: 'Seed Admin', emailVerified: true };
    await admin.auth().getUser('seed-admin').catch(() => admin.auth().createUser({ uid: 'seed-admin', ...account }));
    await db.collection('admins').doc('seed-admin').set({ note: 'emulator seed only', grantedAt: now });
    console.log(`Admin (dashboard): ${account.email}`);
  }
  const daysAgo = (d) => Timestamp.fromMillis(Date.now() - d * 864e5);
  const oldReports = await db.collection('reports').where(admin.firestore.FieldPath.documentId(), '>=', 'seed-report-')
    .where(admin.firestore.FieldPath.documentId(), '<', 'seed-report.').get();
  await Promise.all(oldReports.docs.map((d) => d.ref.delete()));
  const lvThread = db.collection('conversations').doc('seed-student-paid_seed-instr-01');
  const phoneMsg = (await lvThread.collection('messages').where('text', '==', 'Call us any time: +1 312 555 0101').limit(1).get()).docs[0];
  const report = (id, doc) => db.collection('reports').doc(id).set({ userId: 'seed-student-paid', language: 'ru', state: 'IL', ...doc });
  // Northside's 3-star review, reported as written; its author softened it since.
  await report('seed-report-review', {
    contentType: 'review', reason: 'harassment', entity: { instructorUid: 'seed-instr-04', reviewId: 'seedrev04x4' },
    review: { rating: 1, comment: 'Worst school ever, the instructor yelled at me the whole lesson.' },
    message: 'Insulting, and not what happened.', status: 'open', createdAt: daysAgo(0.2),
  });
  await report('seed-report-message', {
    contentType: 'message', reason: 'spam', entity: { conversationId: lvThread.id, messageId: phoneMsg ? phoneMsg.id : 'missing' },
    message: 'Keeps asking me to call outside the app.', status: 'open', createdAt: daysAgo(1.1),
  });
  await report('seed-report-instructor', {
    contentType: 'instructor', reason: 'fake_profile', entity: { instructorUid: 'seed-instr-17' },
    message: "The name and photo don't match the school's website.", status: 'in_review', createdAt: daysAgo(2.3),
  });
  await report('seed-report-question', {
    contentType: 'quiz_question', reason: 'translation', entity: { questionId: 'IL_q_0142', path: 'questions/IL_q_0142' },
    message: 'The Spanish answer B says the opposite of the English one.', language: 'es', status: 'open', createdAt: daysAgo(4),
  });
  await report('seed-report-theory', {
    contentType: 'theory_section', reason: 'image', entity: { topicDocId: 'IL_t_signs', sectionIndex: 3, path: 'trafficRuleTopics/IL_t_signs' },
    status: 'dismissed', resolution: 'dismissed', resolvedAt: daysAgo(1), resolvedBy: 'seed-admin', createdAt: daysAgo(6),
  });

  // Lessons for the board and for Insights. History goes to a student with no
  // account and to schools the app demos don't use, so Lakeview's and
  // Northside's lists stay as described above.
  const at10 = (rowIndex, d) => wallToUtc(addDays(wallClock(Date.now(), ROWS[rowIndex][2]).date, d), 600, ROWS[rowIndex][2]);
  const lesson = async (id, rowIndex, d, minutes, feeKind, status, extra = {}) => {
    const row = ROWS[rowIndex];
    const uid = `seed-instr-${String(rowIndex + 1).padStart(2, '0')}`;
    const startMs = at10(rowIndex, d);
    const created = Timestamp.fromMillis(Math.min(Date.now() - 3600e3, startMs - (2 + (Math.abs(d) % 5)) * 864e5));
    await db.collection('bookings').doc(id).set({
      studentUid: 'seed-student-history', instructorUid: uid, studentDisplayName: REVIEWERS[Math.abs(d) % REVIEWERS.length],
      instructorName: row[4], startAt: Timestamp.fromMillis(startMs), durationMinutes: minutes, timezone: row[2],
      localDate: wallClock(startMs, row[2]).date, localTime: '10:00', ...fees(row[7], minutes, feeKind), status,
      paymentProvider: 'emulator', confirmedAt: created, createdAt: created, updatedAt: created, ...extra,
    });
    return startMs + minutes * 60e3;
  };
  // No-show reports (disputed): one from seed-student-paid with Northside, so
  // the student's side can be checked after a decision; one waiting longer.
  {
    const startMs = lessonStart(3, -2);
    const endMs = startMs + 60 * 60e3;
    await db.collection('bookings').doc('seed-booking-ns-3').set({
      studentUid: 'seed-student-paid', instructorUid: 'seed-instr-04', studentDisplayName: 'Paid S.', instructorName: 'Northside Auto Academy',
      schoolAddress: '103 Main St, Chicago, IL', startAt: Timestamp.fromMillis(startMs), durationMinutes: 60, timezone: tz,
      localDate: wallClock(startMs, tz).date, localTime: new Date(Date.UTC(2000, 0, 1, 0, wallClock(startMs, tz).minutes)).toISOString().slice(11, 16),
      ...fees(75, 60, 'later'), status: 'disputed', paymentProvider: 'emulator', noShowReason: 'instructor_no_show',
      noShowReportedAt: Timestamp.fromMillis(endMs + 3 * 3600e3), completedAt: Timestamp.fromMillis(endMs),
      payoutReleaseAt: Timestamp.fromMillis(endMs + 48 * 3600e3), createdAt: daysAgo(5), updatedAt: Timestamp.fromMillis(endMs + 3 * 3600e3),
    });
  }
  {
    const endMs = await lesson('seed-booking-h-ns-1', 10, -4, 90, 'later', 'disputed', { noShowReason: 'lesson_not_given' });
    await db.collection('bookings').doc('seed-booking-h-ns-1').update({
      noShowReportedAt: Timestamp.fromMillis(endMs + 20 * 3600e3), completedAt: Timestamp.fromMillis(endMs),
      payoutReleaseAt: Timestamp.fromMillis(endMs + 48 * 3600e3),
    });
  }
  // Card disputes: one lost (the school's payout cancelled — pay by hand or
  // not), one Stripe is still running.
  {
    const endMs = await lesson('seed-booking-h-cd-1', 13, -9, 60, 'later', 'completed', {
      disputeStatus: 'lost', disputeReason: 'fraudulent', disputeAmountCents: 7350, stripeDisputeId: 'dp_seed_lost',
    });
    await db.collection('bookings').doc('seed-booking-h-cd-1').update({ completedAt: Timestamp.fromMillis(endMs), payoutCancelledAt: daysAgo(1.5) });
    await lesson('seed-booking-h-cd-2', 15, -6, 60, 'later', 'completed', {
      disputeStatus: 'open', disputeReason: 'product_not_received', disputeAmountCents: 8925, stripeDisputeId: 'dp_seed_open',
      payoutReleaseAt: daysAgo(-2),
    });
  }
  // Three school cancellations in 30 days (Bayou City) and the alert
  // noteSchoolCancellation (functions/src/admin.ts) writes for them.
  for (const [n, d] of [[1, 3], [2, 9], [3, 17]]) {
    await lesson(`seed-booking-h-cx-${n}`, 10, d, 60, 'later', 'refunded', { cancelledBy: 'instructor', cancelledAt: daysAgo(n * 4) });
  }
  await db.collection('reports').doc('alert_cancellations_seed-instr-11').set({
    contentType: 'school_cancellations', reason: 'cancellations', entity: { instructorUid: 'seed-instr-11' },
    count: 3, userId: 'system', status: 'open', createdAt: daysAgo(4), updatedAt: daysAgo(4),
  });
  // 90 days of lessons across six schools: mostly paid out (a few late),
  // some refunded, a few late cancels.
  const HISTORY = [5, 10, 13, 15, 18, 20];
  let h = 0;
  for (let d = 88; d >= 3; d -= 1) {
    for (let k = 0; k < 1 + ((d * 7) % 3); k++) {
      h += 1;
      const rowIndex = HISTORY[(d + k) % HISTORY.length];
      const roll = (d * 13 + k * 7) % 20;
      const status = roll < 2 ? 'refunded' : roll < 3 ? 'late_cancelled' : 'payout_released';
      const minutes = [60, 90, 120][(d + k) % 3];
      const endMs = at10(rowIndex, -d) + minutes * 60e3;
      const lateHours = roll === 19 ? 30 : 1;
      await lesson(`seed-booking-h-${String(h).padStart(3, '0')}`, rowIndex, -d, minutes, h % 6 === 1 ? 'first' : 'later', status,
        status === 'payout_released' ? { completedAt: Timestamp.fromMillis(endMs), payoutReleasedAt: Timestamp.fromMillis(endMs + (48 + lateHours) * 3600e3) }
          : status === 'refunded' ? { cancelledBy: roll === 0 ? 'instructor' : 'student', cancelledAt: Timestamp.fromMillis(endMs - 72 * 3600e3), refundedAt: Timestamp.fromMillis(endMs - 72 * 3600e3) }
            : { cancelledBy: 'student', cancelledAt: Timestamp.fromMillis(endMs - 10 * 3600e3), payoutReleasedAt: Timestamp.fromMillis(endMs + 47 * 3600e3) });
    }
  }
  console.log(`Admin board: 5 reports (review, message, instructor, question, theory dismissed), 2 no-show reports, 2 card disputes, 1 cancellations alert; ${h} past lessons for Insights`);

  console.log(`Seeded ${ROWS.length} instructors; listed per state:`, stats, '; launchStates: IL, TX');
})().catch((e) => { console.error(e); process.exit(1); });
