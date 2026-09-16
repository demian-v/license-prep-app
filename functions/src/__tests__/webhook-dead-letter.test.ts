/**
 * Risk #9 — webhooks never signalled failure, with no dead-letter queue.
 *
 * Apple always received 200, "even on internal error"; the Play handler never
 * rethrew, so Pub/Sub always acked. A renewal or a revocation lost to a
 * transient Firestore error was lost permanently, with no record that it had
 * ever arrived.
 *
 * The original choice was defensible — the in-code comments cite retry storms
 * from our own bugs — so the fix keeps retries BOUNDED: record the failure,
 * ask the platform to retry a few times, then stop asking and leave the
 * dead letter for manual replay.
 */
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import { recordWebhookFailure, MAX_WEBHOOK_RETRIES } from '../webhook-dead-letter';

const db = () => admin.firestore();

// The attempt counter is intentionally durable across invocations, so each run
// must start from a clean slate or it inherits the previous run's count.
beforeAll(async () => {
  const snap = await db().collection('webhookDeadLetter').get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
});

describe('Risk #9 — failures are recorded and retried, then parked', () => {
  it('records a first failure and asks the platform to retry', async () => {
    const r = await recordWebhookFailure(db(), {
      source: 'apple', key: 'uuid-first', notificationType: 'DID_RENEW',
      payload: { signedPayload: 'abc' }, error: new Error('firestore unavailable'),
    });
    expect(r.attempts).toBe(1);
    expect(r.shouldRetry).toBe(true);

    const doc = await db().collection('webhookDeadLetter').doc('apple_uuid-first').get();
    expect(doc.exists).toBe(true);
    expect(doc.get('source')).toBe('apple');
    expect(doc.get('status')).toBe('pending');
    expect(doc.get('lastError')).toMatch(/firestore unavailable/);
  });

  it('increments attempts when the same notification fails again', async () => {
    for (let i = 1; i <= 3; i++) {
      const r = await recordWebhookFailure(db(), {
        source: 'play', key: 'msg-repeat', notificationType: '2',
        payload: { messageId: 'msg-repeat' }, error: new Error('boom'),
      });
      expect(r.attempts).toBe(i);
    }
  });

  it('stops asking for retries once the budget is spent', async () => {
    let last: { attempts: number; shouldRetry: boolean } | undefined;
    for (let i = 0; i < MAX_WEBHOOK_RETRIES + 1; i++) {
      last = await recordWebhookFailure(db(), {
        source: 'apple', key: 'uuid-exhaust', notificationType: 'EXPIRED',
        payload: { signedPayload: 'x' }, error: new Error('still broken'),
      });
    }
    expect(last!.shouldRetry).toBe(false);
    const doc = await db().collection('webhookDeadLetter').doc('apple_uuid-exhaust').get();
    expect(doc.get('status')).toBe('exhausted');
    // The record survives for manual replay — that is the whole point.
    expect(doc.get('payload')).toBeTruthy();
  });

  it('truncates an oversized payload rather than failing the write', async () => {
    const huge = { blob: 'x'.repeat(1_200_000) };
    const r = await recordWebhookFailure(db(), {
      source: 'play', key: 'msg-huge', notificationType: '13',
      payload: huge, error: new Error('too big'),
    });
    expect(r.attempts).toBe(1);
    const doc = await db().collection('webhookDeadLetter').doc('play_msg-huge').get();
    expect(doc.get('payloadTruncated')).toBe(true);
  });

  it('never throws, even if the payload cannot be serialised', async () => {
    const circular: any = {};
    circular.self = circular;
    const r = await recordWebhookFailure(db(), {
      source: 'apple', key: 'uuid-circular', notificationType: 'REFUND',
      payload: circular, error: new Error('original failure'),
    });
    // A dead-letter writer that throws would mask the real error.
    expect(r).toBeDefined();
  });
});
