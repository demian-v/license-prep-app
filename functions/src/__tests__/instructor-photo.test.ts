/**
 * Instructors plan v2 §8 — onInstructorUpload, the step between the private
 * upload and what students see. Production is fail-closed until P10's
 * SafeSearch check (the photo waits as `pending`); only the emulator
 * auto-approves, copying to a versioned public name.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { phonePhoto } from './helpers/jpeg';
import { setPushTransport } from '../push';

const BUCKET = 'demo-driveusa.appspot.com';
const db = () => admin.firestore();
const bucket = () => admin.storage().bucket(BUCKET);
const finalize = (name: string, over: Record<string, unknown> = {}) =>
  testEnv.wrap(fns.onInstructorUpload as any)({
    name, bucket: BUCKET, contentType: 'image/jpeg', size: '2048', ...over,
  } as any);
const upload = (name: string, bytes: Buffer = phonePhoto()) => bucket().file(name).save(bytes, { contentType: 'image/jpeg' });
const exists = async (name: string) => (await bucket().file(name).exists())[0];
const pub = async (uid: string) => (await db().collection('instructors').doc(uid).get()).data()!;
const priv = async (uid: string) => (await db().collection('instructorPrivate').doc(uid).get()).data()!;

async function wipe() {
  await bucket().deleteFiles({ prefix: 'instructorUploads/ph-' }).catch(() => {});
  await bucket().deleteFiles({ prefix: 'instructorPhotos/ph-' }).catch(() => {});
  for (const uid of ['ph-1', 'ph-2']) {
    await db().collection('users').doc(uid).collection('fcmTokens').doc('t1').delete().catch(() => {});
    await db().collection('users').doc(uid).delete().catch(() => {});
    await db().collection('instructors').doc(uid).delete().catch(() => {});
    await db().collection('instructorPrivate').doc(uid).delete().catch(() => {});
  }
}

beforeEach(async () => {
  await wipe();
  await db().collection('instructors').doc('ph-1').set({
    kind: 'school', status: 'active', photoPath: null, photoApproved: false, photoStatus: 'none',
  });
  await db().collection('instructorPrivate').doc('ph-1').set({
    phone: '+1 312 555 0100', moderation: { photo: { status: 'none' }, license: { status: 'none' } },
  });
});
afterEach(() => { delete process.env.FUNCTIONS_EMULATOR; });
afterAll(async () => { setPushTransport(null); await wipe(); testEnv.cleanup(); });

// What the instructor's device would receive (plan v2 §12, P5).
let pushes: { token: string; title?: string; route?: string; kind?: string }[] = [];
beforeEach(async () => {
  pushes = [];
  setPushTransport({
    async send(messages) {
      pushes.push(...messages.map((m) => ({
        token: m.token, title: m.notification?.title, route: m.data?.route, kind: m.data?.kind,
      })));
      return messages.map(() => null);
    },
  });
  await db().collection('users').doc('ph-1').set({ language: 'en' });
  await db().collection('users').doc('ph-1').collection('fcmTokens').doc('t1').set({ token: 'tok-1', platform: 'ios' });
});

describe('onInstructorUpload — production (no moderation yet)', () => {
  it('keeps a new photo pending and shows nothing unmoderated', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    expect(await pub('ph-1')).toMatchObject({ photoStatus: 'pending', photoPath: null, photoApproved: false });
    expect((await priv('ph-1')).moderation).toMatchObject({
      photo: { status: 'pending', uploadId: 'u1' }, license: { status: 'none' },
    });
    expect(await exists('instructorUploads/ph-1/photo/u1.jpg')).toBe(true);
    expect(await exists('instructorPhotos/ph-1/u1.jpg')).toBe(false);
    expect(pushes).toHaveLength(0); // nothing decided yet, nothing to tell
  });

  it('an approved photo stays while a new one waits', async () => {
    await db().collection('instructors').doc('ph-1').update({
      photoPath: 'instructorPhotos/ph-1/old.jpg', photoApproved: true, photoStatus: 'approved',
    });
    await upload('instructorUploads/ph-1/photo/u2.jpg');
    await finalize('instructorUploads/ph-1/photo/u2.jpg');
    expect(await pub('ph-1')).toMatchObject({
      photoPath: 'instructorPhotos/ph-1/old.jpg', photoApproved: true, photoStatus: 'pending',
    });
  });

  it('keeps one pending upload: a newer one replaces the older', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    await upload('instructorUploads/ph-1/photo/u2.jpg');
    await finalize('instructorUploads/ph-1/photo/u2.jpg');
    expect(await exists('instructorUploads/ph-1/photo/u1.jpg')).toBe(false);
    expect(await exists('instructorUploads/ph-1/photo/u2.jpg')).toBe(true);
    expect((await priv('ph-1')).moderation.photo.uploadId).toBe('u2');
  });
});

describe('onInstructorUpload — emulator auto-approve', () => {
  beforeEach(() => { process.env.FUNCTIONS_EMULATOR = 'true'; });

  it('publishes under a versioned name and removes the upload', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    expect(await pub('ph-1')).toMatchObject({
      photoPath: 'instructorPhotos/ph-1/u1.jpg', photoApproved: true, photoStatus: 'approved',
    });
    expect((await priv('ph-1')).moderation.photo).toMatchObject({ status: 'approved', uploadId: 'u1' });
    expect(await exists('instructorPhotos/ph-1/u1.jpg')).toBe(true);
    expect(await exists('instructorUploads/ph-1/photo/u1.jpg')).toBe(false);
  });

  it('publishes the photo without its GPS position or other metadata', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    const [published] = await bucket().file('instructorPhotos/ph-1/u1.jpg').download();
    const text = published.toString('latin1');
    expect(text).not.toContain('GPSLatitude');
    expect(text).not.toContain('Exif');
    expect(text).toContain('ICC_PROFILE');
    const [meta] = await bucket().file('instructorPhotos/ph-1/u1.jpg').getMetadata();
    expect(meta.contentType).toBe('image/jpeg');
  });

  it('refuses a file that only claims to be a JPEG', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg', Buffer.alloc(2048));
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    expect(await pub('ph-1')).toMatchObject({ photoStatus: 'rejected', photoPath: null, photoApproved: false });
    expect(await exists('instructorUploads/ph-1/photo/u1.jpg')).toBe(false);
    expect(await exists('instructorPhotos/ph-1/u1.jpg')).toBe(false);
  });

  it('a new photo replaces the previous one, which is deleted', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    await upload('instructorUploads/ph-1/photo/u2.jpg');
    await finalize('instructorUploads/ph-1/photo/u2.jpg');
    expect((await pub('ph-1')).photoPath).toBe('instructorPhotos/ph-1/u2.jpg');
    expect(await exists('instructorPhotos/ph-1/u1.jpg')).toBe(false);
    expect(await exists('instructorPhotos/ph-1/u2.jpg')).toBe(true);
  });

  it('tells the instructor the photo is published, opening Профиль', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    expect(pushes).toEqual([{ token: 'tok-1', title: 'Photo published', route: 'profile', kind: 'photo_approved' }]);
  });

  it('tells the instructor a refused photo was not accepted', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg', Buffer.alloc(2048));
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    expect(pushes).toEqual([{ token: 'tok-1', title: "Photo wasn't accepted", route: 'profile', kind: 'photo_rejected' }]);
  });

  it('a redelivered event does not notify twice', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    expect(pushes).toHaveLength(1);
  });

  it('a redelivered event changes nothing', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    const before = await pub('ph-1');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    expect((await pub('ph-1')).updatedAt).toEqual(before.updatedAt);
    expect(await exists('instructorPhotos/ph-1/u1.jpg')).toBe(true);
  });
});

describe('onInstructorUpload — refusals', () => {
  beforeEach(() => { process.env.FUNCTIONS_EMULATOR = 'true'; });

  it('deletes an upload from someone with no instructor profile', async () => {
    await upload('instructorUploads/ph-2/photo/u1.jpg');
    await finalize('instructorUploads/ph-2/photo/u1.jpg');
    expect(await exists('instructorUploads/ph-2/photo/u1.jpg')).toBe(false);
    expect(await exists('instructorPhotos/ph-2/u1.jpg')).toBe(false);
  });

  it('deletes a non-JPEG or an oversized file', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg', { contentType: 'image/png' });
    expect(await exists('instructorUploads/ph-1/photo/u1.jpg')).toBe(false);
    await upload('instructorUploads/ph-1/photo/u2.jpg');
    await finalize('instructorUploads/ph-1/photo/u2.jpg', { size: String(5 * 1024 * 1024) });
    expect(await exists('instructorUploads/ph-1/photo/u2.jpg')).toBe(false);
    expect((await pub('ph-1')).photoStatus).toBe('none');
  });

  it('ignores files outside the photo upload path', async () => {
    await upload('instructorPhotos/ph-1/x.jpg');
    await finalize('instructorPhotos/ph-1/x.jpg');
    await finalize('result_memes/90-100/a.webp', { contentType: 'image/webp' });
    expect(await exists('instructorPhotos/ph-1/x.jpg')).toBe(true);
    expect((await pub('ph-1')).photoStatus).toBe('none');
  });
});
