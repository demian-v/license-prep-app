/**
 * LOCAL TOOLING — bump the content cache-bust version (risk #47).
 *
 * Writing `contentMeta/current.version` is what makes a content correction
 * reach devices now instead of whenever their 24 h cache happens to expire.
 * Every app records the version alongside its cached content and drops that
 * cache when the number changes.
 *
 * This is the local equivalent of the step an operator has to take in
 * production after editing content. There is no admin UI for it yet (risk #53).
 *
 * Refuses to run outside the emulator.
 *
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/local/bump-content-version.js
 */
const admin = require('../../functions/node_modules/firebase-admin');

if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  console.error('REFUSING: FIRESTORE_EMULATOR_HOST is not a local address.');
  process.exit(1);
}

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'licenseprepapp' });
const db = admin.firestore();
const ref = db.collection('contentMeta').doc('current');

(async () => {
  const next = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists && typeof snap.data().version === 'number'
      ? Math.floor(snap.data().version)
      : 0;
    const bumped = current + 1;
    tx.set(ref, { version: bumped, updatedAt: new Date().toISOString() }, { merge: true });
    return bumped;
  });

  console.log(`Content version is now ${next}. Devices will drop cached content on next launch.`);
  process.exit(0);
})().catch((err) => { console.error(err); process.exit(1); });
