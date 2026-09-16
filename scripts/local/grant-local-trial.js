/**
 * LOCAL TOOLING — give a local emulator user a trial entitlement.
 *
 * The iOS Simulator can never obtain one through the app: createTrialSubscription
 * throws `failed-precondition` unless `isPhysicalDevice === true`, which is the
 * anti-abuse gate working as designed. This writes what a real device would have
 * received, so entitlement-gated screens can be exercised locally.
 *
 * Mirrors createTrialSubscription exactly, including the users/{uid} entitlement
 * mirror. Refuses to run outside the emulator.
 *
 *   node scripts/local/grant-local-trial.js <email>
 */
const admin = require('../../functions/node_modules/firebase-admin');

if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  console.error('REFUSING: FIRESTORE_EMULATOR_HOST is not a local address.');
  process.exit(1);
}

const email = process.argv[2];
if (!email) { console.error('usage: grant-local-trial.js <email>'); process.exit(1); }

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'licenseprepapp' });
const db = admin.firestore();

(async () => {
  const snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (snap.empty) { console.error(`No user with email ${email}`); process.exit(1); }
  const userId = snap.docs[0].id;

  const trialEnd = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);
  const subRef = db.collection('subscriptions').doc();
  const batch = db.batch();
  batch.set(subRef, {
    id: subRef.id, userId,
    packageId: 3, status: 'active', isActive: true,
    planType: 'trial', duration: 3, price: 0, trialUsed: 0,
    trialEndsAt: admin.firestore.Timestamp.fromDate(trialEnd),
    nextBillingDate: admin.firestore.Timestamp.fromDate(trialEnd),
    deviceIdHash: 'local-simulator-' + '0'.repeat(48),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(db.collection('users').doc(userId), {
    isActive: true,
    nextBillingDate: admin.firestore.Timestamp.fromDate(trialEnd),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  await batch.commit();

  console.log(`Granted 3-day trial to ${email} (${userId}), ends ${trialEnd.toISOString().slice(0, 10)}`);
  process.exit(0);
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
