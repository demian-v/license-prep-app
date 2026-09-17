/**
 * Risk #40 — `processedWebhooks` and `subscriptionLogs` grow without bound.
 *
 * The dangerous half of this row is `subscriptionLogs`: it is the money-state
 * audit trail, and risk #4 was a job that deleted rows out of it by accident.
 * So most of what is asserted here is about NOT deleting.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import {
  retentionCutoff,
  isRetentionEnabled,
  WEBHOOK_DEDUP_RETENTION_DAYS,
  SUBSCRIPTION_LOG_RETENTION_DISABLED,
} from '../retention';

const db = () => admin.firestore();
const DAY_MS = 24 * 60 * 60 * 1000;
const ts = (msAgo: number) => admin.firestore.Timestamp.fromMillis(Date.now() - msAgo);

// Suites run in parallel worker processes against ONE emulator. An earlier
// version of this file wiped `processedWebhooks` and `subscriptionLogs` whole
// in beforeEach, which deleted fixtures out from under rate-limit.test.ts and
// admin-auth.test.ts mid-run and made the suite flaky. Only ever remove the
// documents this file created.
const OWNED = 'retention-test-';
const drop = async (collection: string, ids: string[]) => {
  await Promise.all(
    ids.map((id) => db().collection(collection).doc(`${OWNED}${id}`).delete()),
  );
};
const ref = (collection: string, id: string) =>
  db().collection(collection).doc(`${OWNED}${id}`);

afterAll(async () => {
  testEnv.cleanup();
});

describe('Risk #40 — retention policy arithmetic', () => {
  it('puts the cutoff the configured number of days back', () => {
    const now = Date.parse('2026-09-16T00:00:00.000Z');
    expect(retentionCutoff(30, now).toISOString()).toBe('2026-08-17T00:00:00.000Z');
  });

  it.each([
    [0, false],
    [-1, false],
    [NaN, false],
    [Infinity, false],
    ['30', false],
    [null, false],
    [undefined, false],
    [1, true],
    [30, true],
  ])('isRetentionEnabled(%p) === %p', (value, expected) => {
    // A bad config value must read as disabled, never as "delete everything".
    // A negative or NaN cutoff lands in the future and matches every document.
    expect(isRetentionEnabled(value as any)).toBe(expected);
  });

  it('keeps subscriptionLogs forever by default', () => {
    expect(isRetentionEnabled(SUBSCRIPTION_LOG_RETENTION_DISABLED)).toBe(false);
  });

  it('keeps webhook dedup records past both stores\' retry windows', () => {
    // Apple retries over ~3 days, Google Play RTDN rides Pub/Sub's 7-day
    // retention. Dropping a record while a redelivery is still possible would
    // turn a duplicate into a reprocessed payment event.
    expect(WEBHOOK_DEDUP_RETENTION_DAYS).toBeGreaterThan(7);
  });
});

describe('Risk #40 — cleanupExpiredRecords', () => {
  const run = () => testEnv.wrap(fns.cleanupExpiredRecords as any)({} as any);

  beforeEach(async () => {
    await drop('processedWebhooks', ['old', 'fresh', 'edge', 'old1', 'old2']);
    await drop('subscriptionLogs', ['ancient']);
  });

  it('deletes webhook dedup records past the retention window', async () => {
    await ref('processedWebhooks', 'old').set({
      processedAt: ts((WEBHOOK_DEDUP_RETENTION_DAYS + 5) * DAY_MS),
      result: 'processed',
    });

    await run();

    expect((await ref('processedWebhooks', 'old').get()).exists).toBe(false);
  });

  it('keeps recent dedup records (positive control)', async () => {
    // Without this, a sweep that deleted the whole collection would pass.
    await ref('processedWebhooks', 'fresh').set({
      processedAt: ts(2 * DAY_MS),
      result: 'processed',
    });

    await run();

    expect((await ref('processedWebhooks', 'fresh').get()).exists).toBe(true);
  });

  it('keeps a record sitting just inside the window', async () => {
    await ref('processedWebhooks', 'edge').set({
      processedAt: ts((WEBHOOK_DEDUP_RETENTION_DAYS - 1) * DAY_MS),
      result: 'processed',
    });

    await run();

    expect((await ref('processedWebhooks', 'edge').get()).exists).toBe(true);
  });

  it('does NOT touch subscriptionLogs while retention is unset', async () => {
    // The whole point. This is the audit trail risk #4 was about; it must
    // survive a cleanup run that was never told to prune it.
    await ref('subscriptionLogs', 'ancient').set({
      timestamp: ts(3650 * DAY_MS),
      userId: 'u1',
      action: 'receipt_validated',
    });

    await run();

    expect((await ref('subscriptionLogs', 'ancient').get()).exists).toBe(true);
  });

  it('reports what it did', async () => {
    await ref('processedWebhooks', 'old1').set({
      processedAt: ts(90 * DAY_MS), result: 'processed',
    });
    await ref('processedWebhooks', 'old2').set({
      processedAt: ts(90 * DAY_MS), result: 'processed',
    });

    const result: any = await run();

    // Both of mine are gone, and the count includes them. Not an exact equality:
    // the sweep is collection-wide by design, so a sibling suite's expired row
    // would legitimately be counted too.
    expect((await ref('processedWebhooks', 'old1').get()).exists).toBe(false);
    expect((await ref('processedWebhooks', 'old2').get()).exists).toBe(false);
    expect(result.processedWebhooksDeleted).toBeGreaterThanOrEqual(2);
    expect(result.subscriptionLogsDeleted).toBe(0);
  });
});
