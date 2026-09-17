/**
 * Risk #15 — the index definitions are never deployed, and were incomplete.
 *
 * `firebase.json` declared `firestore.rules` but no `firestore.indexes`, so
 * `firebase deploy` has never shipped an index. Every composite index in
 * production was therefore created by hand from a console error link, and the
 * repo's `firestore.indexes.json` listed three of them.
 *
 * That matters most on the money path: `checkRateLimit` runs *before*
 * `validatePurchaseReceipt`'s try block, so a missing index there throws after
 * the customer has already been charged.
 *
 * These assertions are about the deploy configuration, not about runtime
 * behaviour — the Firestore emulator does not enforce composite indexes, so
 * this is the only place the gap is visible locally.
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

describe('Risk #15 — index definitions are wired into the deploy', () => {
  it('firebase.json points at the index file', () => {
    expect(firebaseJson.firestore?.indexes).toBe('firestore.indexes.json');
  });

  it('still points at the rules file (positive control)', () => {
    expect(firebaseJson.firestore?.rules).toBe('firestore.rules');
  });
});

describe('Risk #15 — the money-path queries have indexes', () => {
  // receipt-validation.ts checkRateLimit: userId ==, timestamp >, action in [...]
  // Field order matches the index already serving this query in production;
  // the query shape is deliberately kept byte-identical (see SESSION.md).
  it('covers the receipt-validation rate limit scan', () => {
    expect(hasIndex('subscriptionLogs', ['userId', 'timestamp', 'action'])).toBe(true);
  });

  // index.ts / receipt-validation.ts — risk #5 receipt-to-account binding
  it('covers receipt binding by Apple original transaction id', () => {
    expect(hasIndex('subscriptions', ['originalTransactionId', 'userId'])).toBe(true);
  });

  it('covers receipt binding by Google purchase token', () => {
    expect(hasIndex('subscriptions', ['androidPurchaseToken', 'userId'])).toBe(true);
  });

  // entitlement.ts — the gate that decides whether paid content is served
  it('covers the entitlement lookup', () => {
    expect(hasIndex('subscriptions', ['userId', 'isActive'])).toBe(true);
  });
});

describe('Risk #15 — the scheduler queries have indexes', () => {
  it('covers the trial expiry sweep', () => {
    expect(
      hasIndex('subscriptions', [
        'planType',
        'isActive',
        'trialUsed',
        'status',
        'trialEndsAt',
      ])
    ).toBe(true);
  });

  it('covers the renewal sweep', () => {
    expect(
      hasIndex('subscriptions', ['status', 'isActive', 'trialUsed', 'nextBillingDate'])
    ).toBe(true);
  });

  it('covers the canceled-subscription sweep', () => {
    expect(hasIndex('subscriptions', ['status', 'isActive', 'nextBillingDate'])).toBe(true);
  });
});

describe('Risk #15 — the content queries have indexes', () => {
  it.each([
    ['quizTopics', ['language', 'state', 'order']],
    ['trafficRuleTopics', ['language', 'state', 'order']],
    ['quizQuestions', ['topicId', 'language', 'state']],
    ['quizQuestions', ['language', 'state']],
    ['theoryModules', ['licenseId', 'language', 'state']],
    ['theoryModules', ['licenseId', 'language']],
    ['practiceTests', ['licenseId', 'language', 'state', 'order']],
  ])('covers %s (%s)', (collection, fields) => {
    expect(hasIndex(collection as string, fields as string[])).toBe(true);
  });
});

describe('Risk #15 — the previously listed indexes are still declared', () => {
  // Keeping these matters: `firebase deploy` offers to DELETE indexes that
  // exist in the project but not in this file. Dropping an entry here is how
  // a deploy would remove a working production index.
  it('keeps the original trial sweep index', () => {
    expect(hasIndex('subscriptions', ['trialEndsAt', 'trialUsed', 'status'])).toBe(true);
  });

  it('keeps the original renewal index', () => {
    expect(hasIndex('subscriptions', ['nextBillingDate', 'trialUsed', 'status'])).toBe(true);
  });

  it('keeps the subscriptionLogs reporting index', () => {
    expect(hasIndex('subscriptionLogs', ['timestamp', 'processedBy'])).toBe(true);
  });
});
