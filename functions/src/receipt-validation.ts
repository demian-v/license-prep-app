// Phase 2: iOS Receipt Validation - IMPLEMENTED ✅
// Phase 3: Android Receipt Validation - IMPLEMENTED ✅
// Phase 4: Firestore Integration - Pending
import * as functions from 'firebase-functions/v1';
import { defineSecret } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import axios from 'axios';
import { google } from 'googleapis';

// ============================================================================
// SECRETS (Firebase Secret Manager)
// ============================================================================

const appleSharedSecret = defineSecret('APPLE_SHARED_SECRET');
const googleCredentials = defineSecret('GOOGLE_CREDENTIALS');

// ============================================================================
// INTERFACES & TYPES
// ============================================================================

/**
 * Request data structure from the Flutter app
 */
interface ReceiptValidationRequest {
  receipt: string;              // Base64 receipt data (iOS) or purchase token (Android)
  platform: 'ios' | 'android';  // Which store
  productId: string;            // monthly, yearly, or trial
}

/**
 * Standardized validation result returned to the app
 */
interface ValidationResult {
  valid: boolean;
  message: string;
  subscriptionId?: string;
  expiresAt?: string;
  productId?: string;
  platform?: string;
  transactionId?: string;
}

// ============================================================================
// CONSTANTS
// ============================================================================

// Apple App Store verification URLs
const APPLE_SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';
const APPLE_PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';

// Product ID mapping (matches your App Store/Play Store product IDs).
//
// YEARLY is retained deliberately (risk #6). The app no longer offers it —
// owner decision 2026-09-16, only the 30-day plan is sold — but the backend
// must still accept a yearly receipt, or a legacy or in-flight purchase would
// be charged and receive nothing. Removing it here would recreate exactly the
// failure #6 describes, one layer down.
const PRODUCT_IDS = {
  MONTHLY: 'monthly',
  YEARLY: 'yearly',
  TRIAL: 'trial'
};

// Apple receipt status codes
const APPLE_STATUS_CODES: { [key: number]: string } = {
  0: 'Valid receipt',
  21000: 'The App Store could not read the JSON object you provided',
  21002: 'The data in the receipt-data property was malformed or missing',
  21003: 'The receipt could not be authenticated',
  21004: 'The shared secret you provided does not match the shared secret on file',
  21005: 'The receipt server is not currently available',
  21006: 'This receipt is valid but the subscription has expired',
  21007: 'This receipt is from the test environment (sandbox)',
  21008: 'This receipt is from the production environment',
  21009: 'Internal data access error',
  21010: 'The user account cannot be found or has been deleted'
};

// ============================================================================
// ANDROID CONFIGURATION
// ============================================================================

// Android package name (from build.gradle)
const ANDROID_PACKAGE_NAME = 'com.driveusa.app';

// Google Play subscription states
const GOOGLE_PLAY_STATES = {
  ACTIVE: 'SUBSCRIPTION_STATE_ACTIVE',
  EXPIRED: 'SUBSCRIPTION_STATE_EXPIRED',
  CANCELLED: 'SUBSCRIPTION_STATE_CANCELED',
  IN_GRACE_PERIOD: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  ON_HOLD: 'SUBSCRIPTION_STATE_ON_HOLD',
  PAUSED: 'SUBSCRIPTION_STATE_PAUSED',
  PENDING: 'SUBSCRIPTION_STATE_PENDING'
};

// ============================================================================
// PHASE 5: RATE LIMITING CONFIGURATION
// ============================================================================

// Successful validations per hour. A real user needs a handful; iOS sandbox
// renews every 5 minutes, which is why this is not lower.
const RATE_LIMIT_MAX_VALIDATIONS = 10;
// Failed attempts per hour, counted SEPARATELY (risk #19). Failures used to
// share the success budget, so ten transient errors locked out the next real
// purchase. This still stops a flood, without punishing a paying customer for
// a bad network or an Apple 21005.
const RATE_LIMIT_MAX_FAILURES = 30;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;  // 1 hour in milliseconds

// Risk #40 — cap on how many log rows one rate-limit check will read.
//
// The query is indexed on (userId, timestamp, action), so it does not get
// slower as subscriptionLogs grows overall — only as one user's attempts in the
// window grow. It had no limit, so a client hammering validation made every
// subsequent check read every one of its own attempts, on the purchase path.
//
// This bound is safe to act on without counting further: if the query returns
// this many rows then successes >= MAX_VALIDATIONS or failures >= MAX_FAILURES
// must already hold, because otherwise the total could be at most
// (MAX_VALIDATIONS - 1) + (MAX_FAILURES - 1), which is smaller.
export const RATE_LIMIT_SCAN_LIMIT = RATE_LIMIT_MAX_VALIDATIONS + RATE_LIMIT_MAX_FAILURES;

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Get Google Service Account credentials (Phase 5: Security)
 * Loads from Firebase Config only (secure)
 */
function getGoogleCredentials(): any {
  // Load from Secret Manager
  const configCreds = googleCredentials.value();
  
  if (!configCreds) {
    console.error('❌ CRITICAL: GOOGLE_CREDENTIALS secret not set in Secret Manager!');
    throw new Error('Google credentials must be configured in Firebase Secret Manager');
  }
  
  console.log('✅ Google credentials loaded from Secret Manager');
  
  // Decode base64 credentials
  const decoded = Buffer.from(configCreds, 'base64').toString('utf-8');
  return JSON.parse(decoded);
}

/**
 * Check whether the user has exceeded their validation rate limit (risk #19).
 *
 * Successes and failures are counted against SEPARATE budgets. Previously a
 * single 10/hour cap covered receipt_validated, receipt_validation_failed and
 * receipt_validation_error together, so ten transient failures exhausted the
 * quota and the eleventh attempt — the one that would have succeeded — was
 * refused with resource-exhausted, after the user had already been charged.
 *
 * The Firestore query is deliberately UNCHANGED in shape: same userId equality,
 * same timestamp range, same `action in [...]` triple. It is served by the
 * existing composite index on subscriptionLogs (userId, timestamp, action).
 * Splitting it into two queries, or dropping the action filter, would need a
 * different index — and firebase.json does not deploy indexes (risk #15), so a
 * query shape change here could break every purchase in production. The
 * partitioning is done in code instead.
 *
 * Fails OPEN. If Firestore cannot answer — a missing index, an outage — this
 * returns false and the purchase proceeds. A rate limiter exists to deter
 * abuse; it must never be the reason a paid purchase fails, particularly here,
 * where the call site sits outside the caller's try block and the money has
 * already left the customer's account. Abuse remains bounded by store-side
 * receipt verification and the receipt→account binding (risk #5).
 */
export async function checkRateLimit(userId: string): Promise<boolean> {
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;

  try {
    const db = admin.firestore();
    const recentAttempts = await db.collection('subscriptionLogs')
      .where('userId', '==', userId)
      .where('timestamp', '>', Timestamp.fromMillis(windowStart))
      .where('action', 'in', ['receipt_validated', 'receipt_validation_failed', 'receipt_validation_error'])
      .limit(RATE_LIMIT_SCAN_LIMIT)
      .get();

    // Hitting the cap is itself a decision: see RATE_LIMIT_SCAN_LIMIT.
    if (recentAttempts.size >= RATE_LIMIT_SCAN_LIMIT) {
      console.warn(
        `🚦 Rate limit EXCEEDED for ${userId} (scan cap of ${RATE_LIMIT_SCAN_LIMIT} reached)`,
      );
      return true;
    }

    let successes = 0;
    let failures = 0;
    recentAttempts.forEach((doc) => {
      if (doc.get('action') === 'receipt_validated') successes++;
      else failures++;
    });

    const successExceeded = successes >= RATE_LIMIT_MAX_VALIDATIONS;
    const failureExceeded = failures >= RATE_LIMIT_MAX_FAILURES;

    console.log(
      `🚦 Rate limit for ${userId}: ${successes}/${RATE_LIMIT_MAX_VALIDATIONS} validations, ` +
      `${failures}/${RATE_LIMIT_MAX_FAILURES} failures in the last hour`,
    );

    if (successExceeded || failureExceeded) {
      console.warn(
        `🚦 Rate limit EXCEEDED for ${userId} ` +
        `(${successExceeded ? 'validation' : 'failure'} budget)`,
      );
      return true;
    }
    return false;
  } catch (error) {
    // See the fail-open note above.
    console.error(
      `🚦 Rate limit check FAILED for ${userId}; allowing the purchase through. ` +
      `If this is FAILED_PRECONDITION the subscriptionLogs (userId, timestamp, action) ` +
      `composite index is missing — see risk #15. Error: ` +
      (error instanceof Error ? error.message : String(error)),
    );
    return false;
  }
}

/**
 * Retry logic with exponential backoff (Phase 5: Error Handling)
 * Handles transient network errors gracefully
 */
async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000
): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error: any) {
      const isLastAttempt = attempt === maxRetries - 1;
      
      // Don't retry on certain errors (client errors that won't change)
      const nonRetryableErrors = [401, 403, 404, 400];
      if (error.code && nonRetryableErrors.includes(error.code)) {
        console.log(`❌ Non-retryable error (${error.code}), not retrying`);
        throw error;
      }
      
      // Don't retry on axios errors with these status codes
      if (error.response?.status && nonRetryableErrors.includes(error.response.status)) {
        console.log(`❌ Non-retryable HTTP status (${error.response.status}), not retrying`);
        throw error;
      }
      
      if (isLastAttempt) {
        console.error(`❌ All ${maxRetries} retry attempts failed`);
        throw error;
      }
      
      // Exponential backoff: 1s, 2s, 4s...
      const delay = baseDelay * Math.pow(2, attempt);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  
  throw new Error('Retry logic failed unexpectedly');
}

/**
 * Validate iOS receipt with Apple App Store
 * Phase 2: IMPLEMENTED ✅
 * 
 * This function validates iOS receipts with Apple's verifyReceipt API.
 * It automatically detects sandbox vs production environment and extracts
 * subscription data including expiration dates and transaction IDs.
 */
async function validateAppleReceipt(
  receiptData: string,
  productId: string
): Promise<{ valid: boolean; expiresAt?: Date; transactionId?: string; originalTransactionId?: string; actualProductId?: string; error?: string }> {
  console.log('🍎 Starting Apple receipt validation');
  console.log(`📦 Product ID: ${productId}`);
  console.log(`📄 Receipt length: ${receiptData.length} characters`);
  
  try {
    // Prepare request body for Apple API
    const requestBody = {
      'receipt-data': receiptData,
      'password': appleSharedSecret.value(),
      'exclude-old-transactions': true
    };
    
    console.log('📡 Prepared request body for Apple API');
    
    // PRODUCTION-FIRST APPROACH (Apple's recommended order)
    // Try production first, fall back to sandbox only if Apple returns 21007.
    // Reference: https://developer.apple.com/documentation/appstorereceipts/verifyreceipt
    console.log('🌐 Step 1: Validating against PRODUCTION endpoint...');
    let response;
    let isSandbox = false;

    try {
      response = await retryWithBackoff(() =>
        axios.post(APPLE_PRODUCTION_URL, requestBody, {
          headers: { 'Content-Type': 'application/json' },
          timeout: 10000
        })
      );
      console.log(`✅ Production API responded with status: ${response.data.status}`);

      // If status is 21007 (sandbox receipt in production), switch to sandbox.
      // This is the expected path for TestFlight builds and dev sandbox accounts.
      if (response.data.status === 21007) {
        console.log('🧪 Status 21007: This is a sandbox receipt, switching to sandbox API...');
        response = await axios.post(APPLE_SANDBOX_URL, requestBody, {
          headers: { 'Content-Type': 'application/json' },
          timeout: 10000
        });
        isSandbox = true;
        console.log(`✅ Sandbox API responded with status: ${response.data.status}`);
      }
    } catch (productionError: unknown) {
      // Production endpoint failed after retries. Do NOT silently fall back to
      // sandbox — that would risk tagging a real purchase as sandbox in logs.
      // Surface a clean error so the client can retry and the failure is visible.
      const errorMessage = productionError instanceof Error ? productionError.message : 'Unknown error';
      console.error('❌ Apple production endpoint unavailable after retries:', errorMessage);
      return {
        valid: false,
        error: 'Apple verification temporarily unavailable. Please try again.'
      };
    }
    
    console.log(`🌍 Using environment: ${isSandbox ? 'SANDBOX' : 'PRODUCTION'}`);
    
    // Check Apple's response status code
    const status = response.data.status;
    console.log(`📊 Apple response status: ${status} - ${APPLE_STATUS_CODES[status] || 'Unknown'}`);
    
    if (status !== 0) {
      // Non-zero status means validation failed
      const errorMessage = APPLE_STATUS_CODES[status] || `Unknown error (status ${status})`;
      console.error(`❌ Receipt validation failed: ${errorMessage}`);
      
      return {
        valid: false,
        error: errorMessage
      };
    }
    
    console.log('✅ Status 0: Receipt is valid!');
    
    // Extract latest receipt info (contains subscription data)
    const latestReceipts = response.data.latest_receipt_info || [];
    console.log(`📦 Found ${latestReceipts.length} transaction(s) in receipt`);
    
    if (latestReceipts.length === 0) {
      console.error('❌ No transactions found in latest_receipt_info');
      return {
        valid: false,
        error: 'No subscription data found in receipt'
      };
    }
    
    // Strict product matching — no fallback to other plans.
    // If Apple's receipt does not contain the exact requested product ID, we
    // return a clear error so the issue is visible and debuggable rather than
    // silently recording the wrong plan type.
    const matchingReceipt = latestReceipts.find((r: any) => r.product_id === productId);

    if (!matchingReceipt) {
      const available = latestReceipts.map((r: any) => r.product_id).join(', ');
      console.error(`❌ Product "${productId}" not found in receipt. Available: [${available}]`);
      return {
        valid: false,
        error: `Receipt does not contain "${productId}". Available products: [${available}]. Please contact support.`
      };
    }

    console.log(`✅ Found matching product: ${productId}`);
    
    // Extract expiration date (Apple returns milliseconds since epoch)
    const expiresAtMs = parseInt(matchingReceipt.expires_date_ms);
    const expiresAt = new Date(expiresAtMs);
    const now = new Date();
    
    console.log(`⏰ Current time: ${now.toISOString()}`);
    console.log(`⏰ Expires at: ${expiresAt.toISOString()}`);
    console.log(`⏰ Time until expiry: ${Math.round((expiresAt.getTime() - now.getTime()) / 1000 / 60)} minutes`);
    
    // Check if subscription is expired
    if (expiresAt < now) {
      const expiredMinutesAgo = Math.round((now.getTime() - expiresAt.getTime()) / 1000 / 60);
      console.error(`❌ Subscription expired ${expiredMinutesAgo} minutes ago`);
      return {
        valid: false,
        error: `Subscription expired on ${expiresAt.toISOString()}`
      };
    }
    
    console.log('✅ Subscription is active and not expired');
    
    // Extract transaction IDs.
    // Use transaction_id (unique per billing cycle) so each renewal is recorded
    // as a separate entry in the transactions[] array.
    // original_transaction_id never changes across renewals — using it would
    // cause the idempotency guard to block every renewal after the first purchase.
    // We separately capture original_transaction_id for webhook event matching.
    const transactionId = matchingReceipt.transaction_id || matchingReceipt.original_transaction_id;
    // Apple sandbox receipts sometimes omit original_transaction_id.
    // For first-time purchases transaction_id === original_transaction_id, so this fallback is safe.
    // For renewals, original_transaction_id is stable across renewals and takes priority.
    const originalTransactionId = (matchingReceipt.original_transaction_id || matchingReceipt.transaction_id) as string | undefined;
    console.log(`🔑 Transaction ID: ${transactionId}`);
    console.log(`🔑 Original Transaction ID: ${originalTransactionId ?? '(not present in receipt)'}`);
    console.log(`🔑 Original Transaction ID: ${originalTransactionId ?? '(not present in receipt)'}`);
    
    // Check for cancellation
    if (matchingReceipt.cancellation_date_ms) {
      const cancelledAt = new Date(parseInt(matchingReceipt.cancellation_date_ms));
      console.warn(`⚠️ Subscription was cancelled at: ${cancelledAt.toISOString()}`);
      return {
        valid: false,
        error: `Subscription was cancelled on ${cancelledAt.toISOString()}`
      };
    }
    
    // SUCCESS! Return valid subscription data
    console.log('🎉 Receipt validation successful!');
    console.log(`✅ Valid subscription until: ${expiresAt.toISOString()}`);

    return {
      valid: true,
      expiresAt: expiresAt,
      transactionId: transactionId,
      originalTransactionId: originalTransactionId,
      actualProductId: productId,
    };
    
  } catch (error) {
    // Network or other errors
    console.error('❌ Error during Apple receipt validation:', error);
    
    if (axios.isAxiosError(error)) {
      console.error('🌐 Network error details:', {
        message: error.message,
        code: error.code,
        status: error.response?.status,
        data: error.response?.data
      });
      
      return {
        valid: false,
        error: `Network error: ${error.message}`
      };
    }
    
    return {
      valid: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
}

/**
 * Validate Android receipt with Google Play Developer API
 * Phase 3: IMPLEMENTED ✅
 * 
 * This function validates Android receipts with Google Play Developer API v3.
 * It authenticates using service account, calls the API, and extracts
 * subscription data including expiration dates and transaction IDs.
 */
async function validateGooglePlayReceipt(
  purchaseToken: string,
  productId: string
): Promise<{ valid: boolean; expiresAt?: Date; transactionId?: string; error?: string }> {
  console.log('🤖 Starting Google Play receipt validation');
  console.log(`📦 Product ID: ${productId}`);
  console.log(`📄 Purchase token length: ${purchaseToken.length} characters`);
  
  try {
    // ========================================================================
    // STEP 1: Authenticate with Service Account (Phase 5: Secured)
    // ========================================================================
    
    console.log('🔐 Authenticating with Google Cloud service account...');
    
    const credentials = getGoogleCredentials();
    const auth = new google.auth.GoogleAuth({
      credentials: credentials,  // Use credentials object instead of keyFile
      scopes: ['https://www.googleapis.com/auth/androidpublisher']
    });
    
    const androidPublisher = google.androidpublisher({
      version: 'v3',
      auth: auth
    });
    
    console.log('✅ Authentication configured successfully');
    
    // ========================================================================
    // STEP 2: Call Google Play Developer API
    // ========================================================================
    
    console.log(`📡 Calling Google Play API for package: ${ANDROID_PACKAGE_NAME}`);
    console.log(`🎫 Using purchase token: ${purchaseToken.substring(0, 20)}...`);
    
    const response = await retryWithBackoff(() =>
      androidPublisher.purchases.subscriptionsv2.get({
        packageName: ANDROID_PACKAGE_NAME,
        token: purchaseToken
      })
    );
    
    console.log('✅ Google Play API responded successfully');
    
    // ========================================================================
    // STEP 3: Parse Response & Extract Subscription Data
    // ========================================================================
    
    const subscriptionData = response.data;
    
    // Check subscription state
    const subscriptionState = subscriptionData.subscriptionState;
    console.log(`📊 Subscription state: ${subscriptionState}`);
    
    if (subscriptionState !== GOOGLE_PLAY_STATES.ACTIVE) {
      // Subscription is not active
      let errorMessage = 'Subscription is not active';
      
      switch (subscriptionState) {
        case GOOGLE_PLAY_STATES.EXPIRED:
          errorMessage = 'Subscription has expired';
          break;
        case GOOGLE_PLAY_STATES.CANCELLED:
          errorMessage = 'Subscription was cancelled';
          break;
        case GOOGLE_PLAY_STATES.IN_GRACE_PERIOD:
          errorMessage = 'Subscription is in grace period (payment issue)';
          break;
        case GOOGLE_PLAY_STATES.ON_HOLD:
          errorMessage = 'Subscription is on hold';
          break;
        case GOOGLE_PLAY_STATES.PAUSED:
          errorMessage = 'Subscription is paused';
          break;
        case GOOGLE_PLAY_STATES.PENDING:
          errorMessage = 'Subscription is pending activation';
          break;
        default:
          errorMessage = `Unknown subscription state: ${subscriptionState}`;
      }
      
      console.error(`❌ ${errorMessage}`);
      return {
        valid: false,
        error: errorMessage
      };
    }
    
    console.log('✅ Subscription state is ACTIVE');
    
    // Extract line items (subscription details)
    const lineItems = subscriptionData.lineItems || [];
    console.log(`📦 Found ${lineItems.length} line item(s)`);
    
    if (lineItems.length === 0) {
      console.error('❌ No line items found in subscription data');
      return {
        valid: false,
        error: 'No subscription details found'
      };
    }
    
    // Get the first line item (subscriptions typically have one)
    const lineItem = lineItems[0];
    const lineItemProductId = lineItem.productId;
    
    console.log(`✅ Line item product ID: ${lineItemProductId}`);
    
    // Validate product ID matches
    if (lineItemProductId !== productId) {
      console.error(`❌ Product ID mismatch: expected "${productId}", got "${lineItemProductId}"`);
      return {
        valid: false,
        error: `Product ID mismatch: expected "${productId}", got "${lineItemProductId}"`
      };
    }
    
    console.log(`✅ Product ID matches: ${productId}`);
    
    // Extract expiration time
    const expiryTime = lineItem.expiryTime;
    if (!expiryTime) {
      console.error('❌ No expiry time found in line item');
      return {
        valid: false,
        error: 'No expiration date found in subscription'
      };
    }
    
    const expiresAt = new Date(expiryTime);
    const now = new Date();
    
    console.log(`⏰ Current time: ${now.toISOString()}`);
    console.log(`⏰ Expires at: ${expiresAt.toISOString()}`);
    console.log(`⏰ Time until expiry: ${Math.round((expiresAt.getTime() - now.getTime()) / 1000 / 60)} minutes`);
    
    // Check if subscription is expired (double-check even though state is ACTIVE)
    if (expiresAt < now) {
      const expiredMinutesAgo = Math.round((now.getTime() - expiresAt.getTime()) / 1000 / 60);
      console.error(`❌ Subscription expired ${expiredMinutesAgo} minutes ago`);
      return {
        valid: false,
        error: `Subscription expired on ${expiresAt.toISOString()}`
      };
    }
    
    console.log('✅ Subscription has not expired');
    
    // Extract transaction ID (order ID)
    const transactionId = subscriptionData.latestOrderId || subscriptionData.linkedPurchaseToken || purchaseToken;
    console.log(`🔑 Transaction ID: ${transactionId}`);
    
    // Check for test purchase (log for information)
    const testPurchase = subscriptionData.testPurchase;
    if (testPurchase) {
      console.log('🧪 This is a TEST PURCHASE (sandbox)');
    }
    
    // SUCCESS! Return valid subscription data
    console.log('🎉 Google Play receipt validation successful!');
    console.log(`✅ Valid subscription until: ${expiresAt.toISOString()}`);
    
    return {
      valid: true,
      expiresAt: expiresAt,
      transactionId: transactionId
    };
    
  } catch (error: any) {
    // Handle Google API errors
    console.error('❌ Error during Google Play receipt validation:', error);
    
    // Check for specific error codes
    if (error.code) {
      console.error(`🔴 Error code: ${error.code}`);
      
      switch (error.code) {
        case 401:
          return {
            valid: false,
            error: 'Authentication failed - Invalid service account credentials'
          };
        case 404:
          return {
            valid: false,
            error: 'Purchase not found - Invalid purchase token or subscription not found'
          };
        case 400:
          return {
            valid: false,
            error: 'Bad request - Invalid package name or purchase token format'
          };
        case 403:
          return {
            valid: false,
            error: 'Permission denied - Service account lacks required permissions'
          };
        default:
          return {
            valid: false,
            error: `Google API error (${error.code}): ${error.message || 'Unknown error'}`
          };
      }
    }
    
    // Generic error handling
    console.error('🌐 Error details:', {
      message: error.message,
      stack: error.stack
    });
    
    return {
      valid: false,
      error: error.message || 'Unknown error occurred during validation'
    };
  }
}

/**
 * Built-in catalogue defaults (risk #20).
 *
 * `subscriptionsType` was a single point of failure for every purchase: one
 * deleted, renamed or mistyped document and getSubscriptionMetadata threw
 * before any write, on every platform, silently. The risk is not theoretical —
 * PAYMENT_SYSTEM_IMPLEMENTATION.md documents planType as 'monthly_subscription',
 * and seeding it that way would match nothing.
 *
 * Values mirror the production catalogue (read 2026-09-16), including the
 * document ids, which are written through as packageId. Firestore still wins
 * when a row exists — this only prevents a missing row from costing a customer
 * a purchase they have already paid for.
 */
const SUBSCRIPTION_DEFAULTS: Record<string, { id: string; duration: number; price: number }> = {
  monthly: { id: '1', duration: 30, price: 9.99 },
  // Legacy only: yearly is no longer sold (owner decision 2026-09-16). Kept as
  // a safety net so a renewal receipt for a pre-existing yearly plan cannot
  // fail activation.
  yearly: { id: '2', duration: 360, price: 79.99 },
  trial: { id: '3', duration: 3, price: 0 },
};

/**
 * Get subscription metadata from the subscriptionsType collection, falling back
 * to built-in defaults for known products (risk #20).
 */
export async function getSubscriptionMetadata(productId: string): Promise<{
  id: string;
  duration: number;
  price: number;
}> {
  console.log(`📋 Fetching subscription metadata for: ${productId}`);

  const db = admin.firestore();
  const snapshot = await db.collection('subscriptionsType')
    .where('planType', '==', productId)
    .limit(1)
    .get();

  if (!snapshot.empty) {
    const doc = snapshot.docs[0];
    const data = doc.data();
    console.log(`✅ Found metadata: id=${doc.id}, duration=${data.duration}, price=${data.price}`);
    return { id: doc.id, duration: data.duration, price: data.price };
  }

  const fallback = SUBSCRIPTION_DEFAULTS[productId];
  if (fallback) {
    // Operational alarm, not a routine path: the catalogue is broken and should
    // be repaired. The customer has already been charged, so the purchase
    // completes on defaults rather than failing.
    console.error(
      `🚨 subscriptionsType has no row for "${productId}" — falling back to built-in ` +
      `defaults (duration=${fallback.duration}, price=${fallback.price}). ` +
      'Repair the catalogue: this should never be the source of truth. See risk #20.',
    );
    return { ...fallback };
  }

  console.error(`❌ Unknown product id with no catalogue row and no default: ${productId}`);
  throw new Error(
    `Subscription type not found and no built-in default exists: ${productId}. ` +
    `Known products: ${Object.keys(SUBSCRIPTION_DEFAULTS).join(', ')}.`,
  );
}

/**
 * Find the user's currently ACTIVE subscription.
 *
 * BUG RV-C1 FIX: The previous implementation queried by `orderBy('createdAt',
 * 'desc').limit(1)` — returning the most recently *created* subscription
 * regardless of its `isActive` state.  This broke the re-subscribe flow:
 *
 *   1. User has an old, inactive trial (isActive=false, planType='trial').
 *   2. User buys a monthly plan.
 *   3. Old query returns the inactive trial doc.
 *   4. 'trial' !== 'monthly' → Scenario C ("upgrade") runs, resurrecting the
 *      dead trial document with stale fields instead of creating a clean new
 *      subscription (Scenario A).
 *
 * Fix: query only `isActive==true`.  If no active subscription exists, return
 * null so Scenario A creates a fresh document.  A composite index on
 * (userId, isActive) is simpler and more reliable than (userId, createdAt).
 */
export async function findExistingSubscription(
  userId: string,
  receipt?: { platform: 'ios' | 'android'; originalTransactionId?: string; androidPurchaseToken?: string },
): Promise<{
  id: string;
  planType: string;
  packageId: string;
  [key: string]: any;
} | null> {
  const db = admin.firestore();

  // Risk #22 — reuse a document that already represents THIS store
  // subscription, even if it has been deactivated. Without this, a purchase
  // made after expiry created a second document for the same store
  // subscription, and the webhooks (which key on the receipt identity) could
  // then update the dead one while the live one drifted out of sync.
  //
  // This does not reopen BUG RV-C1. A dead trial carries no
  // originalTransactionId / androidPurchaseToken, so it never matches here and
  // still falls through to the isActive query below, which correctly returns
  // null so a clean document is created.
  if (receipt) {
    const field = receipt.platform === 'ios' ? 'originalTransactionId' : 'androidPurchaseToken';
    const value = receipt.platform === 'ios'
      ? receipt.originalTransactionId
      : receipt.androidPurchaseToken;

    if (value) {
      // Two equality filters: served by single-field indexes, no composite
      // index required (cf. risk #15).
      const byReceipt = await db.collection('subscriptions')
        .where(field, '==', value)
        .where('userId', '==', userId)
        .limit(1)
        .get();

      if (!byReceipt.empty) {
        const doc = byReceipt.docs[0];
        const data = doc.data();
        console.log(
          `✅ Reusing subscription ${doc.id} matched by ${field} ` +
          `(isActive=${data.isActive}) — avoids a duplicate document`,
        );
        return { id: doc.id, planType: data.planType, packageId: data.packageId, ...data };
      }
    }
  }

  console.log(`🔍 Searching for active subscription for user: ${userId}`);

  const snapshot = await db.collection('subscriptions')
    .where('userId', '==', userId)
    .where('isActive', '==', true)   // FIX: only consider live subscriptions
    .limit(1)
    .get();

  if (snapshot.empty) {
    console.log(`📭 No active subscription found for user: ${userId} → will create new`);
    return null;
  }

  const doc = snapshot.docs[0];
  const data = doc.data();

  console.log(`✅ Found active subscription: ${doc.id}, planType=${data.planType}`);

  return {
    id: doc.id,
    planType: data.planType,
    packageId: data.packageId,
    ...data,
  };
}

/**
 * Sync the user document after a successful purchase (all three scenarios).
 *
 * BUG RV-C2 FIX — two problems with the original version:
 *
 * Problem 1 — isActive never restored on re-subscribe:
 *   When the scheduler deactivates a subscription it sets users.isActive=false.
 *   When the user re-subscribes, createOrUpdateSubscription correctly marks
 *   subscriptions.isActive=true but this helper only updated billing dates —
 *   it never wrote isActive back to true.  The Flutter app gates premium
 *   features via users.isActive, so the user was permanently locked out even
 *   after successfully paying.
 *   Fix: always write isActive:true here (this function is ONLY called on a
 *   successful purchase, so setting true is always correct).
 *
 * Problem 2 — update() throws if user document doesn't exist:
 *   Firestore update() fails with NOT_FOUND if the document is absent (e.g.
 *   a user was deleted from Auth but their subscription record survived).
 *   We used to swallow that error silently, leaving isActive out of sync.
 *   Fix: use set({merge:true}) — creates the doc if missing, merges if present.
 */
async function syncUserBillingDate(
  db: admin.firestore.Firestore,
  userId: string,
  nextBillingDate: Date,
  now: Timestamp
): Promise<void> {
  try {
    await db.collection('users').doc(userId).set(
      {
        isActive: true,   // FIX: restore access after server-side deactivation
        nextBillingDate: Timestamp.fromDate(nextBillingDate),
        lastBillingDate: now,
        lastUpdated: FieldValue.serverTimestamp(),
      },
      { merge: true }     // FIX: safe whether the doc exists or not
    );
    console.log(`✅ Synced user document: isActive=true, nextBillingDate=${nextBillingDate.toISOString()}`);
  } catch (error) {
    // Log but don't rethrow — a sync failure here is corrected the next time
    // the Flutter app calls validateBillingSynchronization().
    console.warn('⚠️ Could not sync user document (non-fatal):', error);
  }
}

/**
 * Create or update subscription in Firestore
 * Phase 4: IMPLEMENTED ✅
 * 
 * This function handles:
 * - New subscription creation
 * - Subscription renewals
 * - Subscription upgrades (trial→paid, monthly→yearly)
 * - Transaction history tracking
 * - Platform tracking (iOS/Android)
 */
/**
 * Receipt→account binding (risk #5).
 *
 * Nothing used to check whether an incoming receipt was already bound to a
 * different account, so one paid receipt could entitle unlimited accounts:
 * share the receipt, every recipient gets a subscription document, and each
 * looks legitimate. Revocation could not clean it up either, because both
 * webhook lookups use `.limit(1)` and so reach exactly one of the N documents.
 *
 * The store identifiers are stable across renewals — `originalTransactionId`
 * on iOS, the purchase token on Android — which is exactly what makes them
 * usable as an ownership key.
 *
 * The query filters on a single field by equality, so it is served by a
 * single-field index and needs no composite index (cf. risk #15, where a
 * missing composite index silently breaks the purchase path).
 *
 * Deliberately NOT filtered on `isActive`: a receipt bound to someone's
 * lapsed subscription still belongs to them, and ignoring inactive rows would
 * reopen the hole the moment a subscription expired.
 */
export async function assertReceiptNotBoundToAnotherUser(params: {
  userId: string;
  platform: 'ios' | 'android';
  originalTransactionId?: string;
  androidPurchaseToken?: string;
}): Promise<void> {
  const { userId, platform } = params;
  const field = platform === 'ios' ? 'originalTransactionId' : 'androidPurchaseToken';
  const value = platform === 'ios' ? params.originalTransactionId : params.androidPurchaseToken;

  // Nothing to bind against. Apple omits original_transaction_id on some
  // receipt shapes; that is not grounds to reject a purchase.
  if (!value) {
    console.log(`🔗 Receipt binding: no ${field} present, skipping ownership check`);
    return;
  }

  const snap = await admin.firestore()
    .collection('subscriptions')
    .where(field, '==', value)
    .get();

  const foreign = snap.docs.filter((doc) => doc.get('userId') !== userId);

  if (foreign.length > 0) {
    const owners = Array.from(new Set(foreign.map((d) => d.get('userId'))));
    console.error(
      `🚫 Receipt binding violation: ${field}=${value} is already bound to ` +
      `${owners.length} other account(s) [${owners.join(', ')}]; ${userId} was refused.`,
    );
    throw new functions.https.HttpsError(
      'permission-denied',
      'This purchase is already associated with another account.',
    );
  }

  console.log(`🔗 Receipt binding OK: ${field}=${value} belongs to ${userId}`);
}

export async function createOrUpdateSubscription(
  userId: string,
  productId: string,
  expiresAt: Date,
  platform: 'ios' | 'android',
  transactionId: string,
  originalTransactionId?: string
): Promise<string> {
  console.log('💾 Starting createOrUpdateSubscription...');
  console.log(`   User: ${userId}, Product: ${productId}, Platform: ${platform}`);

  // Risk #5 — refuse a receipt already bound to another account BEFORE any
  // write, and outside the try below so the permission-denied is not reshaped
  // into a generic 'internal' error by the catch.
  // Android stores the purchase token in androidPurchaseToken, which is this
  // transactionId (see the writes further down).
  await assertReceiptNotBoundToAnotherUser({
    userId,
    platform,
    originalTransactionId,
    androidPurchaseToken: platform === 'android' ? transactionId : undefined,
  });

  try {
    const db = admin.firestore();
    const now = Timestamp.now();
    
    // Get subscription metadata from subscriptionsType collection
    const metadata = await getSubscriptionMetadata(productId);
    
    // Check if user has existing subscription. The receipt identity lets this
    // reuse a lapsed document for the same store subscription (risk #22).
    const existingSubscription = await findExistingSubscription(userId, {
      platform,
      originalTransactionId,
      androidPurchaseToken: platform === 'android' ? transactionId : undefined,
    });

    // ── IDEMPOTENCY GUARD ────────────────────────────────────────────────────
    // Apple/Google can deliver the same transaction receipt multiple times.
    // StoreKit re-queues every unfinished transaction on each app launch, and
    // our auto-renewal code now processes every such delivery — which is correct
    // for catching missed renewals but means the same transactionId can arrive
    // 10-14 times in a short window.
    //
    // Without this guard, each call would append a new entry to transactions[]
    // because arrayUnion compares by deep equality and `date: Timestamp.now()`
    // differs on every invocation — even when transactionId is identical.
    //
    // Fix: if this transactionId already exists in the subscription's
    // transactions array, do an idempotent billing-date update ONLY and return
    // early — no duplicate array entry is written.
    if (existingSubscription) {
      const existingTransactions: any[] = existingSubscription.transactions || [];
      const alreadyRecorded = existingTransactions.some(
        (t: any) => t.transactionId === transactionId
      );

      if (alreadyRecorded) {
        console.log(
          `⚠️ Transaction "${transactionId}" already recorded for user ${userId} — ` +
          `performing idempotent billing-date update only (no duplicate entry)`
        );
        // Still refresh billing metadata (safe to repeat — keeps Firestore in sync).
        await db.collection('subscriptions').doc(existingSubscription.id).update({
          nextBillingDate: Timestamp.fromDate(expiresAt),
          isActive: true,
          status: 'active',
          renewalAttempts: 0,
          updatedAt: now,
        });
        await syncUserBillingDate(db, userId, expiresAt, now);
        console.log(`✅ Idempotent update complete for subscription: ${existingSubscription.id}`);
        return existingSubscription.id;
      }
    }
    // ── END IDEMPOTENCY GUARD ────────────────────────────────────────────────

    // Create transaction record
    const transactionRecord = {
      transactionId: transactionId,
      platform: platform,
      date: now,
      productId: productId,
      amount: metadata.price
    };
    
    let subscriptionDocId: string;

    // Scenario A: New Subscription (First Time)
    if (!existingSubscription) {
      console.log('🆕 Creating NEW subscription...');
      
      const newSubscription = {
        userId: userId,
        planType: productId,
        packageId: metadata.id,
        isActive: true,
        status: 'active',
        platform: platform,  // Track which platform
        nextBillingDate: Timestamp.fromDate(expiresAt),
        duration: metadata.duration,
        price: metadata.price,
        trialUsed: productId === 'trial' ? 0 : 1,
        trialEndsAt: productId === 'trial' ? Timestamp.fromDate(expiresAt) : null,
        transactions: [transactionRecord],  // Transaction history array
        originalTransactionId: platform === 'ios' && originalTransactionId ? originalTransactionId : null,
        androidPurchaseToken: platform === 'android' ? transactionId : null,
        createdAt: now,
        updatedAt: now
      };
      
      const docRef = await db.collection('subscriptions').add(newSubscription);
      console.log(`✅ Created new subscription: ${docRef.id}`);
      subscriptionDocId = docRef.id;

    } else if (existingSubscription.planType === productId) {
      // Scenario B: Renewal (Same Plan)
      console.log(`🔄 RENEWING existing subscription: ${existingSubscription.id}`);
      
      // BUG RV-1 FIX: Reset renewalAttempts to 0.
      // When the scheduler marks a subscription 'past_due' it increments
      // renewalAttempts (max 3 before deactivation).  Apple/Google delivering
      // a real receipt here means payment succeeded, so the grace-period counter
      // MUST be cleared.  Without this reset, a subscription that had gone
      // past_due (renewalAttempts=2) would only need one more missed cycle to
      // be permanently deactivated — effectively halving its grace period.
      await db.collection('subscriptions').doc(existingSubscription.id).update({
        nextBillingDate: Timestamp.fromDate(expiresAt),
        isActive: true,
        status: 'active',
        renewalAttempts: 0,  // FIX: clear grace-period counter on successful renewal
        platform: platform,  // Update platform (user might switch devices)
        transactions: FieldValue.arrayUnion(transactionRecord),
        ...(platform === 'ios' && originalTransactionId && { originalTransactionId }),
        ...(platform === 'android' && { androidPurchaseToken: transactionId }),
        updatedAt: now
      });
      
      console.log(`✅ Renewed subscription: ${existingSubscription.id}`);
      subscriptionDocId = existingSubscription.id;

    } else {
      // Scenario C: Upgrade/Downgrade (Different Plan)
      console.log(`⬆️ UPGRADING subscription from ${existingSubscription.planType} to ${productId}`);
      
      // Add upgrade info to transaction record
      const upgradeTransaction = {
        ...transactionRecord,
        upgradeFrom: existingSubscription.planType  // Track upgrade path
      };
      
      // BUG RV-C3 FIX: Reset renewalAttempts to 0 on upgrade/downgrade.
      // Scenario B (renewal) already resets this counter.  Scenario C was
      // missed — if the existing subscription had been in the grace-period queue
      // (renewalAttempts=2), the upgraded plan would inherit that counter and
      // be permanently deactivated after just ONE more missed billing cycle
      // instead of the full 3-run grace period.
      await db.collection('subscriptions').doc(existingSubscription.id).update({
        planType: productId,  // Change plan
        packageId: metadata.id,
        duration: metadata.duration,
        price: metadata.price,
        nextBillingDate: Timestamp.fromDate(expiresAt),
        trialUsed: 1,  // Mark trial as used if upgrading from trial
        isActive: true,
        status: 'active',
        renewalAttempts: 0,  // FIX: don't carry over grace-period counter
        platform: platform,
        transactions: FieldValue.arrayUnion(upgradeTransaction),
        ...(platform === 'ios' && originalTransactionId && { originalTransactionId }),
        ...(platform === 'android' && { androidPurchaseToken: transactionId }),
        updatedAt: now
      });
      
      console.log(`✅ Upgraded subscription: ${existingSubscription.id}`);
      subscriptionDocId = existingSubscription.id;
    }

    // Sync user document — keeps user.nextBillingDate consistent with the
    // subscription document for any code that reads it directly from users/.
    await syncUserBillingDate(db, userId, expiresAt, now);

    return subscriptionDocId;
    
  } catch (error) {
    console.error('❌ Error in createOrUpdateSubscription:', error);
    throw error;
  }
}

// ============================================================================
// MAIN CALLABLE FUNCTION
// ============================================================================

/**
 * Firebase Callable Function to validate purchase receipts
 * 
 * This function:
 * 1. Validates user authentication
 * 2. Validates input parameters
 * 3. Routes to platform-specific validation (iOS/Android)
 * 4. Creates/updates subscription in Firestore
 * 5. Returns validation result to the app
 * 
 * @param data - Receipt validation request data
 * @param context - Firebase callable function context
 * @returns ValidationResult with success/failure status
 */
export const validatePurchaseReceipt = functions
  .runWith({ secrets: [appleSharedSecret, googleCredentials] })
  .https.onCall(
  async (data: ReceiptValidationRequest, context): Promise<ValidationResult> => {
    
    console.log('🔐 Receipt validation requested');
    console.log('Timestamp:', new Date().toISOString());
    
    // ========================================================================
    // STEP 1: Authentication Validation
    // ========================================================================
    
    if (!context.auth) {
      console.error('❌ Unauthenticated request');
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to validate receipts'
      );
    }

    const userId = context.auth.uid;
    console.log(`✅ Authenticated user: ${userId}`);

    // ========================================================================
    // PHASE 5: Rate Limiting Check
    // ========================================================================
    
    const rateLimitExceeded = await checkRateLimit(userId);
    if (rateLimitExceeded) {
      console.error(`❌ Rate limit exceeded for user: ${userId}`);
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Too many validation attempts. Please try again in an hour.'
      );
    }

    // ========================================================================
    // STEP 2: Input Validation
    // ========================================================================
    
    const { receipt, platform, productId } = data;
    
    // Check for required fields
    if (!receipt || !platform || !productId) {
      console.error('❌ Missing required fields');
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: receipt, platform, and productId are required'
      );
    }

    // Validate platform
    if (platform !== 'ios' && platform !== 'android') {
      console.error(`❌ Invalid platform: ${platform}`);
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Platform must be either "ios" or "android"'
      );
    }

    // Validate product ID
    const validProductIds = Object.values(PRODUCT_IDS);
    if (!validProductIds.includes(productId)) {
      console.error(`❌ Invalid product ID: ${productId}`);
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Invalid product ID. Must be one of: ${validProductIds.join(', ')}`
      );
    }

    console.log(`✅ Input validated - Platform: ${platform}, Product: ${productId}`);

    // ========================================================================
    // STEP 3: Platform-Specific Receipt Validation
    // ========================================================================
    
    try {
      console.log('🔍 Starting receipt validation process...');
      
      let validationResult: {
        valid: boolean;
        expiresAt?: Date;
        transactionId?: string;
        originalTransactionId?: string;  // iOS only — stable ID across renewals, used for webhook matching
        actualProductId?: string;  // BUG RV-MATCH FIX: real product from Apple receipt
        error?: string;
      };
      
      // Route to appropriate validation function based on platform
      if (platform === 'ios') {
        console.log('📱 Routing to iOS validation...');
        validationResult = await validateAppleReceipt(receipt, productId);
      } else {
        console.log('🤖 Routing to Android validation...');
        validationResult = await validateGooglePlayReceipt(receipt, productId);
      }

      // Check if validation failed
      if (!validationResult.valid) {
        console.error(`❌ Receipt validation failed for user: ${userId}`);
        console.error(`Error: ${validationResult.error}`);
        
        // Log failed validation
        await admin.firestore().collection('subscriptionLogs').add({
          userId: userId,
          action: 'receipt_validation_failed',
          platform: platform,
          productId: productId,
          error: validationResult.error,
          timestamp: FieldValue.serverTimestamp(),
          success: false
        });
        
        return {
          valid: false,
          message: validationResult.error || 'Receipt validation failed. Please contact support.',
          productId: productId,
          platform: platform
        };
      }

      console.log('✅ Receipt validation successful!');
      
      // ======================================================================
      // Phase 4: Firestore Integration - ACTIVE ✅
      // ======================================================================
      
      console.log('💾 Creating/updating subscription in Firestore...');

      // Create/update subscription in Firestore
      const subscriptionId = await createOrUpdateSubscription(
        userId,
        productId,
        validationResult.expiresAt!,
        platform,
        validationResult.transactionId!,
        platform === 'ios' ? validationResult.originalTransactionId : undefined
      );

      // Log successful validation with subscription creation
      await admin.firestore().collection('subscriptionLogs').add({
        userId: userId,
        action: 'receipt_validated',
        platform: platform,
        productId: productId,
        subscriptionId: subscriptionId,
        transactionId: validationResult.transactionId,
        expiresAt: Timestamp.fromDate(validationResult.expiresAt!),
        timestamp: FieldValue.serverTimestamp(),
        success: true
      });

      console.log(`✅ Receipt validated successfully for user: ${userId}`);
      console.log(`📦 Subscription ID: ${subscriptionId}`);

      // Return success response with subscription ID
      return {
        valid: true,
        message: 'Subscription activated successfully!',
        subscriptionId: subscriptionId,
        expiresAt: validationResult.expiresAt!.toISOString(),
        productId: productId,
        platform: platform,
        transactionId: validationResult.transactionId
      };

    } catch (error) {
      console.error('❌ Error in receipt validation:', error);
      
      // Log error for monitoring
      await admin.firestore().collection('subscriptionLogs').add({
        userId: userId,
        action: 'receipt_validation_error',
        platform: platform,
        productId: productId,
        error: error instanceof Error ? error.message : String(error),
        timestamp: FieldValue.serverTimestamp(),
        success: false
      });
      
      // Risk #20: this catch used to flatten EVERY error into 'internal',
      // including deliberate HttpsErrors raised inside the try — such as the
      // receipt→account binding refusal (risk #5). The client then could not
      // tell "this receipt belongs to someone else" from "the server broke",
      // and neither could support.
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Failed to validate receipt. Please try again or contact support.',
        { originalError: error instanceof Error ? error.message : String(error) }
      );
    }
  }
);

// ============================================================================
// EXPORTED FOR USE IN index.ts
// ============================================================================

