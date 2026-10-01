/**
 * Instructors plan v2 §4.2 — the signup intent: setSignupRole records
 * signupRole/signupKind once (known values only, never userType), and
 * getUserData returns the role so the app can pick the student or
 * instructor navigation.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';

const db = () => admin.firestore();
const ctx = (uid: string) => ({ auth: { uid, token: { email: `${uid}@example.com`, firebase: { sign_in_provider: 'password' } } } });
const create = (data: unknown, uid: string) =>
  testEnv.wrap(fns.createOrUpdateUserDocument as any)(data as any, ctx(uid) as any);
const getUserData = (uid: string) => testEnv.wrap(fns.getUserData as any)({} as any, ctx(uid) as any);

beforeEach(async () => {
  for (const uid of ['urf-student', 'urf-school', 'urf-forger', 'urf-bogus', 'urf-provisioned']) {
    await db().collection('users').doc(uid).delete().catch(() => {});
  }
});
afterAll(() => testEnv.cleanup());

const setRole = (data: unknown, uid: string) =>
  testEnv.wrap(fns.setSignupRole as any)(data as any, ctx(uid) as any);

describe('createOrUpdateUserDocument — no role fields', () => {
  it('never writes userType or the signup intent, whatever the client sends', async () => {
    await create({ name: 'F', email: 'f@example.com', userType: 'instructor', signupRole: 'instructor' }, 'urf-forger');
    const doc = (await db().collection('users').doc('urf-forger').get()).data()!;
    expect(doc.userType).toBeUndefined();
    expect(doc.signupRole).toBeUndefined();
  });
});

// Asked after the email code (owner, 2026-09-30), so the doc already exists —
// provisionUserDocument (the auth trigger) creates it at account creation.
describe('setSignupRole', () => {
  async function provisioned(uid: string) {
    await db().collection('users').doc(uid).set({
      email: `${uid}@example.com`, name: '', language: 'en', state: null, provisionedBy: 'auth-trigger',
    });
  }

  it('records an instructor intent and kind on the provisioned doc', async () => {
    await provisioned('urf-school');
    await setRole({ signupRole: 'instructor', signupKind: 'schoolInstructor' }, 'urf-school');
    const doc = (await db().collection('users').doc('urf-school').get()).data()!;
    expect(doc.signupRole).toBe('instructor');
    expect(doc.signupKind).toBe('schoolInstructor');
    expect(doc.userType).toBeUndefined();
    expect(doc.provisionedBy).toBe('auth-trigger');
  });

  it('records a student with no kind', async () => {
    await provisioned('urf-student');
    await setRole({ signupRole: 'student', signupKind: 'school' }, 'urf-student');
    const doc = (await db().collection('users').doc('urf-student').get()).data()!;
    expect(doc.signupRole).toBe('student');
    expect(doc.signupKind).toBeUndefined();
  });

  it('is set once: the same answer again is fine, a different one is refused', async () => {
    await provisioned('urf-provisioned');
    await setRole({ signupRole: 'instructor', signupKind: 'school' }, 'urf-provisioned');
    await setRole({ signupRole: 'instructor', signupKind: 'school' }, 'urf-provisioned');
    await expect(setRole({ signupRole: 'student' }, 'urf-provisioned')).rejects.toMatchObject({ code: 'failed-precondition' });
    expect((await db().collection('users').doc('urf-provisioned').get()).get('signupRole')).toBe('instructor');
  });

  // Owner, 2026-09-30: the Sign Up page knows the role, so it is saved when
  // the account is made; an instructor's kind follows after the email code.
  it('saves an instructor role without a kind, then the kind once', async () => {
    await provisioned('urf-provisioned');
    await setRole({ signupRole: 'instructor' }, 'urf-provisioned');
    expect((await db().collection('users').doc('urf-provisioned').get()).get('signupKind')).toBeUndefined();
    await setRole({ signupRole: 'instructor', signupKind: 'schoolInstructor' }, 'urf-provisioned');
    await setRole({ signupRole: 'instructor', signupKind: 'schoolInstructor' }, 'urf-provisioned');
    await expect(setRole({ signupRole: 'student' }, 'urf-provisioned')).rejects.toMatchObject({ code: 'failed-precondition' });
    const doc = (await db().collection('users').doc('urf-provisioned').get()).data()!;
    expect(doc.signupRole).toBe('instructor');
    expect(doc.signupKind).toBe('schoolInstructor');
  });

  // Owner, 2026-09-30: the wizard's first Back reopens «How do you teach?»,
  // so the kind may change until the instructor registers; then it is fixed.
  it('lets the kind change before registration, not after', async () => {
    await provisioned('urf-provisioned');
    await setRole({ signupRole: 'instructor', signupKind: 'schoolInstructor' }, 'urf-provisioned');
    await setRole({ signupRole: 'instructor', signupKind: 'school' }, 'urf-provisioned');
    expect((await db().collection('users').doc('urf-provisioned').get()).get('signupKind')).toBe('school');

    await db().collection('users').doc('urf-provisioned').update({ userType: 'instructor' });
    await expect(setRole({ signupRole: 'instructor', signupKind: 'schoolInstructor' }, 'urf-provisioned'))
      .rejects.toMatchObject({ code: 'failed-precondition' });
    expect((await db().collection('users').doc('urf-provisioned').get()).get('signupKind')).toBe('school');
  });

  it('refuses unknown values', async () => {
    await expect(setRole({ signupRole: 'admin' }, 'urf-bogus')).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(setRole({ signupRole: 'instructor', signupKind: 'solo' }, 'urf-bogus'))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });
});

describe('getUserData — role fields', () => {
  it('returns student for an account without userType', async () => {
    await create({ name: 'St', email: 'st@example.com' }, 'urf-student');
    await expect(getUserData('urf-student')).resolves.toMatchObject({ userType: 'student', signupRole: null });
  });

  it('returns instructor once the server granted it', async () => {
    await db().collection('users').doc('urf-school').set({
      name: 'S', email: 's@example.com', userType: 'instructor', signupRole: 'instructor', signupKind: 'school',
    });
    await expect(getUserData('urf-school')).resolves.toMatchObject({
      userType: 'instructor', signupRole: 'instructor', signupKind: 'school',
    });
  });
});
