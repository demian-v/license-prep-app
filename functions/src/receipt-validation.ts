// Phase 2: iOS Receipt Validation - IMPLEMENTED ✅
// Phase 3: Android Receipt Validation - IMPLEMENTED ✅
// Phase 4: Firestore Integration - Pending
import * as functions from 'firebase-functions/v1';
import { defineSecret } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
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

// Product ID mapping (matches your App Store/Play Store product IDs)
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

const RATE_LIMIT_MAX_ATTEMPTS = 10;  // Max validations per hour
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;  // 1 hour in milliseconds

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
 * Check if user exceeded rate limit (Phase 5: Security)
 * Prevents abuse by limiting validation attempts
 */
async function checkRateLimit(userId: string): Promise<boolean> {
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;
  
  const db = admin.firestore();
  const recentAttempts = await db.collection('subscriptionLogs')
    .where('userId', '==', userId)
    .where('timestamp', '>', admin.firestore.Timestamp.fromMillis(windowStart))
    .where('action', 'in', ['receipt_validated', 'receipt_validation_failed', 'receipt_validation_error'])
    .get();
  
  const attemptCount = recentAttempts.size;
  
  console.log(`🚦 Rate limit check for ${userId}: ${attemptCount}/${RATE_LIMIT_MAX_ATTEMPTS} attempts in last hour`);
  
  return attemptCount >= RATE_LIMIT_MAX_ATTEMPTS;
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
      console.log(`⏳ Retry attempt ${attempt + 1}/${maxRetries}, waiting ${delay}ms...`);
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
): Promise<{ valid: boolean; expiresAt?: Date; transactionId?: string; actualProductId?: string; error?: string }> {
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
    
    // SANDBOX-FIRST APPROACH (as requested by user for testing)
    // Try sandbox first, then fall back to production if needed
    console.log('🧪 Step 1: Trying SANDBOX environment first (testing mode)...');
    let response;
    let isSandbox = true;
    
    try {
      response = await retryWithBackoff(() =>
        axios.post(APPLE_SANDBOX_URL, requestBody, {
          headers: { 'Content-Type': 'application/json' },
          timeout: 10000 // 10 second timeout
        })
      );
      console.log(`✅ Sandbox API responded with status: ${response.data.status}`);
      
      // If status is 21008 (production receipt in sandbox), switch to production
      if (response.data.status === 21008) {
        console.log('🔄 Status 21008: This is a production receipt, switching to production API...');
        response = await axios.post(APPLE_PRODUCTION_URL, requestBody, {
          headers: { 'Content-Type': 'application/json' },
          timeout: 10000
        });
        isSandbox = false;
        console.log(`✅ Production API responded with status: ${response.data.status}`);
      }
    } catch (sandboxError: unknown) {
      const errorMessage = sandboxError instanceof Error ? sandboxError.message : 'Unknown error';
      console.warn('⚠️ Sandbox API failed, trying production:', errorMessage);
      // If sandbox fails entirely, try production
      response = await axios.post(APPLE_PRODUCTION_URL, requestBody, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 10000
      });
      isSandbox = false;
      console.log(`✅ Production API responded with status: ${response.data.status}`);
    }
    
    console.log(`🌍 Using environment: ${isSandbox ? 'SANDBOX' : 'PRODUCTION'}`);
    
    // Check Apple's response status code
    const status = response.data.status;
    console.log(`📊 Apple response status: ${status} - ${APPLE_STATUS_CODES[status] || 'Unknown'}`);
    
    if (status !== 0) {
      // Non-zero status means validation failed
      const errorMessage = APPLE_STATUS_CODES[status] || `Unknown error (status ${status})`;
      console.error(`❌ Receipt validation failed: ${errorMessage}`);
      console.error(`📋 Full Apple response:`, JSON.stringify(response.data, null, 2));
      
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
    console.log(`📄 Transaction details:`, JSON.stringify(matchingReceipt, null, 2));
    
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
    
    // Extract transaction ID.
    // Use transaction_id (unique per billing cycle) so each renewal is recorded
    // as a separate entry in the transactions[] array.
    // original_transaction_id never changes across renewals — using it would
    // cause the idempotency guard to block every renewal after the first purchase.
    const transactionId = matchingReceipt.transaction_id || matchingReceipt.original_transaction_id;
    console.log(`🔑 Transaction ID: ${transactionId}`);
    
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
    console.log(`📋 Response data:`, JSON.stringify(response.data, null, 2));
    
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
 * Get subscription metadata from subscriptionsType collection
 * Phase 4: Helper function
 */
async function getSubscriptionMetadata(productId: string): Promise<{
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
  
  if (snapshot.empty) {
    console.error(`❌ Subscription type not found: ${productId}`);
    throw new Error(`Subscription type not found: ${productId}`);
  }
  
  const doc = snapshot.docs[0];
  const data = doc.data();
  
  console.log(`✅ Found metadata: id=${doc.id}, duration=${data.duration}, price=${data.price}`);
  
  return {
    id: doc.id,
    duration: data.duration,
    price: data.price
  };
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
async function findExistingSubscription(userId: string): Promise<{
  id: string;
  planType: string;
  packageId: string;
  [key: string]: any;
} | null> {
  console.log(`🔍 Searching for active subscription for user: ${userId}`);

  const db = admin.firestore();
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
  now: admin.firestore.Timestamp
): Promise<void> {
  try {
    await db.collection('users').doc(userId).set(
      {
        isActive: true,   // FIX: restore access after server-side deactivation
        nextBillingDate: admin.firestore.Timestamp.fromDate(nextBillingDate),
        lastBillingDate: now,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
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
async function createOrUpdateSubscription(
  userId: string,
  productId: string,
  expiresAt: Date,
  platform: 'ios' | 'android',
  transactionId: string
): Promise<string> {
  console.log('💾 Starting createOrUpdateSubscription...');
  console.log(`   User: ${userId}, Product: ${productId}, Platform: ${platform}`);
  
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    // Get subscription metadata from subscriptionsType collection
    const metadata = await getSubscriptionMetadata(productId);
    
    // Check if user has existing subscription
    const existingSubscription = await findExistingSubscription(userId);

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
          nextBillingDate: admin.firestore.Timestamp.fromDate(expiresAt),
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
        nextBillingDate: admin.firestore.Timestamp.fromDate(expiresAt),
        duration: metadata.duration,
        price: metadata.price,
        trialUsed: productId === 'trial' ? 0 : 1,
        trialEndsAt: productId === 'trial' ? admin.firestore.Timestamp.fromDate(expiresAt) : null,
        transactions: [transactionRecord],  // Transaction history array
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
        nextBillingDate: admin.firestore.Timestamp.fromDate(expiresAt),
        isActive: true,
        status: 'active',
        renewalAttempts: 0,  // FIX: clear grace-period counter on successful renewal
        platform: platform,  // Update platform (user might switch devices)
        transactions: admin.firestore.FieldValue.arrayUnion(transactionRecord),
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
        nextBillingDate: admin.firestore.Timestamp.fromDate(expiresAt),
        trialUsed: 1,  // Mark trial as used if upgrading from trial
        isActive: true,
        status: 'active',
        renewalAttempts: 0,  // FIX: don't carry over grace-period counter
        platform: platform,
        transactions: admin.firestore.FieldValue.arrayUnion(upgradeTransaction),
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
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
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
        validationResult.transactionId!
      );

      // Log successful validation with subscription creation
      await admin.firestore().collection('subscriptionLogs').add({
        userId: userId,
        action: 'receipt_validated',
        platform: platform,
        productId: productId,
        subscriptionId: subscriptionId,
        transactionId: validationResult.transactionId,
        expiresAt: admin.firestore.Timestamp.fromDate(validationResult.expiresAt!),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
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
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        success: false
      });
      
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

console.log('✅ Receipt validation module loaded');
console.log('📦 Function: validatePurchaseReceipt');
console.log('✅ Status: Phases 1-4 COMPLETE!');
console.log('   ✅ Phase 1: File structure');
console.log('   ✅ Phase 2: iOS receipt validation');
console.log('   ✅ Phase 3: Android receipt validation');
console.log('   ✅ Phase 4: Firestore integration (with transaction history, upgrades, renewals)');
console.log('⏳ Next: Phase 5 (Security & Error Handling), Phase 6 (Deploy & Test)');
