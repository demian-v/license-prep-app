/**
 * Risk #23 — the orphan-auth trap.
 *
 * User provisioning was entirely client-initiated: the app created the Auth
 * user, then wrote users/{uid} itself. If that second write failed — network
 * drop, app killed, permission hiccup — the Auth account existed with no
 * document, and nothing ever created one. `updateUserLanguage` and
 * `updateUserState` then called `.update()`, which throws NOT_FOUND on a
 * missing document, so the account was unrecoverable from inside the app.
 *
 * Two fixes, because they cover different populations:
 *   - an auth onCreate trigger provisions the document server-side, so new
 *     accounts cannot be orphaned in the first place;
 *   - the two updaters use set/merge, so accounts ALREADY orphaned in
 *     production heal the moment the user touches a setting.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';

const db = () => admin.firestore();
const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } } });

afterAll(() => testEnv.cleanup());

describe('Risk #23 — new accounts are provisioned server-side', () => {
  it('the auth trigger creates users/{uid} without the client', async () => {
    await db().collection('users').doc('trigger-user').delete().catch(() => {});

    const wrapped = testEnv.wrap(fns.provisionUserDocument as any);
    await wrapped({
      uid: 'trigger-user',
      email: 'trigger@example.com',
      displayName: 'Trigger User',
      emailVerified: false,
    } as any);

    const doc = await db().collection('users').doc('trigger-user').get();
    expect(doc.exists).toBe(true);
    expect(doc.get('email')).toBe('trigger@example.com');
    expect(doc.get('name')).toBe('Trigger User');
    expect(doc.get('createdAt')).toBeTruthy();
  });

  it('does not clobber a document the client already wrote', async () => {
    await db().collection('users').doc('existing-user').set({
      email: 'existing@example.com', name: 'Chosen Name', language: 'pl', state: 'NY',
    });

    const wrapped = testEnv.wrap(fns.provisionUserDocument as any);
    await wrapped({
      uid: 'existing-user', email: 'existing@example.com',
      displayName: 'Auth Name', emailVerified: false,
    } as any);

    const doc = await db().collection('users').doc('existing-user').get();
    expect(doc.get('name')).toBe('Chosen Name');  // client's value wins
    expect(doc.get('language')).toBe('pl');
    expect(doc.get('state')).toBe('NY');
  });
});

describe('Risk #23 — an already-orphaned account can recover', () => {
  it('updateUserState succeeds when the document is missing', async () => {
    await db().collection('users').doc('orphan-a').delete().catch(() => {});
    const wrapped = testEnv.wrap(fns.updateUserState as any);

    await expect(wrapped({ state: 'IL' } as any, ctx('orphan-a') as any)).resolves.toBeDefined();

    const doc = await db().collection('users').doc('orphan-a').get();
    expect(doc.exists).toBe(true);
    expect(doc.get('state')).toBe('IL');
  });

  it('updateUserLanguage succeeds when the document is missing', async () => {
    await db().collection('users').doc('orphan-b').delete().catch(() => {});
    const wrapped = testEnv.wrap(fns.updateUserLanguage as any);

    await expect(wrapped({ language: 'es' } as any, ctx('orphan-b') as any)).resolves.toBeDefined();

    const doc = await db().collection('users').doc('orphan-b').get();
    expect(doc.get('language')).toBe('es');
  });

  it('still updates an existing document normally (positive control)', async () => {
    await db().collection('users').doc('normal-user').set({ email: 'n@example.com', state: 'IL' });
    const wrapped = testEnv.wrap(fns.updateUserState as any);
    await wrapped({ state: 'NY' } as any, ctx('normal-user') as any);

    const doc = await db().collection('users').doc('normal-user').get();
    expect(doc.get('state')).toBe('NY');
    expect(doc.get('email')).toBe('n@example.com'); // untouched
  });
});
