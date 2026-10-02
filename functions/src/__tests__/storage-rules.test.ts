/**
 * Instructors plan v2 §8 — Storage rules for instructor photos. The app
 * uploads to a private pending path (an instructor only, a JPEG under 5 MB,
 * a new name each time); onInstructorUpload publishes it. Approved photos
 * are read by signed-in users, written by the server only; licence images
 * are closed.
 *
 * The upload rule calls firestore.exists(), and the Storage emulator answers
 * it from the project the emulators were started for (singleProjectMode):
 * demo-driveusa under `npm test`, licenseprepapp for the dev emulators
 * (run with STORAGE_RULES_PROJECT=licenseprepapp). So this suite uses that
 * project and never clears Firestore — it only writes and removes its own
 * `sr-*` fixture docs. Files are cleared under the test env's own
 * `<project>.appspot.com` bucket, not the app's `.firebasestorage.app` one,
 * and recursively: env.clearStorage() lists only the top level.
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
    projectId: process.env.STORAGE_RULES_PROJECT || process.env.GCLOUD_PROJECT || 'demo-driveusa',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, '../../../storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

const fixture = (fn: (db: any) => Promise<unknown>) =>
  env.withSecurityRulesDisabled(async (ctx) => { await fn(ctx.firestore()); });

afterAll(async () => {
  await fixture((db) => db.collection('instructors').doc('sr-i1').delete());
  await env.cleanup();
});
async function clearFolder(ref: any): Promise<void> {
  const { items, prefixes } = await ref.listAll();
  await Promise.all([...items.map((i: any) => i.delete()), ...prefixes.map(clearFolder)]);
}
beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const top of ['instructorUploads', 'instructorPhotos', 'instructorLicenses']) {
      await clearFolder(ctx.storage().ref(top));
    }
  });
  // sr-i1 is a registered instructor; sr-s1 is a student.
  await fixture((db) => db.collection('instructors').doc('sr-i1').set({ kind: 'school', status: 'active' }));
});

const storageAs = (uid: string, provider = 'password') =>
  env.authenticatedContext(uid, { firebase: { sign_in_provider: provider } } as any).storage();
const jpeg = (bytes = 1024) => new Uint8Array(bytes);
const put = (s: any, p: string, data: Uint8Array, contentType = 'image/jpeg') =>
  new Promise<void>((resolve, reject) => s.ref(p).put(data, { contentType }).then(() => resolve(), reject));
const seedFile = (p: string) => env.withSecurityRulesDisabled(async (ctx) => {
  await put(ctx.storage(), p, jpeg());
});

describe('instructorUploads/{uid}/photo', () => {
  it('an instructor uploads a JPEG under 5 MB to their own pending path', async () => {
    await assertSucceeds(put(storageAs('sr-i1'), 'instructorUploads/sr-i1/photo/abc123.jpg', jpeg()));
  });

  it('and can read it back; nobody else can', async () => {
    await seedFile('instructorUploads/sr-i1/photo/abc123.jpg');
    await assertSucceeds(storageAs('sr-i1').ref('instructorUploads/sr-i1/photo/abc123.jpg').getMetadata());
    await assertFails(storageAs('sr-s1').ref('instructorUploads/sr-i1/photo/abc123.jpg').getMetadata());
  });

  it('a student (no instructor profile) cannot upload', async () => {
    await assertFails(put(storageAs('sr-s1'), 'instructorUploads/sr-s1/photo/abc123.jpg', jpeg()));
  });

  it("nobody uploads into someone else's folder, and anonymous sessions never", async () => {
    await assertFails(put(storageAs('sr-s1'), 'instructorUploads/sr-i1/photo/abc123.jpg', jpeg()));
    await assertFails(put(storageAs('sr-i1', 'anonymous'), 'instructorUploads/sr-i1/photo/abc123.jpg', jpeg()));
  });

  it('refuses a non-JPEG, a file of 5 MB or more, and a bad name', async () => {
    const s = storageAs('sr-i1');
    await assertFails(put(s, 'instructorUploads/sr-i1/photo/abc123.jpg', jpeg(), 'image/png'));
    await assertFails(put(s, 'instructorUploads/sr-i1/photo/big.jpg', jpeg(5 * 1024 * 1024)));
    await assertFails(put(s, 'instructorUploads/sr-i1/photo/abc123.png', jpeg()));
    await assertFails(put(s, 'instructorUploads/sr-i1/photo/../x.jpg', jpeg()));
    await assertFails(put(s, 'instructorUploads/sr-i1/license/abc123.jpg', jpeg()));
  });

  it('an upload is never overwritten or deleted by the client', async () => {
    await seedFile('instructorUploads/sr-i1/photo/abc123.jpg');
    await assertFails(put(storageAs('sr-i1'), 'instructorUploads/sr-i1/photo/abc123.jpg', jpeg()));
    await assertFails(storageAs('sr-i1').ref('instructorUploads/sr-i1/photo/abc123.jpg').delete());
  });
});

describe('instructorPhotos and instructorLicenses', () => {
  it('signed-in users read approved photos; anonymous sessions do not', async () => {
    await seedFile('instructorPhotos/sr-i1/abc123.jpg');
    await assertSucceeds(storageAs('sr-s1').ref('instructorPhotos/sr-i1/abc123.jpg').getMetadata());
    await assertFails(storageAs('sr-s1', 'anonymous').ref('instructorPhotos/sr-i1/abc123.jpg').getMetadata());
  });

  it('only the server writes approved photos — not even the owner', async () => {
    await assertFails(put(storageAs('sr-i1'), 'instructorPhotos/sr-i1/abc123.jpg', jpeg()));
  });

  it('licence images are closed both ways', async () => {
    await seedFile('instructorLicenses/sr-i1/abc123.jpg');
    await assertFails(storageAs('sr-i1').ref('instructorLicenses/sr-i1/abc123.jpg').getMetadata());
    await assertFails(put(storageAs('sr-i1'), 'instructorLicenses/sr-i1/x.jpg', jpeg()));
  });
});
