import * as fs from 'fs';
import * as path from 'path';
import {
  detectAppleReceiptFormat,
  usesStoreKit2,
} from '../apple-receipt-format';

/**
 * Risk #56 — the server must read both of Apple's receipt formats.
 *
 * Today `validateAppleReceipt` posts whatever it is given to the legacy
 * `verifyReceipt` endpoint. A StoreKit 2 JWS comes back 21002 ("malformed
 * receipt"), so iOS purchases only work because `main()` calls
 * `enableStoreKit1()` — one line of client ordering, against a deprecated API.
 *
 * The register's sequencing is deliberate and these tests encode it: make the
 * **server** format-aware first, deploy it, and only then let the client move.
 * A backend that accepts both cannot be broken by a client that changes.
 */

/** A structurally real JWS: three base64url segments, header decodes to JSON. */
const b64url = (o: unknown) =>
  Buffer.from(JSON.stringify(o)).toString('base64url');
const JWS = [
  b64url({ alg: 'ES256', x5c: ['MIIBo...'] }),
  b64url({ transactionId: '2000000123', productId: 'monthly' }),
  'MEUCIQDsignaturebytes',
].join('.');

/** What the shipped build sends: base64 PKCS#7, no dots. */
const APP_RECEIPT =
  'MIITuQYJKoZIhvcNAQcCoIITqjCCE6YCAQExCzAJBgUrDgMCGgUAMIIDWgYJKoZIhvcNAQcBoIIDSwSCA0cxggNDMAoCAQgCAQEEAhYA';

describe('risk #56 — which format is this receipt', () => {
  it('recognises a StoreKit 2 JWS', () => {
    expect(detectAppleReceiptFormat(JWS)).toBe('jws');
    expect(usesStoreKit2(JWS)).toBe(true);
  });

  it('recognises the base64 app receipt the live build sends', () => {
    expect(detectAppleReceiptFormat(APP_RECEIPT)).toBe('app-receipt');
    expect(usesStoreKit2(APP_RECEIPT)).toBe(false);
  });

  it('tolerates whitespace around either form', () => {
    expect(detectAppleReceiptFormat(`\n  ${JWS}\t`)).toBe('jws');
    expect(detectAppleReceiptFormat(`  ${APP_RECEIPT}  `)).toBe('app-receipt');
  });

  it.each([
    ['empty', ''],
    ['whitespace only', '   \n'],
    ['two segments', 'eyJhbGciOiJFUzI1NiJ9.payload'],
    ['four segments', 'eyJhbGciOiJFUzI1NiJ9.a.b.c'],
    ['three segments, header not JSON', 'notjson.payload.signature'],
    ['three segments, empty payload', 'eyJhbGciOiJFUzI1NiJ9..signature'],
    ['three segments, empty signature', 'eyJhbGciOiJFUzI1NiJ9.payload.'],
    ['header is only the prefix', 'eyJ.payload.signature'],
    ['not base64 at all', 'hello world!'],
  ])('refuses to call %s a JWS', (_label, input) => {
    expect(usesStoreKit2(input)).toBe(false);
  });

  it('survives a non-string without throwing', () => {
    // The receipt arrives from the client over the wire. A callable's payload
    // is whatever the caller sent, and this runs before any validation.
    expect(
      detectAppleReceiptFormat(undefined as unknown as string),
    ).toBe('unknown');
    expect(detectAppleReceiptFormat(null as unknown as string)).toBe('unknown');
    expect(detectAppleReceiptFormat(12345 as unknown as string)).toBe('unknown');
  });
});

describe('the asymmetry is the whole design', () => {
  /**
   * The two possible mistakes cost very different amounts:
   *
   *   app receipt read as JWS -> the verifier rejects it -> a WORKING purchase
   *                              breaks, for a paying customer, after Apple
   *                              has already charged them
   *   JWS read as app receipt -> verifyReceipt returns 21002 -> exactly the
   *                              failure we have today, no worse
   *
   * So the detector must only claim 'jws' when it is certain, and everything
   * else must fall through to the legacy path.
   */
  it('anything uncertain falls through to the legacy path', () => {
    const uncertain = [
      '',
      'MII',
      'eyJ',
      'eyJ.',
      '...',
      'a.b',
      'one.two.three.four',
      '!!!not base64!!!',
      'has spaces in it',
    ];
    for (const input of uncertain) {
      expect(usesStoreKit2(input)).toBe(false);
    }
  });

  it('never classifies a base64 blob as a JWS, at any length', () => {
    // App receipts run to tens of kilobytes. Length must not enter into it.
    for (const len of [4, 100, 5000, 40000]) {
      const blob = 'M'.repeat(len);
      expect(detectAppleReceiptFormat(blob)).toBe('app-receipt');
      expect(usesStoreKit2(blob)).toBe(false);
    }
  });
});

describe('the routing is wired into validateAppleReceipt', () => {
  // The function is private and its real path posts to Apple, so this asserts
  // on the source: the JWS branch must be taken BEFORE the legacy request is
  // built, or a JWS would still reach verifyReceipt.
  const src = fs.readFileSync(
    path.join(__dirname, '../receipt-validation.ts'),
    'utf8',
  );
  const body = src.slice(src.indexOf('async function validateAppleReceipt'));
  const code = body
    .split('\n')
    .filter((l) => {
      const t = l.trim();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

  it('calls the detector', () => {
    expect(code).toMatch(/usesStoreKit2\(|detectAppleReceiptFormat\(/);
  });

  it('routes JWS to the StoreKit 2 verifier before touching verifyReceipt', () => {
    const routed = code.search(/validateAppleJwsTransaction\(/);
    const legacy = code.search(/'receipt-data'/);
    expect(routed).toBeGreaterThan(-1);
    expect(legacy).toBeGreaterThan(-1);
    expect(routed).toBeLessThan(legacy);
  });
});

describe('one bundle id, not two', () => {
  /**
   * `index.ts` carries its own `APPLE_BUNDLE_ID` for the webhook verifier, and
   * its comment says what a wrong value costs: **every** webhook verification
   * fails silently, caught and answered 200 with no processing. The JWS path
   * needs the same constant.
   *
   * The webhook is live money-path code with no test coverage of its own, so
   * it was left untouched rather than refactored onto a shared import. This
   * test is the price of that decision: if the two literals ever diverge, it
   * fails here instead of going quiet in production.
   */
  const read = (p: string) =>
    fs.readFileSync(path.join(__dirname, '..', p), 'utf8');
  const bundleIdIn = (file: string) =>
    read(file).match(/APPLE_BUNDLE_ID\s*=\s*'([^']+)'/)?.[1];

  it('index.ts and the JWS verifier agree', () => {
    const webhook = bundleIdIn('index.ts');
    const jws = bundleIdIn('apple-jws-validation.ts');
    expect(webhook).toBeDefined();
    expect(jws).toBeDefined();
    expect(jws).toBe(webhook);
  });

  it('and both match the Android applicationId, which is the real one', () => {
    const gradle = fs.readFileSync(
      path.join(__dirname, '../../../android/app/build.gradle'),
      'utf8',
    );
    expect(gradle).toContain('applicationId = "com.driveusa.app"');
    expect(bundleIdIn('apple-jws-validation.ts')).toBe('com.driveusa.app');
  });
});
