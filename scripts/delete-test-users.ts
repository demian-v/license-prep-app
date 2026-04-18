/**
 * Delete pre-release test users from Firestore + Firebase Auth.
 *
 * KEEPS users with createdAt in [2026-04-15 00:00:00Z, 2026-04-16 23:59:59.999Z].
 * WIPES everyone else: users/{uid}, subscriptions where userId==uid,
 * savedQuestions/{uid}, and the Firebase Auth account.
 *
 * Default is dry-run. Pass --execute to actually delete.
 */

import * as fs from 'fs';
import * as path from 'path';
import * as admin from 'firebase-admin';

// ---------- Config ----------

const KEEP_WINDOW_START_ISO = '2026-04-15T00:00:00.000Z';
const KEEP_WINDOW_END_ISO = '2026-04-16T23:59:59.999Z';

const SERVICE_ACCOUNT_PATH = path.resolve(
  __dirname,
  'admin-service-account.json'
);
const MANIFEST_PATH = path.resolve(__dirname, 'deletion-manifest.json');

const FIRESTORE_BATCH_LIMIT = 500;
const AUTH_BATCH_LIMIT = 1000;

// ---------- Types ----------

interface Manifest {
  generatedAt: string;
  keepWindow: { start: string; end: string };
  toDelete: string[];
  toKeep: string[];
  unknownCreatedAt: string[];
  subscriptionsToDelete: string[]; // subscription doc IDs
  orphanSubscriptions: string[]; // subscription doc IDs whose userId has no user doc
}

// ---------- Main ----------

async function main() {
  const execute = process.argv.includes('--execute');

  console.log('='.repeat(70));
  console.log('  license-prep-app :: delete-test-users');
  console.log(`  Mode: ${execute ? 'EXECUTE (DESTRUCTIVE)' : 'DRY RUN'}`);
  console.log(`  Keep window (UTC): ${KEEP_WINDOW_START_ISO} → ${KEEP_WINDOW_END_ISO}`);
  console.log('='.repeat(70));

  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`ERROR: service account not found at ${SERVICE_ACCOUNT_PATH}`);
    process.exit(1);
  }

  const serviceAccount = require(SERVICE_ACCOUNT_PATH);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });
  console.log(`\nConnected to project: ${serviceAccount.project_id}`);

  const db = admin.firestore();
  const keepStart = admin.firestore.Timestamp.fromDate(new Date(KEEP_WINDOW_START_ISO));
  const keepEnd = admin.firestore.Timestamp.fromDate(new Date(KEEP_WINDOW_END_ISO));

  // Partition users
  console.log('\n[1/3] Scanning users collection...');
  const usersSnap = await db.collection('users').get();
  const toDelete: string[] = [];
  const toKeep: string[] = [];
  const unknownCreatedAt: string[] = [];

  for (const doc of usersSnap.docs) {
    const createdAt = doc.get('createdAt');
    if (!createdAt || !(createdAt instanceof admin.firestore.Timestamp)) {
      unknownCreatedAt.push(doc.id);
      continue;
    }
    const inWindow =
      createdAt.toMillis() >= keepStart.toMillis() &&
      createdAt.toMillis() <= keepEnd.toMillis();
    if (inWindow) toKeep.push(doc.id);
    else toDelete.push(doc.id);
  }

  console.log(`  total users: ${usersSnap.size}`);
  console.log(`  KEEP (in window):       ${toKeep.length}`);
  console.log(`  DELETE (outside window): ${toDelete.length}`);
  console.log(`  UNKNOWN createdAt (kept): ${unknownCreatedAt.length}`);

  // Gather subscriptions to delete (userId ∈ toDelete) + orphans
  console.log('\n[2/3] Scanning subscriptions collection...');
  const subsSnap = await db.collection('subscriptions').get();
  const deleteSet = new Set(toDelete);
  const keepSet = new Set([...toKeep, ...unknownCreatedAt]);
  const subscriptionsToDelete: string[] = [];
  const orphanSubscriptions: string[] = [];

  for (const doc of subsSnap.docs) {
    const userId = doc.get('userId');
    if (typeof userId !== 'string') {
      orphanSubscriptions.push(doc.id);
      continue;
    }
    if (deleteSet.has(userId)) subscriptionsToDelete.push(doc.id);
    else if (!keepSet.has(userId)) orphanSubscriptions.push(doc.id);
  }

  console.log(`  total subscriptions: ${subsSnap.size}`);
  console.log(`  will delete (owner in DELETE set): ${subscriptionsToDelete.length}`);
  console.log(`  orphans (userId has no user doc, NOT deleted): ${orphanSubscriptions.length}`);

  // Write manifest
  const manifest: Manifest = {
    generatedAt: new Date().toISOString(),
    keepWindow: { start: KEEP_WINDOW_START_ISO, end: KEEP_WINDOW_END_ISO },
    toDelete,
    toKeep,
    unknownCreatedAt,
    subscriptionsToDelete,
    orphanSubscriptions,
  };
  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2));
  console.log(`\nManifest written: ${MANIFEST_PATH}`);

  // Sample output
  console.log('\nSample (first 10 UIDs per bucket):');
  console.log('  KEEP  :', toKeep.slice(0, 10));
  console.log('  DELETE:', toDelete.slice(0, 10));
  if (unknownCreatedAt.length > 0) {
    console.log('  UNKNOWN createdAt:', unknownCreatedAt.slice(0, 10));
  }

  if (!execute) {
    console.log('\nDRY RUN complete. No changes made.');
    console.log('Review the manifest, then re-run with --execute to perform deletion.');
    return;
  }

  // ---------- EXECUTE ----------
  await runExecute({
    toDelete,
    subscriptionsToDelete,
    db,
  });
}

async function runExecute(args: {
  toDelete: string[];
  subscriptionsToDelete: string[];
  db: admin.firestore.Firestore;
}) {
  const { toDelete, subscriptionsToDelete, db } = args;

  const logPath = path.resolve(
    __dirname,
    `deletion-log-${timestampStamp()}.txt`
  );
  const logStream = fs.createWriteStream(logPath, { flags: 'a' });
  const log = (msg: string) => {
    const line = `[${new Date().toISOString()}] ${msg}`;
    console.log(line);
    logStream.write(line + '\n');
  };

  console.log('\n' + '!'.repeat(70));
  console.log('  WARNING: about to permanently delete data.');
  console.log(`  Users to delete:        ${toDelete.length}`);
  console.log(`  Subscriptions to delete: ${subscriptionsToDelete.length}`);
  console.log(`  Log file: ${logPath}`);
  console.log('  Starting in 5 seconds... Ctrl+C to abort.');
  console.log('!'.repeat(70));
  await sleep(5000);

  log(`EXECUTE start. ${toDelete.length} users, ${subscriptionsToDelete.length} subscriptions.`);

  // 1. Delete subscriptions (batched)
  log('Step 1/3: deleting subscriptions...');
  const subFailures = await deleteDocsByIds(
    db,
    'subscriptions',
    subscriptionsToDelete,
    log
  );

  // 2. Delete savedQuestions + users together (2 writes per uid → max 250 uids/batch)
  log('Step 2/3: deleting savedQuestions + users...');
  const sqFailures: string[] = [];
  const userFailures: string[] = [];
  const UID_CHUNK = Math.floor(FIRESTORE_BATCH_LIMIT / 2);
  for (let i = 0; i < toDelete.length; i += UID_CHUNK) {
    const chunk = toDelete.slice(i, i + UID_CHUNK);
    const batch = db.batch();
    for (const uid of chunk) {
      batch.delete(db.collection('savedQuestions').doc(uid));
      batch.delete(db.collection('users').doc(uid));
    }
    try {
      await batch.commit();
      log(`  batch ${i / UID_CHUNK + 1}: committed ${chunk.length} uid pairs`);
    } catch (err) {
      log(`  batch ${i / UID_CHUNK + 1}: FAILED - ${(err as Error).message}`);
      // Fall back to per-doc to isolate failures
      for (const uid of chunk) {
        try {
          await db.collection('savedQuestions').doc(uid).delete();
        } catch (e) {
          sqFailures.push(uid);
          log(`    savedQuestions/${uid} failed: ${(e as Error).message}`);
        }
        try {
          await db.collection('users').doc(uid).delete();
        } catch (e) {
          userFailures.push(uid);
          log(`    users/${uid} failed: ${(e as Error).message}`);
        }
      }
    }
  }

  // 3. Delete Firebase Auth users (up to 1000 per call)
  log('Step 3/3: deleting Firebase Auth accounts...');
  const authFailures: string[] = [];
  for (let i = 0; i < toDelete.length; i += AUTH_BATCH_LIMIT) {
    const chunk = toDelete.slice(i, i + AUTH_BATCH_LIMIT);
    try {
      const result = await admin.auth().deleteUsers(chunk);
      log(
        `  auth batch ${i / AUTH_BATCH_LIMIT + 1}: ` +
          `success=${result.successCount}, failure=${result.failureCount}`
      );
      for (const err of result.errors) {
        const uid = chunk[err.index];
        if (err.error.code === 'auth/user-not-found') {
          log(`    ${uid}: not found in Auth (ok)`);
        } else {
          authFailures.push(uid);
          log(`    ${uid}: ${err.error.code} - ${err.error.message}`);
        }
      }
    } catch (err) {
      log(`  auth batch ${i / AUTH_BATCH_LIMIT + 1}: FATAL ${(err as Error).message}`);
      authFailures.push(...chunk);
    }
  }

  // Summary
  log('');
  log('='.repeat(60));
  log('EXECUTE complete.');
  log(`  subscriptions deleted: ${subscriptionsToDelete.length - subFailures.length} / ${subscriptionsToDelete.length}`);
  log(`  users deleted:         ${toDelete.length - userFailures.length} / ${toDelete.length}`);
  log(`  savedQuestions deleted: up to ${toDelete.length} (non-existent docs are no-ops)`);
  log(`  auth accounts deleted: ${toDelete.length - authFailures.length} / ${toDelete.length}`);
  if (subFailures.length) log(`  subscription failures: ${subFailures.length}`);
  if (sqFailures.length) log(`  savedQuestions failures: ${sqFailures.length}`);
  if (userFailures.length) log(`  user doc failures: ${userFailures.length}`);
  if (authFailures.length) log(`  auth failures: ${authFailures.length}`);
  log('='.repeat(60));

  logStream.end();
  console.log(`\nLog written: ${logPath}`);
}

async function deleteDocsByIds(
  db: admin.firestore.Firestore,
  collection: string,
  ids: string[],
  log: (msg: string) => void
): Promise<string[]> {
  const failures: string[] = [];
  for (let i = 0; i < ids.length; i += FIRESTORE_BATCH_LIMIT) {
    const chunk = ids.slice(i, i + FIRESTORE_BATCH_LIMIT);
    const batch = db.batch();
    for (const id of chunk) batch.delete(db.collection(collection).doc(id));
    try {
      await batch.commit();
      log(`  ${collection} batch ${i / FIRESTORE_BATCH_LIMIT + 1}: ${chunk.length} deleted`);
    } catch (err) {
      log(`  ${collection} batch ${i / FIRESTORE_BATCH_LIMIT + 1}: FAILED ${(err as Error).message}`);
      for (const id of chunk) {
        try {
          await db.collection(collection).doc(id).delete();
        } catch (e) {
          failures.push(id);
          log(`    ${collection}/${id}: ${(e as Error).message}`);
        }
      }
    }
  }
  return failures;
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

function timestampStamp() {
  const d = new Date();
  const pad = (n: number) => n.toString().padStart(2, '0');
  return (
    `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}` +
    `-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('FATAL:', err);
    process.exit(1);
  });
