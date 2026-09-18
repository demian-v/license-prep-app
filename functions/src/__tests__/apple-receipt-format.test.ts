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

describe('exactly one bundle id', () => {
  /**
   * A wrong bundle id costs **every** webhook verification, silently: the
   * error is caught, the request answered 200, and no subscription state moves.
   * `index.ts` used to declare its own copy alongside the JWS path's, so the
   * two could drift into exactly that.
   *
   * The first version of this test only asserted the two literals *agreed*,
   * which catches divergence solely when someone runs the suite. The constant
   * now exists once and `index.ts` imports it, so these tests defend the
   * stronger property: there is nothing to diverge.
   */
  const read = (p: string) =>
    fs.readFileSync(path.join(__dirname, '..', p), 'utf8');

  it('is defined in apple-jws-validation and nowhere else', () => {
    const definition = /APPLE_BUNDLE_ID\s*=\s*'([^']+)'/;

    expect(read('apple-jws-validation.ts').match(definition)?.[1]).toBe(
      'com.driveusa.app',
    );

    // Any other module that assigns it has reintroduced the second copy.
    const others = fs
      .readdirSync(path.join(__dirname, '..'))
      .filter((f) => f.endsWith('.ts') && f !== 'apple-jws-validation.ts');
    for (const file of others) {
      expect(read(file)).not.toMatch(definition);
    }
  });

  it('is imported by index.ts rather than redeclared', () => {
    const src = read('index.ts');
    expect(src).toMatch(
      /import\s*\{[^}]*APPLE_BUNDLE_ID[^}]*\}\s*from\s*'\.\/apple-jws-validation'/,
    );
    // And still reaches the webhook's verifier.
    expect(src).toMatch(/new SignedDataVerifier\([\s\S]{0,200}APPLE_BUNDLE_ID/);
  });

  it('matches the Android applicationId, which is the real one', () => {
    const gradle = fs.readFileSync(
      path.join(__dirname, '../../../android/app/build.gradle'),
      'utf8',
    );
    expect(gradle).toContain('applicationId = "com.driveusa.app"');
  });

  it('and the compiled output carries the literal into the verifier', () => {
    // The refactor's real risk is that the value stops reaching the verifier
    // at runtime, which a source-level check cannot see. tsconfig emits to
    // lib/, so if a build is present, read what actually ships. Skipped rather
    // than failed when lib/ is stale or absent — `npm run build` runs in
    // predeploy, so the deployed artefact is always freshly compiled.
    const compiled = path.join(__dirname, '../../lib/index.js');
    if (!fs.existsSync(compiled)) return;
    const js = fs.readFileSync(compiled, 'utf8');
    expect(js).toMatch(/SignedDataVerifier\([\s\S]{0,300}APPLE_BUNDLE_ID/);
  });
});
