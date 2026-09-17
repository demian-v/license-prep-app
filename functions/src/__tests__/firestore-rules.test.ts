/**
 * Firestore security rules — risks #3 and #29.
 *
 * Written RED on purpose. These describe the rules we want; they fail against
 * the rules we have. Uses its own demo project so it never touches the
 * long-running seeded emulator's data.
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
    projectId: 'demo-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const anon = () => env.authenticatedContext('anon-1', { firebase: { sign_in_provider: 'anonymous' } } as any);
const free = () => env.authenticatedContext('free-1', { firebase: { sign_in_provider: 'password' } } as any);

describe('Risk #3 — content must not be readable by anonymous or unentitled users', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('quizQuestions').doc('q1').set({ correctAnswer: 0 });
      await ctx.firestore().collection('quizTopics').doc('t1').set({ title: 'Signs' });
    });
  });

  it('an anonymous user cannot read quizQuestions', async () => {
    await assertFails(anon().firestore().collection('quizQuestions').doc('q1').get());
  });

  it('an anonymous user cannot read quizTopics', async () => {
    await assertFails(anon().firestore().collection('quizTopics').doc('t1').get());
  });

  it('a signed-in user with no subscription cannot read quizQuestions', async () => {
    await assertFails(free().firestore().collection('quizQuestions').doc('q1').get());
  });

  it('an unauthenticated visitor cannot read quizQuestions (control — already enforced)', async () => {
    await assertFails(env.unauthenticatedContext().firestore().collection('quizQuestions').doc('q1').get());
  });

  // Without these two, a rule of "deny everyone" would pass every test above.
  it('a PAID user CAN read quizQuestions (positive control)', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc('paid-1').set({ isActive: true });
    });
    const paid = env.authenticatedContext('paid-1', { firebase: { sign_in_provider: 'password' } } as any);
    await assertSucceeds(paid.firestore().collection('quizQuestions').doc('q1').get());
  });

  it('a TRIAL user CAN read quizQuestions (regression guard)', async () => {
    // createTrialSubscription now mirrors entitlement onto users/{uid}. Before
    // that change this rule would have locked out every trial user, because
    // users.isActive was never written on the trial path.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc('trial-1').set({
        isActive: true,
        nextBillingDate: new Date(Date.now() + 3 * 864e5),
      });
    });
    const trial = env.authenticatedContext('trial-1', { firebase: { sign_in_provider: 'password' } } as any);
    await assertSucceeds(trial.firestore().collection('quizQuestions').doc('q1').get());
  });

  it('an anonymous user with isActive still cannot read (anonymous gate holds)', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc('anon-1').set({ isActive: true });
    });
    await assertFails(anon().firestore().collection('quizQuestions').doc('q1').get());
  });
});

describe('Risk #29 — users/{uid} must not accept arbitrary client writes', () => {
  it('a user cannot set isActive on their own document', async () => {
    await assertFails(
      free().firestore().collection('users').doc('free-1').set({ isActive: true }, { merge: true }),
    );
  });

  it('a user cannot grant themselves a subscription field', async () => {
    await assertFails(
      free().firestore().collection('users').doc('free-1').set({ subscriptionStatus: 'active' }, { merge: true }),
    );
  });

  it('a user can still write their own profile fields (positive control)', async () => {
    await assertSucceeds(
      free().firestore().collection('users').doc('free-1').set({ displayName: 'Demian' }, { merge: true }),
    );
  });

  it('a user cannot write another user document (control — already enforced)', async () => {
    await assertFails(
      free().firestore().collection('users').doc('someone-else').set({ displayName: 'x' }),
    );
  });
});

/**
 * Risk #45 — `reports` is a write-only black hole, and the `userId` field in the
 * document body is never checked against the caller.
 *
 * Only the document ID was bound to the uid. The body could claim any userId,
 * which poisons admin triage; and nothing let a user read their own report
 * back, so the feature was write-only for everyone (verified 2026-08-20: the
 * `admins` collection does not exist in production, so isAdmin() is false for
 * everyone and the collection was unreadable, permanently).
 */
describe('Risk #45 — reports ownership', () => {
  const owner = () =>
    env.authenticatedContext('owner-1', { firebase: { sign_in_provider: 'password' } } as any);
  const other = () =>
    env.authenticatedContext('other-1', { firebase: { sign_in_provider: 'password' } } as any);

  const body = (userId: string) => ({
    userId,
    createdAt: new Date(),
    reason: 'image',
    contentType: 'quiz_question',
    entity: { questionId: 'q1', path: 'quizQuestions/q1' },
    status: 'open',
  });

  const idFor = (uid: string) => `1_user_${uid}_report_1`;

  it('lets a user file a report under their own id (positive control)', async () => {
    await assertSucceeds(
      owner().firestore().collection('reports').doc(idFor('owner-1')).set(body('owner-1')),
    );
  });

  it('rejects a report whose body claims someone else\'s userId', async () => {
    // The document ID is the caller's, so the old rule allowed this: the body
    // could attribute the complaint to any user at all.
    await assertFails(
      owner().firestore().collection('reports').doc(idFor('owner-1')).set(body('other-1')),
    );
  });

  it('rejects a report with no userId at all', async () => {
    const { userId, ...withoutUserId } = body('owner-1');
    await assertFails(
      owner().firestore().collection('reports').doc(idFor('owner-1')).set(withoutUserId as any),
    );
  });

  it('accepts the fallback id shape used when the counter is unavailable', async () => {
    // The client falls back to a generated id when the counter fails. That id
    // has to satisfy the rules, or the report is silently lost — which is what
    // `.add()` did, producing an auto-id matching no allowed pattern.
    await assertSucceeds(
      owner().firestore()
        .collection('reports')
        .doc(`1789600000000_user_owner-1_report_fallback_12345`)
        .set(body('owner-1')),
    );
  });

  it('lets a user read their own report back', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('reports').doc(idFor('owner-1')).set(body('owner-1'));
    });

    await assertSucceeds(
      owner().firestore().collection('reports').doc(idFor('owner-1')).get(),
    );
  });

  it('does not let a user read someone else\'s report', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('reports').doc(idFor('owner-1')).set(body('owner-1'));
    });

    await assertFails(
      other().firestore().collection('reports').doc(idFor('owner-1')).get(),
    );
  });

  it('lets a user list only their own reports', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('reports').doc(idFor('owner-1')).set(body('owner-1'));
      await ctx.firestore().collection('reports').doc(idFor('other-1')).set(body('other-1'));
    });

    await assertSucceeds(
      owner().firestore().collection('reports').where('userId', '==', 'owner-1').get(),
    );
  });

  it('does not let a user read the whole collection', async () => {
    // This is what getUserReports did — an unfiltered .get(). It was denied,
    // and the client swallowed the error and returned an empty list, so users
    // were told they had no reports rather than that the read failed.
    await assertFails(owner().firestore().collection('reports').get());
  });

  it('still refuses a user editing their own report after filing it', async () => {
    // Triage state belongs to admins. A user must not be able to reopen or
    // close their own complaint.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('reports').doc(idFor('owner-1')).set(body('owner-1'));
    });

    await assertFails(
      owner().firestore().collection('reports').doc(idFor('owner-1')).update({ status: 'closed' }),
    );
  });
});
