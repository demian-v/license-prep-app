/**
 * Risk #15 — the index definitions are never deployed, and were incomplete.
 *
 * `firebase.json` declared `firestore.rules` but no `firestore.indexes`, so
 * `firebase deploy` never shipped an index. Every composite index in production
 * was created by hand from a console error link, and the repo's
 * `firestore.indexes.json` listed three — none of which actually matched what
 * production held.
 *
 * IMPORTANT, and the reason this file exists in this shape: the entries below
 * were taken from `firebase firestore:indexes --project licenseprepapp` on
 * 2026-09-17, not derived from reading the query code. An earlier version of
 * this file WAS derived from the code, and 8 of production's 11 indexes did not
 * match it — including the subscriptionLogs one every purchase depends on,
 * which SESSION.md wrongly recorded as (userId, timestamp, action) when
 * production actually holds (action, userId, timestamp).
 *
 * That matters because `firebase deploy` offers to DELETE indexes present in
 * the project and absent from the file, and does so without asking under
 * `--force`. So the invariant this file protects is: **every index production
 * holds is declared here**. Deleting an entry is how a deploy drops a working
 * production index.
 *
 * The Firestore emulator does not enforce composite indexes, so this is the
 * only place the gap is visible locally.
 */
import * as fs from 'fs';
import * as path from 'path';

const REPO_ROOT = path.join(__dirname, '../../..');

const firebaseJson = JSON.parse(
  fs.readFileSync(path.join(REPO_ROOT, 'firebase.json'), 'utf8')
);
const indexFile = JSON.parse(
  fs.readFileSync(path.join(REPO_ROOT, 'firestore.indexes.json'), 'utf8')
);

/** Does an index exist for this collection with exactly these fields, in order? */
const hasIndex = (collection: string, fields: string[]): boolean =>
  indexFile.indexes.some(
    (idx: any) =>
      idx.collectionGroup === collection &&
      idx.fields.length === fields.length &&
      idx.fields.every((f: any, i: number) => f.fieldPath === fields[i])
  );

/**
 * Exactly what `firebase firestore:indexes --project licenseprepapp` returned
 * on 2026-09-17. `__name__` is omitted because Firestore appends it itself and
 * the index file must not declare it.
 *
 * When production gains an index, add it here in the same commit that adds it
 * to firestore.indexes.json.
 */
const IN_PRODUCTION: Array<[string, string[]]> = [
  ['quizQuestions', ['language', 'state', 'topicId', 'order']],
  ['quizTopics', ['language', 'state', 'order']],
  ['trafficRuleTopics', ['language', 'state', 'order']],
  ['theoryModules', ['language', 'state', 'licenseId', 'order']],
  ['subscriptionLogs', ['action', 'userId', 'timestamp']],
  ['subscriptions', ['isActive', 'planType', 'status', 'trialUsed', 'trialEndsAt']],
  ['subscriptions', ['status', 'isActive', 'nextBillingDate']],
  ['subscriptions', ['trialUsed', 'status', 'nextBillingDate']],
  ['subscriptions', ['trialUsed', 'status', 'trialEndsAt']],
  ['subscriptions', ['userId', 'createdAt']],
  ['subscriptions', ['userId', 'status', 'createdAt']],
];

describe('Risk #15 — index definitions are wired into the deploy', () => {
  it('firebase.json points at the index file', () => {
    expect(firebaseJson.firestore?.indexes).toBe('firestore.indexes.json');
  });

  it('still points at the rules file (positive control)', () => {
    expect(firebaseJson.firestore?.rules).toBe('firestore.rules');
  });
});

describe('Risk #15 — a deploy must never delete a production index', () => {
  it.each(IN_PRODUCTION)('declares the %s index that production holds (%s)', (collection, fields) => {
    expect(hasIndex(collection as string, fields as string[])).toBe(true);
  });

  it('declares every one of them, so a deploy can only add', () => {
    const missing = IN_PRODUCTION.filter(([c, f]) => !hasIndex(c, f));
    expect(missing).toEqual([]);
  });

  // The money path specifically. checkRateLimit runs BEFORE
  // validatePurchaseReceipt's try block, so losing this index throws after the
  // customer has already been charged.
  it('declares the receipt rate-limit index in production field order', () => {
    expect(hasIndex('subscriptionLogs', ['action', 'userId', 'timestamp'])).toBe(true);
  });
});

describe('Risk #15 — indexes the code needs that production lacks', () => {
  // Each of these is a query whose shape changed without the index following —
  // the failure mode #15 describes. They are additions, not replacements.

  // getPracticeTests: licenseId ==, language ==, state in [...], orderBy order.
  // Production holds no practiceTests index at all.
  it('declares the practiceTests listing index', () => {
    expect(hasIndex('practiceTests', ['language', 'state', 'licenseId', 'order'])).toBe(true);
  });

  // renewActiveSubscriptions: nextBillingDate <=, status ==, isActive ==,
  // trialUsed ==, orderBy nextBillingDate. Production holds
  // (trialUsed, status, nextBillingDate) — the shape from BEFORE the isActive
  // filter was added by the SM-MOD-2 fix.
  it('declares the renewal sweep index including isActive', () => {
    expect(
      hasIndex('subscriptions', ['status', 'isActive', 'trialUsed', 'nextBillingDate'])
    ).toBe(true);
  });

  // getRenewalStats, per plan type.
  it('declares the per-plan renewal stats index', () => {
    expect(
      hasIndex('subscriptions', [
        'status', 'isActive', 'trialUsed', 'planType', 'nextBillingDate',
      ])
    ).toBe(true);
  });
});

describe('Risk #15 — no speculative indexes', () => {
  // An earlier version of this file declared indexes for pure-equality queries
  // such as (userId, isActive) and (originalTransactionId, userId). Production
  // holds none of them and those queries demonstrably work, so Firestore is
  // serving them without a composite index. Declaring them would build indexes
  // nobody needs, which cost write latency and storage.
  it.each([
    ['subscriptions', ['userId', 'isActive']],
    ['subscriptions', ['originalTransactionId', 'userId']],
    ['subscriptions', ['androidPurchaseToken', 'userId']],
    ['quizQuestions', ['language', 'state']],
    ['theoryModules', ['licenseId', 'language']],
  ])('does not declare the pure-equality %s index (%s)', (collection, fields) => {
    expect(hasIndex(collection as string, fields as string[])).toBe(false);
  });

  it('declares exactly production plus the three known gaps', () => {
    expect(indexFile.indexes).toHaveLength(IN_PRODUCTION.length + 3);
  });
});
