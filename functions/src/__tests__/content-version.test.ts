/**
 * Risk #47 — there is no content version or cache-bust signal, so a wrong
 * answer or a legally sensitive traffic-rule error cannot be pushed out. It
 * expires out, up to 24 hours later.
 *
 * `getContentVersion` is that signal: one integer the client compares against
 * what it cached. Bumping it makes every device drop its cached content on next
 * launch, regardless of TTL.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import {
  parseContentVersion,
  DEFAULT_CONTENT_VERSION,
  CONTENT_VERSION_COLLECTION,
  CONTENT_VERSION_DOC,
} from '../content-version';

const db = () => admin.firestore();
const docRef = () =>
  db().collection(CONTENT_VERSION_COLLECTION).doc(CONTENT_VERSION_DOC);

const SIGNED_IN = {
  auth: { uid: 'reader', token: { firebase: { sign_in_provider: 'password' } } },
};

const call = (ctx: any) => testEnv.wrap(fns.getContentVersion as any)({} as any, ctx);

afterAll(async () => {
  testEnv.cleanup();
});

describe('Risk #47 — parsing a version out of whatever is in the doc', () => {
  it.each([
    [{ version: 7 }, 7],
    [{ version: 0 }, 0],
    [{ version: 12.9 }, 12], // hand-edited console value
  ])('reads %j as %i', (data, expected) => {
    expect(parseContentVersion(data)).toBe(expected);
  });

  it.each([
    [undefined],
    [null],
    [{}],
    [{ version: 'three' }],
    [{ version: -1 }],
    [{ version: NaN }],
  ])('falls back to the default for %j', (data) => {
    // A malformed version must never read as "newer", or one bad console edit
    // would wipe every device's cache on a loop.
    expect(parseContentVersion(data as any)).toBe(DEFAULT_CONTENT_VERSION);
  });
});

describe('Risk #47 — getContentVersion callable', () => {
  beforeEach(async () => {
    await docRef().delete().catch(() => undefined);
  });

  it('refuses an unauthenticated caller', async () => {
    await expect(call({})).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('returns the default when no version document exists yet', async () => {
    // A fresh project has no contentMeta doc. That must be a working "version
    // 0", not an error, or content stops loading for everyone.
    await expect(call(SIGNED_IN)).resolves.toEqual({
      version: DEFAULT_CONTENT_VERSION,
    });
  });

  it('returns the published version (positive control)', async () => {
    await docRef().set({ version: 42 });
    await expect(call(SIGNED_IN)).resolves.toEqual({ version: 42 });
  });

  it('reflects a bump without redeploying anything', async () => {
    await docRef().set({ version: 1 });
    expect(await call(SIGNED_IN)).toEqual({ version: 1 });

    await docRef().set({ version: 2 });

    expect(await call(SIGNED_IN)).toEqual({ version: 2 });
  });

  it('is NOT entitlement-gated', async () => {
    // Deliberate: `reader` has no subscription. A lapsed user who resubscribes
    // must not be left holding content cached before a correction. The value is
    // one integer and discloses no content.
    await docRef().set({ version: 5 });
    await expect(call(SIGNED_IN)).resolves.toEqual({ version: 5 });
  });
});
