/**
 * Cursor-paginated sweep with a time budget (risk #25).
 *
 * The schedulers used `.limit(100)` with no cursor: document 101 was never
 * processed, and nothing reported that anything had been skipped. That became
 * load-bearing under risk #7, where the grace window tolerates a subscription
 * being up to 30 days overdue and then trusts the scheduler to revoke it. A
 * sweep that silently stops at 100 leaves a lapsed subscriber with access
 * forever — the exact failure the grace window was meant to bound.
 *
 * Why a cursor rather than simply re-running the query: the expiry sweeps
 * deactivate what they touch, so re-querying would work for them. The renewal
 * sweep does not — inside the grace window it only marks a subscription
 * `past_due`, which still matches the query it came from. Re-querying there
 * would process the same documents forever.
 *
 * Why a time budget: these run on Cloud Functions, which have a hard timeout.
 * Unbounded pagination just moves the failure from "stopped at 100 quietly" to
 * "killed mid-sweep quietly". The sweep stops early, on purpose, and says how
 * much is left so the next run continues and the depth is visible.
 */

/**
 * Wall-clock budget for one scheduled sweep.
 *
 * Sized against the 540s timeout the schedulers now request, leaving headroom
 * for the rest of the function and for a clean return. Overrunning a Cloud
 * Function timeout kills the process mid-write, which is strictly worse than
 * stopping deliberately and reporting the remainder.
 */
export const SWEEP_TIME_BUDGET_MS = 7 * 60 * 1000;

export interface SweepResult {
  processed: number;
  errors: string[];
  /** True when the sweep stopped with work still queued. */
  moreRemaining: boolean;
  pages: number;
}

export async function sweepPaginated(opts: {
  /** Used in logs so a deep queue can be attributed to a specific sweep. */
  label: string;
  /** Must carry a deterministic order — a cursor is meaningless without one. */
  baseQuery: FirebaseFirestore.Query;
  pageSize?: number;
  /** Epoch ms after which no new page is started. */
  deadline: number;
  handle: (doc: FirebaseFirestore.QueryDocumentSnapshot) => Promise<void>;
}): Promise<SweepResult> {
  const pageSize = opts.pageSize ?? 100;
  const result: SweepResult = { processed: 0, errors: [], moreRemaining: false, pages: 0 };

  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    if (Date.now() >= opts.deadline) {
      result.moreRemaining = true;
      break;
    }

    let query = opts.baseQuery.limit(pageSize);
    if (cursor) query = query.startAfter(cursor);

    const snap = await query.get();
    if (snap.empty) break;

    result.pages++;

    for (const doc of snap.docs) {
      if (Date.now() >= opts.deadline) {
        result.moreRemaining = true;
        break;
      }
      try {
        await opts.handle(doc);
        result.processed++;
      } catch (error) {
        // Per-document isolation: one poisoned document must not abandon the
        // rest of the queue.
        result.errors.push(
          `${opts.label}: error processing ${doc.id}: ` +
          (error instanceof Error ? error.message : String(error)),
        );
      }
    }

    if (result.moreRemaining) break;

    cursor = snap.docs[snap.docs.length - 1];

    // A short page means the query is exhausted.
    if (snap.size < pageSize) break;
  }

  if (result.moreRemaining) {
    console.warn(
      `🧹 ${opts.label}: stopped with work still queued after ${result.processed} ` +
      `document(s) across ${result.pages} page(s). The next scheduled run will continue. ` +
      'If this persists, the queue is growing faster than it drains — see risk #25.',
    );
  } else {
    console.log(
      `🧹 ${opts.label}: swept ${result.processed} document(s) across ${result.pages} page(s), queue drained.`,
    );
  }

  return result;
}
