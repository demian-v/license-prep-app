/**
 * Instructors plan v2 §8 — onInstructorUpload, the step between the private
 * upload and what students see. SafeSearch (a fake Vision client here, no
 * request leaves jest) decides in every environment: a clean photo is
 * copied to a versioned public name; LIKELY+ is refused; a Vision error
 * holds it `pending`, fail-closed, for an admin (P10b).
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { phonePhoto } from './helpers/jpeg';
import { setPushTransport } from '../push';
import { SafeSearch, fakeVision, setVisionClient, vision, VISION_TEST_MARKER } from '../vision-client';

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
  await bucket().deleteFiles({ prefix: 'instructorLicenses/ph-' }).catch(() => {});
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
afterAll(async () => { setPushTransport(null); setVisionClient(null); await wipe(); testEnv.cleanup(); });

// The fake Vision's answer for the next photo.
let verdict: 'ok' | 'unsafe' | 'error' = 'ok';
const seen: number[] = [];
beforeEach(() => {
  verdict = 'ok';
  seen.length = 0;
  setVisionClient({
    async safeSearch(jpeg): Promise<SafeSearch> {
      seen.push(jpeg.length);
      if (verdict === 'error') throw new Error('Vision: 503');
      return verdict === 'unsafe'
        ? { adult: 'LIKELY', violence: 'VERY_UNLIKELY', racy: 'POSSIBLE' }
        : { adult: 'VERY_UNLIKELY', violence: 'UNLIKELY', racy: 'POSSIBLE' };
    },
  });
});

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

describe('onInstructorUpload — Vision down: held, fail-closed', () => {
  beforeEach(() => { verdict = 'error'; });

  it('keeps a new photo pending and shows nothing unmoderated', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    expect(await pub('ph-1')).toMatchObject({ photoStatus: 'pending', photoPath: null, photoApproved: false });
    expect((await priv('ph-1')).moderation).toMatchObject({
      photo: { status: 'pending', uploadId: 'u1', reason: 'vision_error' }, license: { status: 'none' },
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

describe('onInstructorUpload — SafeSearch', () => {
  it('checks the photo, then publishes a clean one', async () => {
    await upload('instructorUploads/ph-1/photo/u1.jpg');
    await finalize('instructorUploads/ph-1/photo/u1.jpg');
    expect(seen).toHaveLength(1);
    expect(await pub('ph-1')).toMatchObject({ photoStatus: 'approved', photoPath: 'instructorPhotos/ph-1/u1.jpg' });
  });

  it('refuses LIKELY or above: upload deleted, an older photo kept, a push', async () => {
    await db().collection('instructors').doc('ph-1').update({
      photoPath: 'instructorPhotos/ph-1/old.jpg', photoApproved: true, photoStatus: 'approved',
    });
    verdict = 'unsafe';
    await upload('instructorUploads/ph-1/photo/u2.jpg');
    await finalize('instructorUploads/ph-1/photo/u2.jpg');
    expect(await pub('ph-1')).toMatchObject({ photoPath: 'instructorPhotos/ph-1/old.jpg', photoApproved: true, photoStatus: 'rejected' });
    expect((await priv('ph-1')).moderation.photo).toMatchObject({ status: 'rejected', reason: 'safesearch' });
    expect(await exists('instructorUploads/ph-1/photo/u2.jpg')).toBe(false);
    expect(await exists('instructorPhotos/ph-1/u2.jpg')).toBe(false);
    expect(pushes).toEqual([expect.objectContaining({ title: "Photo wasn't accepted" })]);
  });

  it('the emulator always gets the fake Vision, never the real API', () => {
    setVisionClient(null);
    process.env.FUNCTIONS_EMULATOR = 'true';
    expect(vision()).toBe(fakeVision);
  });

  it("the emulator's fake holds or refuses only a JPEG with the test marker", async () => {
    const marked = (m: string) => Buffer.concat([phonePhoto(), Buffer.from(`${VISION_TEST_MARKER}${m}`, 'latin1')]);
    await expect(fakeVision.safeSearch(phonePhoto())).resolves.toMatchObject({ adult: 'VERY_UNLIKELY' });
    await expect(fakeVision.safeSearch(marked('error'))).rejects.toThrow('simulated');
    await expect(fakeVision.safeSearch(marked('unsafe'))).resolves.toMatchObject({ adult: 'VERY_LIKELY' });
  });
});

describe('onInstructorUpload — a clean photo is published', () => {
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

  it('moves the instructor\'s chat threads to the new photo (P6)', async () => {
    const thread = admin.firestore().collection('conversations').doc('ph-s_ph-1');
    await thread.set({ studentUid: 'ph-s', instructorUid: 'ph-1', participantUids: ['ph-s', 'ph-1'], instructorPhotoPath: null });
    try {
      await upload('instructorUploads/ph-1/photo/u1.jpg');
      await finalize('instructorUploads/ph-1/photo/u1.jpg');
      expect((await thread.get()).get('instructorPhotoPath')).toBe('instructorPhotos/ph-1/u1.jpg');
    } finally {
      await thread.delete();
    }
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

describe('onInstructorUpload — licence photo (P10b)', () => {
  // Production behaviour: a licence image is filed at once (never public, so
  // no SafeSearch gate), unlike the profile photo.
  it('files it privately without its metadata, in production too, and keeps licenseCheck', async () => {
    await db().collection('instructors').doc('ph-1').update({ licenseCheck: 'pending' });
    await upload('instructorUploads/ph-1/license/l1.jpg');
    await finalize('instructorUploads/ph-1/license/l1.jpg');
    expect(await exists('instructorUploads/ph-1/license/l1.jpg')).toBe(false);
    const [filed] = await bucket().file('instructorLicenses/ph-1/l1.jpg').download();
    expect(filed.toString('latin1')).not.toContain('GPSLatitude');
    const p = await priv('ph-1');
    expect(p).toMatchObject({ licenseImagePath: 'instructorLicenses/ph-1/l1.jpg', licenseImageBucket: BUCKET, moderation: { license: { status: 'received', uploadId: 'l1' } } });
    const u = await pub('ph-1');
    expect(u).toMatchObject({ licensePhotoStatus: 'received', licenseCheck: 'pending', photoStatus: 'none' });
    expect(u.licensePhotoAt).toBeDefined();
    expect(pushes).toHaveLength(0);
  });

  it('a new licence photo replaces the previous one', async () => {
    await upload('instructorUploads/ph-1/license/l1.jpg');
    await finalize('instructorUploads/ph-1/license/l1.jpg');
    await upload('instructorUploads/ph-1/license/l2.jpg');
    await finalize('instructorUploads/ph-1/license/l2.jpg');
    expect(await exists('instructorLicenses/ph-1/l1.jpg')).toBe(false);
    expect(await exists('instructorLicenses/ph-1/l2.jpg')).toBe(true);
    expect((await priv('ph-1')).licenseImagePath).toBe('instructorLicenses/ph-1/l2.jpg');
  });

  it('refuses an unreadable file, a non-JPEG and someone with no profile', async () => {
    await upload('instructorUploads/ph-1/license/l3.jpg', Buffer.alloc(2048));
    await finalize('instructorUploads/ph-1/license/l3.jpg');
    expect(await exists('instructorLicenses/ph-1/l3.jpg')).toBe(false);
    expect((await pub('ph-1')).licensePhotoStatus).toBe('unreadable');
    await upload('instructorUploads/ph-1/license/l4.jpg');
    await finalize('instructorUploads/ph-1/license/l4.jpg', { contentType: 'image/png' });
    expect(await exists('instructorUploads/ph-1/license/l4.jpg')).toBe(false);
    await upload('instructorUploads/ph-2/license/l5.jpg');
    await finalize('instructorUploads/ph-2/license/l5.jpg');
    expect(await exists('instructorLicenses/ph-2/l5.jpg')).toBe(false);
  });
});
