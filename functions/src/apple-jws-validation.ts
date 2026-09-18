/**
 * Risk #56 — validate a StoreKit 2 JWS transaction.
 *
 * The other half of `validateAppleReceipt`. Apple's legacy `verifyReceipt`
 * endpoint cannot read a JWS, so this verifies the signature locally with
 * `SignedDataVerifier` — the same library, and the same production-then-sandbox
 * dance, that `appStoreWebhook` already uses successfully for
 * `signedTransactionInfo`.
 *
 * Returns the **same shape** as `validateAppleReceipt` on purpose. Everything
 * downstream — the `subscriptions` write, the idempotency guard on
 * `transactionId`, the webhook matching on `originalTransactionId`, the risk
 * #27 environment tag — then works without knowing which format arrived.
 *
 * Sequencing, from the register: this is deployed and verified **before** any
 * iOS client change, so the risky change lands on a backend that cannot be
 * broken by it.
 */
import {
  SignedDataVerifier,
  Environment,
  VerificationStatus,
} from '@apple/app-store-server-library';
import * as fs from 'fs';
import * as path from 'path';

/**
 * The **only** definition of the bundle id, used by this JWS path and by
 * `appStoreWebhook` in `index.ts`, which imports it from here.
 *
 * VERIFY it matches App Store Connect before deploying. If it is wrong, every
 * webhook verification fails **silently** — the error is caught, answered 200,
 * and no subscription state is updated. It was briefly declared in two places;
 * one value that cannot disagree with itself beats a test that notices when two
 * do.
 */
export const APPLE_BUNDLE_ID = 'com.driveusa.app';

/**
 * Loaded on first use, not at import. `receipt-validation.ts` is imported by
 * unit tests that have no business reading certificates off disk.
 */
let cachedRootCAs: Buffer[] | null = null;

function appleRootCAs(): Buffer[] {
  if (cachedRootCAs) return cachedRootCAs;
  // __dirname is functions/lib at runtime (tsconfig outDir "lib", rootDir
  // "src") and functions/src under ts-jest. One "../" reaches functions/certs
  // from either. Same file and same reasoning as index.ts.
  cachedRootCAs = [
    fs.readFileSync(path.join(__dirname, '../certs/AppleRootCA-G3.cer')),
  ];
  return cachedRootCAs;
}

/**
 * `APPLE_APP_ID` is declared once, as a param in `index.ts`. Reading the
 * environment here rather than calling `defineInt` again avoids declaring the
 * same param twice in one codebase; the value is the same either way.
 *
 * A missing or zero value is passed as `undefined`, which the library requires
 * for Sandbox and rejects for Production — the same behaviour as the webhook.
 * The register's Top-7 #5 is exactly this: unset in production means
 * verification runs against app id 0.
 */
function appleAppIdOrUndefined(): number | undefined {
  const raw = Number.parseInt(process.env.APPLE_APP_ID ?? '', 10);
  return Number.isFinite(raw) && raw > 0 ? raw : undefined;
}

function makeVerifier(env: Environment): SignedDataVerifier {
  return new SignedDataVerifier(
    appleRootCAs(),
    true, // enableOnlineChecks (OCSP)
    env,
    APPLE_BUNDLE_ID,
    appleAppIdOrUndefined(),
  );
}

export interface AppleJwsValidationResult {
  valid: boolean;
  expiresAt?: Date;
  transactionId?: string;
  originalTransactionId?: string;
  actualProductId?: string;
  environment?: 'sandbox' | 'production';
  error?: string;
}

/**
 * Verify a `signedTransactionInfo` JWS and apply the same rules the legacy
 * path applies: the product must be the one that was asked for, the
 * subscription must not be revoked, and it must not have expired.
 */
export async function validateAppleJwsTransaction(
  signedTransactionInfo: string,
  productId: string,
): Promise<AppleJwsValidationResult> {
  console.log('🍎 Starting Apple JWS (StoreKit 2) validation');
  console.log(`📦 Product ID: ${productId}`);

  let payload;
  let verifiedIn: Environment;

  try {
    // In the emulator there is no production data to verify against. In
    // production, try production first and fall back only on an explicit
    // environment mismatch — the same order as appStoreWebhook.
    const primaryEnv = process.env.FUNCTIONS_EMULATOR
      ? Environment.SANDBOX
      : Environment.PRODUCTION;

    try {
      payload = await makeVerifier(primaryEnv).verifyAndDecodeTransaction(
        signedTransactionInfo,
      );
      verifiedIn = primaryEnv;
    } catch (e: unknown) {
      const status = (e as { status?: number } | null)?.status;
      if (
        status === VerificationStatus.INVALID_ENVIRONMENT &&
        primaryEnv === Environment.PRODUCTION
      ) {
        // A sandbox transaction sent to the production verifier: TestFlight
        // builds and sandbox testers. Expected, not an error.
        console.log('🧪 INVALID_ENVIRONMENT — retrying as Sandbox');
        payload = await makeVerifier(
          Environment.SANDBOX,
        ).verifyAndDecodeTransaction(signedTransactionInfo);
        verifiedIn = Environment.SANDBOX;
      } else {
        throw e;
      }
    }
  } catch (error: unknown) {
    // A signature that does not verify is not a transient failure — retrying
    // will not change the answer, so say so plainly rather than inviting the
    // client to try again.
    const status = (error as { status?: number } | null)?.status;
    const statusName =
      status !== undefined ? VerificationStatus[status] ?? String(status) : 'unknown';
    console.error(
      `❌ JWS verification failed (${statusName}):`,
      error instanceof Error ? error.message : String(error),
    );
    return {
      valid: false,
      error: `Receipt signature could not be verified (${statusName}). Please contact support.`,
    };
  }

  // The payload's own environment is more truthful than which verifier
  // happened to succeed, but either answers risk #27.
  const environment: 'sandbox' | 'production' =
    payload.environment === Environment.SANDBOX ||
    verifiedIn === Environment.SANDBOX
      ? 'sandbox'
      : 'production';
  console.log(`🌍 Environment: ${environment.toUpperCase()}`);

  // Strict product matching, same rule and same reason as the legacy path: a
  // silent fallback to another plan records the wrong subscription.
  if (payload.productId !== productId) {
    console.error(
      `❌ Product "${productId}" requested but transaction is for "${payload.productId}"`,
    );
    return {
      valid: false,
      error:
        `Receipt does not contain "${productId}". ` +
        `Available products: [${payload.productId ?? 'none'}]. Please contact support.`,
    };
  }

  if (payload.revocationDate) {
    const revokedAt = new Date(payload.revocationDate);
    console.warn(`⚠️ Transaction was revoked at: ${revokedAt.toISOString()}`);
    return {
      valid: false,
      error: `Subscription was cancelled on ${revokedAt.toISOString()}`,
    };
  }

  // Auto-renewable subscriptions always carry expiresDate. Its absence means
  // this is not the kind of product this app sells, and guessing an expiry
  // would grant entitlement for a period nobody agreed to.
  if (!payload.expiresDate) {
    console.error('❌ Transaction has no expiresDate');
    return {
      valid: false,
      error: 'No subscription expiry found in receipt',
    };
  }

  const expiresAt = new Date(payload.expiresDate);
  const now = new Date();
  console.log(`⏰ Expires at: ${expiresAt.toISOString()}`);

  if (expiresAt < now) {
    const minutesAgo = Math.round((now.getTime() - expiresAt.getTime()) / 60000);
    console.error(`❌ Subscription expired ${minutesAgo} minutes ago`);
    return {
      valid: false,
      error: `Subscription expired on ${expiresAt.toISOString()}`,
    };
  }

  // transactionId changes every billing cycle and originalTransactionId does
  // not. Both are carried out for the same reasons as the legacy path: the
  // first keeps renewals from colliding with the idempotency guard, the second
  // is what appStoreWebhook matches on.
  console.log('🎉 JWS validation successful');
  return {
    valid: true,
    expiresAt,
    transactionId: payload.transactionId,
    originalTransactionId: payload.originalTransactionId,
    actualProductId: payload.productId,
    environment,
  };
}
