/**
 * Risk #11 — the global counter rule contradicts its own writer.
 *
 * `CounterService.getNextGlobalReportId` increments the counter inside a
 * transaction with `set({value, lastUpdated, description}, merge: true)`.
 * Two things in the rule make that impossible:
 *
 *  1. `allow create: if false` — on a project where the document does not
 *     exist yet, a merge-set IS a create. So the first report ever filed is
 *     denied, and the counter can never bootstrap from the client.
 *
 *  2. `request.resource.data.keys().hasOnly([...])` is evaluated on the
 *     MERGED document, not on what changed. `initializeGlobalCounterFromExistingReports`
 *     and `resetGlobalCounter` write `createdAt`, `initializedFrom` and
 *     `initialCount`, so once either has run, every later increment carries
 *     those keys through the merge and is denied forever. That is why the
 *     register's runbook warns not to run those helpers: following it bricks
 *     the counter.
 *
 * Written RED against the rules as they were.
 */
import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-counter-rules',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const user = () => env.authenticatedContext('user-1', { firebase: { sign_in_provider: 'password' } } as any);
const COUNTER = 'counters/global_report_counter';

/**
 * Exactly what CounterService writes on each increment. The real writer uses
 * `FieldValue.serverTimestamp()` for `lastUpdated`; a plain Date is equivalent
 * here because the rule constrains which keys may change, not their types.
 */
const increment = (value: number) => ({
  value,
  lastUpdated: new Date(),
  description: 'Global sequential counter for all reports',
});

/** Seed the counter as it exists after an admin helper has run. */
const seedWithAdminFields = async (value: number) => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(COUNTER).set({
      value,
      lastUpdated: new Date(),
      description: 'Global sequential counter for all reports',
      createdAt: new Date(),
      initializedFrom: 'existing_reports_count',
      initialCount: value,
    });
  });
};

describe('Risk #11 — the counter can bootstrap', () => {
  it('the first report ever filed creates the counter at 1', async () => {
    await assertSucceeds(
      user().firestore().doc(COUNTER).set(increment(1), { merge: true })
    );
  });

  it('a create that does not start at 1 is refused', async () => {
    await assertFails(
      user().firestore().doc(COUNTER).set(increment(5), { merge: true })
    );
  });

  it('a create carrying extra fields is refused', async () => {
    await assertFails(
      user().firestore().doc(COUNTER).set(
        { ...increment(1), initialCount: 900 },
        { merge: true }
      )
    );
  });
});

describe('Risk #11 — increments survive the admin helpers', () => {
  it('increments after initializeGlobalCounterFromExistingReports has run', async () => {
    await seedWithAdminFields(42);
    await assertSucceeds(
      user().firestore().doc(COUNTER).set(increment(43), { merge: true })
    );
  });

  it('increments on a counter with only the three plain fields', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(COUNTER).set({
        value: 7,
        lastUpdated: new Date(),
        description: 'Global sequential counter for all reports',
      });
    });
    await assertSucceeds(
      user().firestore().doc(COUNTER).set(increment(8), { merge: true })
    );
  });
});

describe('Risk #11 — the increment invariant still holds', () => {
  beforeEach(async () => { await seedWithAdminFields(42); });

  it('refuses a jump of more than one', async () => {
    await assertFails(
      user().firestore().doc(COUNTER).set(increment(50), { merge: true })
    );
  });

  it('refuses a decrement', async () => {
    await assertFails(
      user().firestore().doc(COUNTER).set(increment(41), { merge: true })
    );
  });

  it('refuses an update that changes a field the counter does not own', async () => {
    await assertFails(
      user().firestore().doc(COUNTER).set(
        { ...increment(43), initialCount: 0 },
        { merge: true }
      )
    );
  });

  it('refuses an unauthenticated increment', async () => {
    await assertFails(
      env.unauthenticatedContext().firestore().doc(COUNTER).set(increment(43), { merge: true })
    );
  });

  it('refuses a delete', async () => {
    await assertFails(user().firestore().doc(COUNTER).delete());
  });
});
