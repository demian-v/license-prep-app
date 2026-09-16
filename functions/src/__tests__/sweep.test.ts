/**
 * Risk #25 — schedulers were capped at 100 documents per run, with no cursor
 * and no signal that anything was left behind.
 *
 * Two queries x limit(100) hourly for expiry, two x limit(100) every 6 hours
 * for renewals. Document 101 was simply not processed, and nothing said so.
 *
 * This became load-bearing with risk #7: the grace window now tolerates a
 * subscription being up to 30 days overdue, and trusts the scheduler to revoke
 * it after that. A sweep that silently stops at 100 means a lapsed subscriber
 * keeps access indefinitely, which is the failure #7 was supposed to bound.
 */
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

import { sweepPaginated } from '../sweep';

const db = () => admin.firestore();
const COLL = 'sweepFixtures';

async function seed(count: number, tag: string) {
  const existing = await db().collection(COLL).where('tag', '==', tag).get();
  await Promise.all(existing.docs.map((d) => d.ref.delete()));
  for (let i = 0; i < count; i += 400) {
    const batch = db().batch();
    for (let j = i; j < Math.min(i + 400, count); j++) {
      batch.set(db().collection(COLL).doc(`${tag}-${String(j).padStart(4, '0')}`), {
        tag, order: j, done: false,
      });
    }
    await batch.commit();
  }
}

describe('Risk #25 — a sweep must not stop at 100 documents', () => {
  it('processes every document across multiple pages', async () => {
    await seed(250, 'many');
    const seen: string[] = [];

    const res = await sweepPaginated({
      label: 'test-many',
      baseQuery: db().collection(COLL).where('tag', '==', 'many').orderBy('order'),
      pageSize: 100,
      deadline: Date.now() + 60_000,
      handle: async (doc) => { seen.push(doc.id); },
    });

    expect(res.processed).toBe(250);
    expect(new Set(seen).size).toBe(250); // no document handled twice
    expect(res.pages).toBeGreaterThan(1);
    expect(res.moreRemaining).toBe(false);
  });

  it('stops at the time budget and REPORTS what is left behind', async () => {
    await seed(250, 'slow');

    const res = await sweepPaginated({
      label: 'test-slow',
      baseQuery: db().collection(COLL).where('tag', '==', 'slow').orderBy('order'),
      pageSize: 100,
      deadline: Date.now() + 150, // expires almost immediately
      handle: async () => { await new Promise((r) => setTimeout(r, 2)); },
    });

    expect(res.processed).toBeLessThan(250);
    // The whole point: silence about the remainder is what made #25 invisible.
    expect(res.moreRemaining).toBe(true);
  });

  it('keeps going when one document fails', async () => {
    await seed(5, 'flaky');
    const res = await sweepPaginated({
      label: 'test-flaky',
      baseQuery: db().collection(COLL).where('tag', '==', 'flaky').orderBy('order'),
      pageSize: 2,
      deadline: Date.now() + 60_000,
      handle: async (doc) => {
        if (doc.get('order') === 2) throw new Error('bad document');
      },
    });

    expect(res.processed).toBe(4);
    expect(res.errors).toHaveLength(1);
    expect(res.errors[0]).toMatch(/bad document/);
    expect(res.moreRemaining).toBe(false);
  });

  it('handles an empty result set (positive control)', async () => {
    const res = await sweepPaginated({
      label: 'test-empty',
      baseQuery: db().collection(COLL).where('tag', '==', 'nothing-here').orderBy('order'),
      pageSize: 100,
      deadline: Date.now() + 60_000,
      handle: async () => { throw new Error('should never be called'); },
    });
    expect(res.processed).toBe(0);
    expect(res.moreRemaining).toBe(false);
  });
});
