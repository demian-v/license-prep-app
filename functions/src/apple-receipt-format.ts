/**
 * Risk #56 — tell an App Store receipt from a StoreKit 2 JWS.
 *
 * The client can send either of two unrelated things in the same `receipt`
 * field, and the server has to work out which:
 *
 * - a **base64 app receipt**, which is a PKCS#7 DER blob. This is what
 *   StoreKit 1 produces and what Apple's legacy `verifyReceipt` endpoint
 *   accepts. It is what the shipped iOS build sends today.
 * - a **JWS transaction**, three base64url segments separated by dots, signed
 *   by Apple. This is what StoreKit 2 produces. `verifyReceipt` cannot read it
 *   and rejects it with status 21002 ("malformed receipt").
 *
 * Until now the server only understood the first, and iOS was held on
 * StoreKit 1 by a single `enableStoreKit1()` call in `main()` — one line of
 * client ordering standing between every iOS purchase and a 21002. Apple has
 * that call on a deprecation clock, so the server needs to read both before
 * the client is allowed to change.
 *
 * Kept as its own module with no imports so the decision is testable without
 * Firebase, Apple, or the network.
 */

export type AppleReceiptFormat = 'jws' | 'app-receipt' | 'unknown';

/** Base64url of `{"`, the first two characters of every JWS header. */
const JWS_HEADER_PREFIX = 'eyJ';

/** Standard base64, padding included. App receipts carry no dots or dashes. */
const BASE64_ONLY = /^[A-Za-z0-9+/]+={0,2}$/;

/**
 * Which of Apple's two receipt formats this string is.
 *
 * **Deliberately conservative.** Only a confident JWS match returns `'jws'`;
 * everything else falls through to the legacy path, which is exactly today's
 * behaviour. That ordering matters: misreading an app receipt as a JWS would
 * break working purchases, while misreading a JWS as an app receipt only
 * reproduces the 21002 we already get. The costly mistake is the one this
 * cannot make.
 */
export function detectAppleReceiptFormat(receipt: string): AppleReceiptFormat {
  if (typeof receipt !== 'string') return 'unknown';

  const trimmed = receipt.trim();
  if (trimmed.length === 0) return 'unknown';

  const segments = trimmed.split('.');

  if (segments.length === 3) {
    const [header, payload, signature] = segments;
    // All three must be present — "a..b" is not a JWS — and the header must
    // decode to JSON. A three-part string that fails either test is not
    // something to hand to the verifier.
    if (
      header.startsWith(JWS_HEADER_PREFIX) &&
      header.length > JWS_HEADER_PREFIX.length &&
      payload.length > 0 &&
      signature.length > 0
    ) {
      return 'jws';
    }
    return 'unknown';
  }

  // No dots and nothing but base64: an app receipt. Real ones begin `MII`
  // (the DER SEQUENCE header), but that is NOT required here — rejecting a
  // receipt for failing a prefix check we invented is how working purchases
  // break, and Apple is the authority on whether its own receipt is valid.
  if (segments.length === 1 && BASE64_ONLY.test(trimmed)) {
    return 'app-receipt';
  }

  return 'unknown';
}

/**
 * Whether this receipt should go to the StoreKit 2 verifier.
 *
 * The routing decision in one place, so `validateAppleReceipt` cannot drift
 * from what the tests assert. Anything that is not a confident JWS goes to
 * `verifyReceipt`, unchanged.
 */
export function usesStoreKit2(receipt: string): boolean {
  return detectAppleReceiptFormat(receipt) === 'jws';
}
