/**
 * LOCAL TOOLING — loads .local-export/*.json into the Firestore EMULATOR.
 *
 * Refuses to run unless FIRESTORE_EMULATOR_HOST is set and the project id
 * starts with `demo-`, so it can never write to a real project.
 */
const admin = require('../../functions/node_modules/firebase-admin');
const fs = require('fs');
const path = require('path');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-driveusa';
const IN = path.join(__dirname, '../../.local-export');

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('REFUSING: FIRESTORE_EMULATOR_HOST is not set.');
  process.exit(1);
}
if (!PROJECT.startsWith('demo-')) {
  console.error(`REFUSING: project "${PROJECT}" is not a demo- project.`);
  process.exit(1);
}

admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();

(async () => {
  console.log(`Seeding ${PROJECT} at ${process.env.FIRESTORE_EMULATOR_HOST}\n`);
  let grand = 0;
  for (const file of fs.readdirSync(IN).filter((f) => f.endsWith('.json') && !f.startsWith('_'))) {
    const name = path.basename(file, '.json');
    const docs = JSON.parse(fs.readFileSync(path.join(IN, file), 'utf8'));
    const entries = Object.entries(docs);
    for (let i = 0; i < entries.length; i += 450) {
      const batch = db.batch();
      for (const [id, data] of entries.slice(i, i + 450)) {
        batch.set(db.collection(name).doc(id), revive(data));
      }
      await batch.commit();
    }
    grand += entries.length;
    console.log(`  ${name.padEnd(20)} ${String(entries.length).padStart(5)} docs`);
  }
  console.log(`\nSeeded ${grand} documents.`);
  process.exit(0);
})().catch((e) => { console.error('SEED FAILED:', e.message); process.exit(1); });

/** Turn the exporter's serialised Timestamps back into real ones. */
function revive(v) {
  if (v === null || typeof v !== 'object') return v;
  if (Array.isArray(v)) return v.map(revive);
  if (v._seconds !== undefined && v._nanoseconds !== undefined) {
    return new admin.firestore.Timestamp(v._seconds, v._nanoseconds);
  }
  const out = {};
  for (const [k, val] of Object.entries(v)) out[k] = revive(val);
  return out;
}
