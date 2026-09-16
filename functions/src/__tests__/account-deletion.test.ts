/**
 * Risks #13 and #14 — account deletion.
 *
 * #13: privacy_policy.md promises "your account and all associated data" and
 * "all personal data is deleted within 30 days". deleteUserAccount deleted the
 * users document and savedQuestions — 2 of at least 8 places holding user data.
 * Everything else survived indefinitely.
 *
 * #14: deletion needed no reauthentication (admin.auth().deleteUser bypasses
 * requires-recent-login entirely), was not atomic, and silently left the user's
 * store subscription billing them.
 *
 * Subscription and billing records are ANONYMISED, not deleted: the same policy
 * says "Subscription Data: Retained as required for billing and tax purposes".
 * Stripping the personal link honours both promises at once.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { collectUserDataForDeletion } from '../account-deletion';

const db = () => admin.firestore();
const UID = 'delete-me';

/** auth_time in seconds — Firebase puts it in the ID token. */
const ctx = (uid: string, authAgeSeconds = 10) => ({
  auth: {
    uid,
    token: {
      auth_time: Math.floor(Date.now() / 1000) - authAgeSeconds,
      firebase: { sign_in_provider: 'password' },
    },
  },
});

async function seedEverything(uid: string) {
  const b = db().batch();
  b.set(db().collection('users').doc(uid), { email: 'del@example.com', name: 'Del' });
  b.set(db().collection('users').doc(uid).collection('sessions').doc('s1'), { device: 'iPhone' });
  b.set(db().collection('savedQuestions').doc(uid), { items: ['q1'] });
  b.set(db().collection('progress').doc(uid), { completed: 12 });
  b.set(db().collection('counters').doc(`user_${uid}_reports`), { value: 3 });
  b.set(db().collection('reports').doc(`1_user_${uid}_report_1`), { userId: uid, reason: 'image' });
  b.set(db().collection('subscriptions').doc(`sub-${uid}`), { userId: uid, planType: 'monthly', price: 9.99 });
  b.set(db().collection('subscriptionLogs').doc(`log-${uid}`), { userId: uid, action: 'receipt_validated' });
  await b.commit();
}

afterAll(() => testEnv.cleanup());

describe('Risk #13 — everything personal is actually removed', () => {
  beforeAll(async () => {
    await seedEverything(UID);
    const wrapped = testEnv.wrap(fns.deleteUserAccount as any);
    await wrapped({} as any, ctx(UID) as any);
  }, 60000);

  it.each([
    ['users', UID],
    ['savedQuestions', UID],
    ['progress', UID],
    ['counters', `user_${UID}_reports`],
    ['reports', `1_user_${UID}_report_1`],
  ])('deletes %s/%s', async (coll, id) => {
    const doc = await db().collection(coll).doc(id).get();
    expect(doc.exists).toBe(false);
  });

  it('deletes the sessions SUBcollection, which a parent delete would leave behind', async () => {
    const sessions = await db().collection('users').doc(UID).collection('sessions').get();
    expect(sessions.size).toBe(0);
  });
});

describe('Risk #13 — billing records are kept but de-linked', () => {
  it('keeps the subscription for tax purposes, without the person attached', async () => {
    const doc = await db().collection('subscriptions').doc(`sub-${UID}`).get();
    expect(doc.exists).toBe(true);           // retained per the stated policy
    expect(doc.get('price')).toBe(9.99);     // the financial record survives
    expect(doc.get('userId')).not.toBe(UID); // the link to the person does not
    expect(doc.get('anonymizedAt')).toBeTruthy();
  });

  it('does the same for subscriptionLogs', async () => {
    const doc = await db().collection('subscriptionLogs').doc(`log-${UID}`).get();
    expect(doc.exists).toBe(true);
    expect(doc.get('userId')).not.toBe(UID);
  });
});

describe('Risk #14 — deletion requires a recent login', () => {
  it('refuses when the session is stale', async () => {
    await seedEverything('stale-user');
    const wrapped = testEnv.wrap(fns.deleteUserAccount as any);
    // 45 minutes old — admin.auth().deleteUser bypasses requires-recent-login,
    // so nothing enforced this before.
    await expect(wrapped({} as any, ctx('stale-user', 45 * 60) as any))
      .rejects.toMatchObject({ code: 'failed-precondition' });

    const doc = await db().collection('users').doc('stale-user').get();
    expect(doc.exists).toBe(true); // nothing was touched
  });

  it('tells the caller their store subscription keeps billing', async () => {
    await seedEverything('warned-user');
    const wrapped = testEnv.wrap(fns.deleteUserAccount as any);
    const res: any = await wrapped({} as any, ctx('warned-user') as any);
    expect(res.storeSubscriptionWarning).toBeTruthy();
  });
});

describe('collectUserDataForDeletion — the enumeration itself', () => {
  it('finds every location, so a new collection cannot be forgotten silently', async () => {
    await seedEverything('enum-user');
    const plan = await collectUserDataForDeletion(db(), 'enum-user');
    const kinds = plan.map((p) => p.collection).sort();
    expect(kinds).toEqual(expect.arrayContaining([
      'counters', 'progress', 'reports', 'savedQuestions',
      'subscriptionLogs', 'subscriptions', 'users', 'users/sessions',
    ]));
  });
});
