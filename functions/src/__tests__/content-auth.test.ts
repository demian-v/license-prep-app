/**
 * Risk #3 — the entire paid content corpus is served by unauthenticated callables.
 *
 * These tests are written RED on purpose: they describe the behaviour we want,
 * and they fail against the current code. That failure IS the evidence the
 * vulnerability is real. Do not weaken them to make them pass.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
// eslint-disable-next-line @typescript-eslint/no-var-requires
import * as fns from '../index';

const db = () => admin.firestore();

const ANON_CTX = { auth: { uid: 'anon-user', token: { firebase: { sign_in_provider: 'anonymous' } } } };
const FREE_CTX = { auth: { uid: 'free-user', token: { firebase: { sign_in_provider: 'password' } } } };
const PAID_CTX = { auth: { uid: 'paid-user', token: { firebase: { sign_in_provider: 'password' } } } };

beforeAll(async () => {
  await db().collection('quizTopics').doc('t1').set({
    language: 'zz', state: 'ZZ', order: 1, title: 'Road Signs',
  });
  await db().collection('quizQuestions').doc('q1').set({
    language: 'zz', state: 'ZZ', topicId: 't1',
    question: 'What does a red octagon mean?',
    options: ['Stop', 'Yield', 'Go', 'Slow'],
    correctAnswer: 0,
    explanation: 'A red octagon is always a stop sign.',
  });
  // entitlement fixture for the positive control
  await db().collection('subscriptions').doc('sub-paid').set({
    userId: 'paid-user', isActive: true, planType: 'monthly',
    nextBillingDate: admin.firestore.Timestamp.fromMillis(Date.now() + 30 * 864e5),
  });
});

afterAll(async () => { testEnv.cleanup(); });

describe('Risk #3 — content callables must require an entitled, non-anonymous user', () => {
  it('getQuizTopics rejects a caller with no auth at all', async () => {
    const wrapped = testEnv.wrap(fns.getQuizTopics as any);
    await expect(wrapped({ language: 'zz', state: 'ZZ' } as any, {} as any))
      .rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('getQuizTopics rejects an anonymous caller', async () => {
    const wrapped = testEnv.wrap(fns.getQuizTopics as any);
    await expect(wrapped({ language: 'zz', state: 'ZZ' } as any, ANON_CTX as any))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('getQuizTopics rejects a signed-in user with no subscription', async () => {
    const wrapped = testEnv.wrap(fns.getQuizTopics as any);
    await expect(wrapped({ language: 'zz', state: 'ZZ' } as any, FREE_CTX as any))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('getQuizTopics serves an entitled user (positive control)', async () => {
    const wrapped = testEnv.wrap(fns.getQuizTopics as any);
    const res: any = await wrapped({ language: 'zz', state: 'ZZ' } as any, PAID_CTX as any);
    expect(Array.isArray(res)).toBe(true);
    expect(res).toHaveLength(1);
    expect(res[0].title).toBe('Road Signs');
  });

  it('getQuizQuestions does not leak answers to an unauthenticated caller', async () => {
    const wrapped = testEnv.wrap(fns.getQuizQuestions as any);
    await expect(wrapped({ language: 'zz', state: 'ZZ', topicId: 't1' } as any, {} as any))
      .rejects.toMatchObject({ code: 'unauthenticated' });
  });
});
