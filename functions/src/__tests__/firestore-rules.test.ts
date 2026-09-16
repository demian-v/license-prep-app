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
