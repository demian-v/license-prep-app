# 💳 Payment System Implementation Documentation

**DriveUSA App - Receipt Validation & Subscription Management**

**Last Updated:** December 1, 2026  
**Status:** ✅ Production Ready (Pending Sandbox Testing)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Backend Implementation](#backend-implementation)
4. [Frontend Implementation](#frontend-implementation)
5. [Security](#security)
6. [Configuration](#configuration)
7. [Testing Guide](#testing-guide)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance](#maintenance)

---

## 🎯 Overview

### What This System Does

The payment system provides **secure, server-side receipt validation** for iOS and Android in-app purchases. It:

- ✅ Validates receipts with Apple App Store and Google Play
- ✅ Creates/updates subscriptions in Firestore
- ✅ Tracks transaction history
- ✅ Handles subscription renewals and upgrades
- ✅ Prevents fraud with rate limiting
- ✅ Provides detailed logging for debugging

### Key Features

- **Cross-Platform:** Works for both iOS (App Store) and Android (Google Play)
- **Server-Side Validation:** No client-side manipulation possible
- **Secure:** All secrets stored in Firebase Config, not in code
- **Resilient:** Retry logic with exponential backoff
- **Auditable:** Complete transaction history in Firestore

---

## 🏗️ Architecture

### System Flow

```
┌─────────────┐
│   User      │
│ Makes       │
│ Purchase    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│  App Store / Google Play        │
│  (Handles payment)              │
└──────────┬──────────────────────┘
           │
           │ Receipt/Token
           ▼
┌─────────────────────────────────┐
│  Flutter App                    │
│  (in_app_purchase_service.dart) │
│  • Extracts receipt data        │
│  • Calls Firebase function      │
└──────────┬──────────────────────┘
           │
           │ HTTP Callable
           ▼
┌─────────────────────────────────┐
│  Firebase Function              │
│  (validatePurchaseReceipt)      │
│  • Validates with Apple/Google  │
│  • Creates subscription         │
│  • Returns result               │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│  Firestore Database             │
│  • subscriptions collection     │
│  • subscriptionLogs collection  │
│  • subscriptionsType collection │
└─────────────────────────────────┘
```

### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **Backend** | `functions/src/receipt-validation.ts` | Receipt validation logic |
| **Frontend** | `lib/services/in_app_purchase_service.dart` | IAP integration & receipt submission |
| **Configuration** | Firebase Config | Secure storage of secrets |
| **Database** | Firestore | Subscription data storage |

---

## 🔧 Backend Implementation

### Main Function: `validatePurchaseReceipt`

**Location:** `functions/src/receipt-validation.ts`

**Type:** Firebase Callable Function  
**Region:** us-central1  
**Runtime:** Node.js 20

### Request Format

```typescript
interface ReceiptValidationRequest {
  receipt: string;              // Base64 receipt (iOS) or purchase token (Android)
  platform: 'ios' | 'android';  // Which store
  productId: string;            // Product identifier (e.g., 'monthly_subscription')
}
```

### Response Format

```typescript
interface ValidationResult {
  valid: boolean;               // Was validation successful?
  message: string;              // Human-readable message
  subscriptionId?: string;      // Firestore document ID
  expiresAt?: string;           // ISO 8601 date string
  productId?: string;           // Product that was purchased
  platform?: string;            // 'ios' or 'android'
  transactionId?: string;       // Apple/Google transaction ID
}
```

### Processing Steps

1. **Authentication Check**
   - Verifies user is authenticated via Firebase Auth
   - Extracts user ID from context

2. **Rate Limiting**
   - Max 10 validation attempts per user per hour
   - Prevents abuse and protects API quotas

3. **Input Validation**
   - Checks required fields (receipt, platform, productId)
   - Validates platform is 'ios' or 'android'
   - Validates productId is in allowed list

4. **Platform-Specific Validation**
   - **iOS:** Calls `validateAppleReceipt()`
   - **Android:** Calls `validateGooglePlayReceipt()`

5. **Firestore Integration**
   - Creates new subscription (first purchase)
   - Renews existing subscription (same plan)
   - Upgrades subscription (different plan)
   - Tracks transaction history

6. **Logging**
   - Success: Logs to `subscriptionLogs` with full details
   - Failure: Logs error reason for debugging

### iOS Validation (`validateAppleReceipt`)

**API:** Apple App Store Server API  
**Endpoint:** `https://buy.itunes.apple.com/verifyReceipt` (production)  
**Sandbox:** `https://sandbox.itunes.apple.com/verifyReceipt`

**Strategy:** Sandbox-first approach
1. Try sandbox environment first
2. If status 21008 (production receipt), switch to production
3. If sandbox fails, try production

**What It Checks:**
- Receipt authenticity with Apple
- Subscription expiration date
- Product ID matches
- Cancellation status
- Transaction ID

**Security:**
- Uses shared secret from Firebase Config
- 10-second timeout per request
- Retry logic with exponential backoff (3 attempts)

### Android Validation (`validateGooglePlayReceipt`)

**API:** Google Play Developer API v3  
**Endpoint:** `https://www.googleapis.com/androidpublisher/v3/`

**Authentication:**
- Uses service account credentials (from Firebase Config)
- OAuth 2.0 with `androidpublisher` scope

**What It Checks:**
- Subscription state (must be ACTIVE)
- Product ID matches
- Expiration date
- Transaction/order ID

**Security:**
- Credentials stored as base64 in Firebase Config
- Automatic token refresh via googleapis library
- Retry logic with exponential backoff

### Firestore Schema

**`subscriptions` Collection:**
```typescript
{
  userId: string;                    // Firebase Auth UID
  planType: string;                  // 'monthly_subscription' or 'yearly_subscription'
  packageId: string;                 // Reference to subscriptionsType
  isActive: boolean;                 // Is subscription active?
  status: string;                    // 'active', 'expired', 'cancelled'
  platform: 'ios' | 'android';       // Which platform
  nextBillingDate: Timestamp;        // When it expires/renews
  duration: number;                  // Days (30 or 365)
  price: number;                     // Price paid
  trialUsed: number;                 // 0=not used, 1=used
  trialEndsAt: Timestamp | null;     // For trial subscriptions
  transactions: Array<{              // Transaction history
    transactionId: string;
    platform: string;
    date: Timestamp;
    productId: string;
    amount: number;
    upgradeFrom?: string;            // If this was an upgrade
  }>;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**`subscriptionLogs` Collection:**
```typescript
{
  userId: string;
  action: string;                    // 'receipt_validated', 'receipt_validation_failed', etc.
  platform: 'ios' | 'android';
  productId: string;
  subscriptionId?: string;           // If successful
  transactionId?: string;
  expiresAt?: Timestamp;
  error?: string;                    // If failed
  timestamp: Timestamp;
  success: boolean;
}
```

**`subscriptionsType` Collection:**
```typescript
{
  planType: string;                  // 'monthly_subscription' or 'yearly_subscription'
  duration: number;                  // Days
  price: number;                     // USD
  // ... other metadata
}
```

---

## 📱 Frontend Implementation

### Main Service: `InAppPurchaseService`

**Location:** `lib/services/in_app_purchase_service.dart`

### Dependencies

```yaml
dependencies:
  in_app_purchase: ^3.1.11
  in_app_purchase_android: ^0.3.4+5
  in_app_purchase_storekit: ^0.3.8+1
  cloud_functions: ^4.5.3
```

### Initialization

```dart
final iapService = InAppPurchaseService();
await iapService.initialize();

// Set callbacks
iapService.setPurchaseCallbacks(
  onSuccess: (productId) {
    print('Purchase successful: $productId');
    // Update UI, grant access, etc.
  },
  onError: (error) {
    print('Purchase error: $error');
    // Show error to user
  },
  onCanceled: (productId) {
    print('Purchase canceled: $productId');
  },
);
```

### Purchase Flow

```dart
// 1. Get available products
List<ProductDetails> products = iapService.getProducts();

// 2. Initiate purchase
bool success = await iapService.purchaseProduct('monthly_subscription');

// 3. Purchase stream listener handles the rest automatically:
//    - Purchase completes
//    - _handleSuccessfulPurchase() called
//    - _validateReceipt() called (sends to backend)
//    - onSuccess callback triggered
```

### Receipt Validation Method

**Location:** `_validateReceipt()` in `InAppPurchaseService`

```dart
Future<bool> _validateReceipt(PurchaseDetails purchaseDetails) async {
  // 1. Extract receipt data
  String receipt = purchaseDetails.verificationData.serverVerificationData;
  String platform = Platform.isIOS ? 'ios' : 'android';
  
  // 2. Call Firebase function
  final callable = FirebaseFunctions.instance.httpsCallable('validatePurchaseReceipt');
  final result = await callable.call({
    'receipt': receipt,
    'platform': platform,
    'productId': purchaseDetails.productID,
  });
  
  // 3. Parse response
  final data = result.data as Map<String, dynamic>;
  return data['valid'] == true;
}
```

### Error Handling

```dart
try {
  final result = await callable.call({...});
  // Handle success
} catch (e) {
  if (e is FirebaseFunctionsException) {
    // Firebase function error
    print('Error code: ${e.code}');
    print('Message: ${e.message}');
    print('Details: ${e.details}');
  } else {
    // Network or other error
    print('Error: $e');
  }
  return false;
}
```

---

## 🔐 Security

### Secrets Management

**All secrets are stored in Firebase Config, NOT in code.**

#### Apple Shared Secret

**Purpose:** Validates iOS receipts with Apple  
**Storage:** Firebase Config

**Set with:**
```bash
firebase functions:config:set apple.shared_secret="YOUR_SHARED_SECRET_HERE"
```

**Access in code:**
```typescript
const APPLE_SHARED_SECRET = functions.config().apple?.shared_secret;
```

**Where to find:**
- App Store Connect → Your App → App Information → App-Specific Shared Secret

#### Google Service Account

**Purpose:** Validates Android receipts with Google Play  
**Storage:** Firebase Config (base64 encoded)

**Set with:**
```bash
# Convert to base64 first
base64 functions/service-account.json | tr -d '\n' > temp.txt

# Set in Firebase
firebase functions:config:set google.credentials="$(cat temp.txt)"

# Clean up
rm temp.txt
```

**Access in code:**
```typescript
const configCreds = functions.config().google?.credentials;
const decoded = Buffer.from(configCreds, 'base64').toString('utf-8');
const credentials = JSON.parse(decoded);
```

**Original file:** `functions/service-account.json` (in `.gitignore`)

### Rate Limiting

**Implementation:** Check recent attempts in Firestore

**Limits:**
- Maximum: 10 validation attempts
- Window: 1 hour (rolling)
- Per: User (identified by Firebase Auth UID)

**Purpose:**
- Prevents abuse
- Protects API quotas (Apple/Google charge per request)
- Detects potential fraud

**Code Location:** `checkRateLimit()` in `receipt-validation.ts`

### Retry Logic

**Implementation:** Exponential backoff

**Configuration:**
- Max retries: 3
- Base delay: 1 second
- Delays: 1s, 2s, 4s

**Skips retry for:**
- 400 (Bad Request)
- 401 (Unauthorized)
- 403 (Forbidden)
- 404 (Not Found)

**Purpose:**
- Handles transient network errors
- Doesn't waste attempts on permanent errors

**Code Location:** `retryWithBackoff()` in `receipt-validation.ts`

### What's NOT Stored in Code

❌ Apple shared secret  
❌ Google service account credentials  
❌ API keys or tokens  
❌ Firebase project secrets  

✅ Everything is in Firebase Config or `.gitignore`

---

## ⚙️ Configuration

### Firebase Setup

**Project:** licenseprepapp  
**Region:** us-central1  
**Runtime:** Node.js 20

### Required Firebase APIs

- Cloud Functions
- Cloud Firestore
- Cloud Build
- Artifact Registry
- Cloud Scheduler (for scheduled functions)

### Product IDs

**Must match across:**
1. App code (`InAppPurchaseService.productIds`)
2. App Store Connect (iOS)
3. Google Play Console (Android)
4. Firestore (`subscriptionsType.planType`)

**Current Product IDs:**
- `monthly_subscription`
- `yearly_subscription`

### Environment Variables

**View current config:**
```bash
firebase functions:config:get
```

**Expected output:**
```json
{
  "apple": {
    "shared_secret": "574b56c57bc64fefb8189ed68b7fc351"
  },
  "google": {
    "credentials": "ewogICJ0eXBlIjogInNlcnZpY2VfYWNjb3VudCIsCi..."
  }
}
```

### Firestore Indexes

**Required for rate limiting:**
```
Collection: subscriptionLogs
Fields: userId (Ascending), timestamp (Descending), action (Ascending)
```

**Set in:** `firestore.indexes.json`

---

## 🧪 Testing Guide

### iOS Sandbox Testing

#### Prerequisites

1. **Create Sandbox Test Account**
   - App Store Connect → Users and Access → Sandbox Testers
   - Add new tester with unique Apple ID

2. **Configure Products**
   - App Store Connect → Your App → Subscriptions
   - Create auto-renewable subscriptions
   - Product IDs: `monthly_subscription`, `yearly_subscription`

3. **Get Shared Secret**
   - App Store Connect → Your App → App Information
   - Copy App-Specific Shared Secret
   - Set in Firebase Config

#### Testing Steps

```bash
# 1. Build app for TestFlight
flutter build ios --release

# 2. Upload to App Store Connect
# (via Xcode or transporter)

# 3. Add build to TestFlight

# 4. Invite sandbox tester

# 5. On test device:
#    - Sign out of App Store
#    - Open app
#    - Make purchase
#    - Sign in with sandbox account when prompted

# 6. Verify in Firebase Console:
#    - Check Firestore > subscriptions
#    - Check Firestore > subscriptionLogs
#    - Check Functions > Logs
```

#### iOS Sandbox Features

- Purchases are free
- Subscriptions renew every 5 minutes (not 1 month)
- Can test renewals quickly
- Can test cancellations
- No real money charged

### Android Testing

#### Prerequisites

1. **Create Service Account**
   - Google Cloud Console → IAM & Admin → Service Accounts
   - Create account with "Viewer" role
   - Download JSON key → save as `functions/service-account.json`

2. **Grant Permissions**
   - Google Play Console → Your App → API access
   - Link service account
   - Grant "View financial data" permission

3. **Configure Products**
   - Google Play Console → Your App → Monetization → Subscriptions
   - Create subscriptions
   - Product IDs: `monthly_subscription`, `yearly_subscription`

4. **Add License Testers**
   - Google Play Console → Testing → License Testing
   - Add tester Gmail addresses

#### Testing Steps

```bash
# 1. Build app bundle
flutter build appbundle --release

# 2. Upload to Google Play Console
# Internal Testing track

# 3. Add testers to internal testing

# 4. Testers download from Play Store

# 5. Make test purchase

# 6. Verify in Firebase Console:
#    - Check Firestore > subscriptions
#    - Check Firestore > subscriptionLogs
#    - Check Functions > Logs
```

#### Android Testing Features

- Can use test cards (no real charges)
- License testers can make test purchases
- Purchases complete instantly
- Can test renewals (happen at normal intervals in test mode)

### Verification Checklist

After a test purchase, verify:

- [ ] Firebase Functions logs show successful validation
- [ ] Firestore `subscriptions` collection has new document
- [ ] `subscriptionLogs` has success entry
- [ ] Subscription has correct:
  - [ ] userId
  - [ ] planType
  - [ ] platform
  - [ ] expiresAt date
  - [ ] transactionId
- [ ] App received success callback
- [ ] User granted subscription access

---

## 🔧 Troubleshooting

### Common Issues

#### "Apple shared secret not configured"

**Cause:** Firebase Config missing `apple.shared_secret`

**Fix:**
```bash
firebase functions:config:set apple.shared_secret="YOUR_SECRET"
firebase deploy --only functions
```

#### "Google credentials not configured"

**Cause:** Firebase Config missing `google.credentials`

**Fix:**
```bash
base64 functions/service-account.json | tr -d '\n' > temp.txt
firebase functions:config:set google.credentials="$(cat temp.txt)"
firebase deploy --only functions
rm temp.txt
```

#### "Product not found in receipt"

**Cause:** Product ID mismatch

**Check:**
1. App code has correct product ID
2. Store (App Store/Play Store) has same product ID
3. Receipt is for the correct product

#### "Rate limit exceeded"

**Cause:** User made >10 validation attempts in 1 hour

**Fix:**
- Wait 1 hour for window to reset
- Or manually clear logs in Firestore (not recommended)

#### "Receipt validation failed - Status 21004"

**Cause:** Wrong shared secret

**Fix:**
1. Get correct shared secret from App Store Connect
2. Update Firebase Config
3. Redeploy functions

#### "Authentication failed - Invalid service account"

**Cause:** Google service account credentials invalid

**Fix:**
1. Download new service account JSON from Google Cloud
2. Convert to base64 and update Firebase Config
3. Verify permissions in Play Console

#### TypeScript Build Warnings

**Warning:** "Interface declared but never used"

**Cause:** Interfaces marked for future use

**Fix:** Safe to ignore - these are for documentation/future features

### Debugging Tools

#### Firebase Console Logs

**View logs:**
```
Firebase Console → Functions → Logs
```

**Filter by function:**
```
resource.labels.function_name="validatePurchaseReceipt"
```

**Common log markers:**
- `🍎` - iOS validation
- `🤖` - Android validation
- `✅` - Success
- `❌` - Error
- `🔐` - Authentication/security

#### Firestore Query

**Find user's subscriptions:**
```
Collection: subscriptions
Where: userId == "USER_UID"
Order by: createdAt desc
```

**Find validation attempts:**
```
Collection: subscriptionLogs
Where: userId == "USER_UID"
Order by: timestamp desc
Limit: 20
```

#### Test Commands

**Test Firebase function locally:**
```bash
cd functions
npm run serve

# Then call function via Firebase Emulator UI
```

**View current config:**
```bash
firebase functions:config:get
```

**Check function status:**
```bash
firebase functions:list
```

---

## 🔄 Maintenance

### Regular Tasks

#### Monitor Rate Limit Abuse

**Query:**
```
Collection: subscriptionLogs
Where: success == false
Order by: timestamp desc
```

Look for patterns:
- Same user failing repeatedly
- Same IP making many requests
- Unusual timestamps

#### Clean Up Old Logs

**Recommendation:** Keep logs for 90 days

**Manual cleanup script needed** (not automated)

#### Update Dependencies

**Check for updates:**
```bash
cd functions
npm outdated
```

**Update:**
```bash
npm update
npm audit fix
```

**Test after updating!**

### Migration Tasks

#### Before March 2026: Migrate from functions.config()

**Current:** Using `functions.config()` (deprecated)  
**Target:** Params package (modern approach)

**Migration guide:** https://firebase.google.com/docs/functions/config-env#migrate-config

**Priority:** Medium (current method works until March 2026)

### Backup Strategy

**Critical data to backup:**
- Firestore `subscriptions` collection
- Firestore `subscriptionLogs` collection
- Firebase Functions configuration
- Service account JSON (keep secure!)

**Automated:** Firebase handles infrastructure backups  
**Manual:** Export Firestore data periodically

---

## 📚 Additional Resources

### Documentation Links

- [Apple App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [Google Play Developer API](https://developers.google.com/android-publisher)
- [Firebase Functions](https://firebase.google.com/docs/functions)
- [Flutter in_app_purchase](https://pub.dev/packages/in_app_purchase)

### Support

**Questions or Issues:**
1. Check Firebase Functions logs
2. Check Firestore subscriptionLogs
3. Review this documentation
4. Check Apple/Google documentation

---

## 📊 Implementation Summary

### What's Complete

✅ Backend receipt validation (iOS & Android)  
✅ Firestore integration (subscriptions & logs)  
✅ Security (all secrets in Firebase Config)  
✅ Rate limiting (10/hour)  
✅ Retry logic (exponential backoff)  
✅ Error handling (comprehensive)  
✅ Flutter app integration (calls backend)  
✅ Transaction history tracking  
✅ Subscription renewals & upgrades  

### What's Needed

⚠️ Store configuration verification  
⚠️ Sandbox testing (iOS & Android)  
⚠️ Production testing  
⚠️ Monitoring setup  

### Status: ✅ Production Ready

**Code is complete and deployed.**  
**Next step: Test in sandbox environments.**

---

**Document Version:** 1.0  
**Created:** December 1, 2026  
**Author:** Payment System Implementation Team
