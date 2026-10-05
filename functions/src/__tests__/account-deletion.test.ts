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
import { phonePhoto } from './helpers/jpeg';

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

describe('Instructors plan v2 §17 — an instructor account', () => {
  const IUID = 'delete-instructor';
  const OTHER = 'keep-instructor';
  const bucket = () => admin.storage().bucket();
  const file = (p: string) => bucket().file(p).save(phonePhoto(), { contentType: 'image/jpeg' });
  const exists = async (p: string) => (await bucket().file(p).exists())[0];

  beforeAll(async () => {
    await seedEverything(IUID);
    const b = db().batch();
    for (const uid of [IUID, OTHER]) {
      b.set(db().collection('instructors').doc(uid), { kind: 'school', state: 'ZX', listed: false, photoPath: `instructorPhotos/${uid}/p2.jpg` });
      b.set(db().collection('instructorPrivate').doc(uid), { phone: '+1 312 555 0100', contactEmail: `${uid}@example.com` });
      b.set(db().collection('instructors').doc(uid).collection('reviews').doc('student-1'), { rating: 5, comment: 'Great' });
    }
    b.set(db().collection('favorites').doc(IUID), { instructorUids: [OTHER] });
    b.set(db().collection('users').doc(IUID).collection('fcmTokens').doc('t1'), { token: 'x', platform: 'ios' });
    await b.commit();
    for (const uid of [IUID, OTHER]) {
      await file(`instructorPhotos/${uid}/p1.jpg`);
      await file(`instructorPhotos/${uid}/p2.jpg`);
      await file(`instructorUploads/${uid}/photo/u1.jpg`);
      await file(`instructorLicenses/${uid}/l1.jpg`);
    }
    await testEnv.wrap(fns.deleteUserAccount as any)({} as any, ctx(IUID) as any);
  }, 60000);

  afterAll(async () => {
    for (const prefix of ['instructorPhotos/', 'instructorUploads/', 'instructorLicenses/']) {
      await bucket().deleteFiles({ prefix: `${prefix}${OTHER}/`, force: true }).catch(() => {});
    }
    await db().recursiveDelete(db().collection('instructors').doc(OTHER));
    await db().collection('instructorPrivate').doc(OTHER).delete();
  });

  it.each([['instructors'], ['instructorPrivate'], ['favorites']])('deletes %s/{uid}', async (coll) => {
    expect((await db().collection(coll).doc(IUID).get()).exists).toBe(false);
  });

  it('deletes the reviews ON the profile and the push tokens (subcollections)', async () => {
    expect((await db().collection('instructors').doc(IUID).collection('reviews').get()).size).toBe(0);
    expect((await db().collection('users').doc(IUID).collection('fcmTokens').get()).size).toBe(0);
  });

  it('deletes every photo version, pending upload and licence image in Storage', async () => {
    for (const p of [`instructorPhotos/${IUID}/p1.jpg`, `instructorPhotos/${IUID}/p2.jpg`,
      `instructorUploads/${IUID}/photo/u1.jpg`, `instructorLicenses/${IUID}/l1.jpg`]) {
      expect(await exists(p)).toBe(false);
    }
  });

  it("leaves another instructor's data alone", async () => {
    expect((await db().collection('instructors').doc(OTHER).get()).exists).toBe(true);
    expect((await db().collection('instructorPrivate').doc(OTHER).get()).exists).toBe(true);
    expect((await db().collection('instructors').doc(OTHER).collection('reviews').get()).size).toBe(1);
    for (const p of [`instructorPhotos/${OTHER}/p1.jpg`, `instructorUploads/${OTHER}/photo/u1.jpg`, `instructorLicenses/${OTHER}/l1.jpg`]) {
      expect(await exists(p)).toBe(true);
    }
  });

  it('the enumeration lists the instructor locations too', async () => {
    await db().collection('instructors').doc('enum-i').set({ kind: 'school' });
    await db().collection('instructorPrivate').doc('enum-i').set({ phone: 'x' });
    await db().collection('favorites').doc('enum-i').set({ instructorUids: [] });
    await db().collection('users').doc('enum-i').collection('fcmTokens').doc('t').set({ token: 'x' });
    await db().collection('instructors').doc('enum-i').collection('reviews').doc('s').set({ rating: 4 });
    const kinds = (await collectUserDataForDeletion(db(), 'enum-i')).map((p) => p.collection);
    expect(kinds).toEqual(expect.arrayContaining([
      'instructors', 'instructorPrivate', 'favorites', 'users/fcmTokens', 'instructors/reviews',
    ]));
    await db().recursiveDelete(db().collection('instructors').doc('enum-i'));
    await db().recursiveDelete(db().collection('users').doc('enum-i'));
    await db().collection('instructorPrivate').doc('enum-i').delete();
    await db().collection('favorites').doc('enum-i').delete();
  });
});


describe('Instructors plan v2 §17 — conversations are anonymised, not deleted (P6)', () => {
  const wrapped = () => testEnv.wrap(fns.deleteUserAccount as any);
  const conv = (id: string) => db().collection('conversations').doc(id);

  beforeAll(async () => {
    const b = db().batch();
    // The student deletes; the instructor keeps the thread.
    b.set(conv('del-s_del-i1'), {
      studentUid: 'del-s', instructorUid: 'del-i1', participantUids: ['del-s', 'del-i1'],
      studentDisplayName: 'Anna K.', instructorName: 'Maria', studentUnread: 2, instructorUnread: 1,
    });
    b.set(conv('del-s_del-i1').collection('messages').doc('m1'), { senderUid: 'del-s', text: 'Hi', masked: false });
    // The instructor deletes; the student keeps the thread.
    b.set(conv('del-s2_del-i2'), {
      studentUid: 'del-s2', instructorUid: 'del-i2', participantUids: ['del-s2', 'del-i2'],
      studentDisplayName: 'Bo L.', instructorName: 'Lakeview', instructorPhotoPath: 'instructorPhotos/del-i2/p.jpg',
      instructorUnread: 3,
    });
    // The other side is already gone: nobody can read it any more.
    b.set(conv('del-s_del-i3'), {
      studentUid: 'del-s', instructorUid: 'del-i3', participantUids: ['del-s'], instructorDeleted: true,
    });
    b.set(conv('del-s_del-i3').collection('messages').doc('m1'), { senderUid: 'del-i3', text: 'Bye', masked: false });
    b.set(db().collection('users').doc('del-s'), { name: 'Anna' });
    b.set(db().collection('users').doc('del-i2'), { name: 'Lakeview' });
    await b.commit();
    await wrapped()({} as any, ctx('del-s') as any);
    await wrapped()({} as any, ctx('del-i2') as any);
  }, 60000);

  it('a deleted student: the instructor keeps the thread, without the name', async () => {
    const c = (await conv('del-s_del-i1').get()).data()!;
    expect(c).toMatchObject({
      participantUids: ['del-i1'], studentDeleted: true, studentDisplayName: null, studentUnread: 0,
      instructorName: 'Maria', instructorUnread: 1,
    });
    expect((await conv('del-s_del-i1').collection('messages').doc('m1').get()).exists).toBe(true);
  });

  it('a deleted instructor: the student keeps the thread, without name or photo', async () => {
    const c = (await conv('del-s2_del-i2').get()).data()!;
    expect(c).toMatchObject({
      participantUids: ['del-s2'], instructorDeleted: true, instructorName: null, instructorPhotoPath: null,
      studentDisplayName: 'Bo L.',
    });
  });

  it('a thread with nobody left is deleted with its messages', async () => {
    expect((await conv('del-s_del-i3').get()).exists).toBe(false);
    expect((await conv('del-s_del-i3').collection('messages').get()).size).toBe(0);
  });

  afterAll(async () => {
    for (const id of ['del-s_del-i1', 'del-s2_del-i2']) await db().recursiveDelete(conv(id));
  });
});
