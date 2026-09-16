/**
 * LOCAL TOOLING — reads production Firestore and writes content JSON to .local-export/.
 *
 * READ-ONLY BY CONSTRUCTION: this script only ever calls .get(). It never calls
 * set/update/delete/add. Do not add writes here — this runs with a production
 * service account.
 *
 * Deliberately excludes every collection containing user data.
 */
const admin = require('../../functions/node_modules/firebase-admin');
const fs = require('fs');
const path = require('path');

const CONTENT_COLLECTIONS = [
  'quizQuestions', 'quizTopics', 'trafficRuleTopics', 'theoryModules',
  'practiceTests', 'roadSigns', 'roadSignCategories', 'licenseTypes',
  'subscriptionsType',
];

// Never exported: users, subscriptions, reports, progress, savedQuestions,
// subscriptionLogs, trialDevices, processedWebhooks, counters.

const OUT = path.join(__dirname, '../../.local-export');

admin.initializeApp({
  credential: admin.credential.cert(require('../../functions/service-account.json')),
});
const db = admin.firestore();

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const summary = [];
  for (const name of CONTENT_COLLECTIONS) {
    const snap = await db.collection(name).get();
    const docs = {};
    snap.forEach((doc) => { docs[doc.id] = doc.data(); });
    const file = path.join(OUT, `${name}.json`);
    fs.writeFileSync(file, JSON.stringify(docs, null, 2));
    const kb = (fs.statSync(file).size / 1024).toFixed(1);
    summary.push({ collection: name, docs: snap.size, kb: Number(kb) });
    console.log(`  ${name.padEnd(20)} ${String(snap.size).padStart(5)} docs  ${kb} KB`);
  }
  fs.writeFileSync(path.join(OUT, '_manifest.json'),
    JSON.stringify({ exportedAt: new Date().toISOString(), source: 'licenseprepapp', readOnly: true, collections: summary }, null, 2));
  console.log(`\nTotal: ${summary.reduce((a, c) => a + c.docs, 0)} documents`);
  process.exit(0);
})().catch((e) => { console.error('EXPORT FAILED:', e.message); process.exit(1); });
