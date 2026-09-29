/**
 * LOCAL TOOLING — load the result-page memes into the emulators.
 *
 * Uploads every picture in design/memes/own/webp/ (made by
 * design/memes/own/_src/to_webp.py) to the Storage emulator at
 * result_memes/<bucket>/<id>.webp and writes one result_memes/{id} document
 * per picture: { bucket, storagePath, width, height, bytes, active, order }.
 * Idempotent: a re-run overwrites the same ids.
 *
 * EMULATORS ONLY. Refuses to run unless both FIRESTORE_EMULATOR_HOST and
 * FIREBASE_STORAGE_EMULATOR_HOST point at this machine. Loading the live
 * project (licenseprepapp) needs the owner's explicit OK and is not what this
 * script is for.
 *
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *   FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 \
 *   GCLOUD_PROJECT=licenseprepapp \
 *   node scripts/local/seed-result-memes.js
 */
const fs = require('fs');
const path = require('path');
const admin = require('../../functions/node_modules/firebase-admin');

const LOCAL = /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/;
if (!LOCAL.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  console.error('REFUSING: FIRESTORE_EMULATOR_HOST is not a local address.');
  process.exit(1);
}
if (!LOCAL.test(process.env.FIREBASE_STORAGE_EMULATOR_HOST || '')) {
  console.error('REFUSING: FIREBASE_STORAGE_EMULATOR_HOST is not a local address.');
  process.exit(1);
}

const BUCKET = process.env.STORAGE_BUCKET || 'licenseprepapp.firebasestorage.app';
const ROOT = path.join(__dirname, '../../design/memes/own');
const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, 'webp/manifest.json'), 'utf8'));

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'licenseprepapp', storageBucket: BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();

(async () => {
  let bytes = 0;
  for (const m of manifest) {
    const file = fs.readFileSync(path.join(ROOT, m.file));
    await bucket.file(m.storagePath).save(file, {
      contentType: 'image/webp',
      metadata: { cacheControl: 'public, max-age=31536000' },
    });
    await db.collection('result_memes').doc(m.id).set({
      bucket: m.bucket,
      storagePath: m.storagePath,
      width: m.width,
      height: m.height,
      bytes: m.bytes,
      active: true,
      order: m.order,
    });
    bytes += m.bytes;
  }
  const perBucket = manifest.reduce((acc, m) => ({ ...acc, [m.bucket]: (acc[m.bucket] || 0) + 1 }), {});
  console.log(`Seeded ${manifest.length} result memes (${Math.round(bytes / 1024)} KB) into ${BUCKET}:`, perBucket);
})().catch((e) => { console.error(e); process.exit(1); });
