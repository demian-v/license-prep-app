# Webhook Integration: Apple App Store + Google Play Real-Time Subscription Updates

## Context

Currently recurring payment sync only happens on user login — no real-time updates when
Apple/Google silently process renewals, cancellations, or expirations. This plan implements:
- **Apple App Store Server Notifications** (direct HTTPS webhook) — Phase 1
- **Google Play Real-Time Developer Notifications** (via Google Cloud Pub/Sub) — Phase 2

Both require storing a platform-specific transaction identifier at purchase time so webhook
events can be matched to Firestore subscription documents.

---

## Architecture

```
Apple: Apple servers → HTTPS POST → appStoreWebhook (onRequest) → Firestore
Android: Google Play → Pub/Sub topic → handleGooglePlayNotifications (pubsub.onPublish) → Firestore
```

`originalTransactionId` (iOS) and `androidPurchaseToken` (Android) are stored server-side
inside `validatePurchaseReceipt` when the subscription is first created — no Flutter changes
required, no race conditions.

---

## Files to Modify

| File | Change |
|------|--------|
| `functions/package.json` | Add `@apple/app-store-server-library` |
| `functions/certs/AppleRootCA-G3.cer` | New — bundled Apple root certificate (public, safe to commit) |
| `functions/src/receipt-validation.ts` | Store `originalTransactionId` / `androidPurchaseToken` in all Firestore write paths |
| `functions/src/index.ts` | Add `appStoreWebhook`, `handleGooglePlayNotifications` |
| `firestore.rules` | Add `processedWebhooks` rule |
| `firestore.indexes.json` | Add index on `originalTransactionId` |
| `lib/models/user_subscription.dart` | Add optional read-only fields (display only) |

---

## Step-by-Step Implementation

### Step 1 — Add `@apple/app-store-server-library`

In `functions/package.json`, add to `dependencies`:
```json
"@apple/app-store-server-library": "^3.0.0"
```
Run `npm install` in `functions/`.

---

### Step 2 — Bundle Apple Root Certificate

Download `AppleRootCA-G3.cer` from `https://www.apple.com/certificateauthority/` and save to
`functions/certs/AppleRootCA-G3.cer`.

> **Why not `loadRootCAs()` from the library?**
> That function does not exist. The Apple README uses it as a pseudocode placeholder. The actual
> `SignedDataVerifier` constructor takes `Buffer[]` — you supply the certificates yourself.
> `AppleRootCA-G3.cer` is a public certificate, safe to commit to the repo.

---

### Step 3 — Store `originalTransactionId` / `androidPurchaseToken` in receipt-validation.ts

`original_transaction_id` is already extracted from the Apple receipt response inside
`validateAppleReceipt()`. Add it to all three Firestore write paths in `createOrUpdateSubscription`:

**Scenario A (new subscription) — add to the document fields:**
```typescript
originalTransactionId: platform === 'ios' ? originalTransactionId : null,
androidPurchaseToken: platform === 'android' ? receipt : null,
```

**Scenario B (renewal) and C (upgrade) — add to update fields:**
```typescript
...(platform === 'ios' && originalTransactionId && { originalTransactionId }),
...(platform === 'android' && receipt && { androidPurchaseToken: receipt }),
```

For Android, `receipt` (the `data.receipt` field passed to `validatePurchaseReceipt`) IS the
Google Play purchase token. No separate call needed.

> **Why not a separate `recordApplePurchase` Cloud Function called from Flutter?**
> That approach has a race condition: if the app crashes between receipt validation and the
> recording call, the subscription never gets `originalTransactionId` and webhooks can never
> find it. Server-side storage inside `validatePurchaseReceipt` is atomic and reliable.

---

### Step 4 — Add `APPLE_APP_ID` parameter

> **Why not `functions.config()`?**
> Firebase Functions v7 (which this project uses) deprecated `functions.config()` — it returns
> an empty object at runtime. The project already uses `defineSecret` for secrets. Use `defineInt`
> from `firebase-functions/params` for the App ID.

At the top of `functions/src/index.ts`, alongside existing `defineSecret` calls:
```typescript
import { defineSecret, defineInt } from 'firebase-functions/params';
const appleAppId = defineInt('APPLE_APP_ID', { default: 0 });
```

Set it before deploying:
```bash
firebase functions:params:set APPLE_APP_ID=YOUR_NUMERIC_ID
```

The numeric App ID is found in App Store Connect → Your App → General → App Information →
Apple ID.

---

### Step 5 — Add `appStoreWebhook` Cloud Function

Add to `functions/src/index.ts`:

```typescript
import * as fs from 'fs';
import * as path from 'path';
import {
  SignedDataVerifier,
  Environment,
  NotificationTypeV2,
} from '@apple/app-store-server-library';

const APPLE_BUNDLE_ID = 'com.driveusa.app';

// Bundled Apple Root CA — public certificate, safe to commit
const appleRootCAs: Buffer[] = [
  fs.readFileSync(path.join(__dirname, '../../certs/AppleRootCA-G3.cer')),
];

export const appStoreWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') { res.status(405).send('Method Not Allowed'); return; }

  const { signedPayload } = req.body;
  if (!signedPayload) { res.status(200).json({ received: true }); return; }

  try {
    const environment = process.env.FUNCTIONS_EMULATOR
      ? Environment.SANDBOX
      : Environment.PRODUCTION;

    const appId = appleAppId.value();
    const verifier = new SignedDataVerifier(
      appleRootCAs,
      true,                          // enableOnlineChecks (OCSP)
      environment,
      APPLE_BUNDLE_ID,
      appId > 0 ? appId : undefined  // required for Production; optional for Sandbox
    );

    const notification = await verifier.verifyAndDecodeNotification(signedPayload);
    const { notificationType, subtype, data, notificationUUID } = notification;

    // Apple sends this when you click "Send test notification" in App Store Connect
    if (notificationType === NotificationTypeV2.TEST) {
      console.log('✅ appStoreWebhook: Test notification received');
      res.status(200).json({ received: true });
      return;
    }

    if (!data?.signedTransactionInfo) {
      console.log(`ℹ️ appStoreWebhook: No transaction info for ${notificationType}`);
      res.status(200).json({ received: true });
      return;
    }

    const transaction = await verifier.verifyAndDecodeTransaction(data.signedTransactionInfo);
    const { originalTransactionId, expiresDate, productId } = transaction;

    // Idempotency: notificationUUID is Apple's own dedup key — same UUID on every retry
    if (!notificationUUID) {
      console.warn('⚠️ appStoreWebhook: Missing notificationUUID, skipping');
      res.status(200).json({ received: true });
      return;
    }

    const alreadyProcessed = await db.collection('processedWebhooks').doc(notificationUUID).get();
    if (alreadyProcessed.exists) {
      console.log(`⏭️ appStoreWebhook: Already processed ${notificationUUID}`);
      res.status(200).json({ received: true });
      return;
    }

    // Look up subscription by originalTransactionId
    const snap = await db.collection('subscriptions')
      .where('originalTransactionId', '==', originalTransactionId)
      .limit(1).get();

    if (snap.empty) {
      console.warn(`⚠️ appStoreWebhook: No subscription found for txn ${originalTransactionId}`);
      // Mark processed so retries don't pile up
      await db.collection('processedWebhooks').doc(notificationUUID).set({
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationType,
        subtype: subtype ?? null,
        originalTransactionId,
        result: 'subscription_not_found',
      });
      res.status(200).json({ received: true });
      return;
    }

    const subRef = snap.docs[0].ref;
    const subData = snap.docs[0].data();
    const userId = subData.userId as string;
    const userRef = db.collection('users').doc(userId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    // expiresDate is Unix milliseconds (number) per JWSTransactionDecodedPayload type
    const expiresTimestamp = expiresDate
      ? admin.firestore.Timestamp.fromMillis(expiresDate)
      : null;

    let subUpdates: Record<string, unknown> = { updatedAt: now };
    let userUpdates: Record<string, unknown> | null = null;
    let logAction = notificationType as string;

    switch (notificationType) {
      case NotificationTypeV2.DID_RENEW:
      case NotificationTypeV2.SUBSCRIBED:
        // Reactivate + update billing date + reset grace-period counter
        subUpdates = {
          ...subUpdates,
          isActive: true,
          status: 'active',
          renewalAttempts: 0,
          ...(expiresTimestamp && { nextBillingDate: expiresTimestamp }),
        };
        userUpdates = {
          isActive: true,
          ...(expiresTimestamp && { nextBillingDate: expiresTimestamp }),
          lastUpdated: now,
        };
        logAction = 'apple_renewed';
        break;

      case NotificationTypeV2.DID_FAIL_TO_RENEW:
        // Apple's grace period begins — keep access, flag as past_due
        subUpdates = { ...subUpdates, status: 'past_due' };
        logAction = 'apple_billing_failed';
        break;

      case NotificationTypeV2.GRACE_PERIOD_EXPIRED:
      case NotificationTypeV2.EXPIRED:
        // Grace period ended without payment / subscription definitively expired
        subUpdates = { ...subUpdates, isActive: false, status: 'inactive' };
        userUpdates = { isActive: false, lastUpdated: now };
        logAction = 'apple_expired';
        break;

      case NotificationTypeV2.REFUND:
      case NotificationTypeV2.REVOKE:
        // Refund issued or Family Sharing revoked
        subUpdates = { ...subUpdates, isActive: false, status: 'inactive' };
        userUpdates = { isActive: false, lastUpdated: now };
        logAction = 'apple_revoked';
        break;

      case NotificationTypeV2.DID_CHANGE_RENEWAL_STATUS:
        // User turned off auto-renew — access continues until billing period ends
        // isActive stays true; Cloud Scheduler handles final expiry
        subUpdates = { ...subUpdates, status: 'canceled' };
        logAction = 'apple_cancel_requested';
        break;

      default:
        console.log(`ℹ️ appStoreWebhook: Unhandled type ${notificationType}, skipping`);
        res.status(200).json({ received: true });
        return;
    }

    // Atomic batch: subscription + users (if needed) + dedup + audit
    const batch = db.batch();
    batch.update(subRef, subUpdates);
    if (userUpdates) {
      batch.set(userRef, userUpdates, { merge: true }); // merge: true — safe if user doc missing
    }
    batch.set(db.collection('processedWebhooks').doc(notificationUUID), {
      processedAt: now,
      notificationType,
      subtype: subtype ?? null,
      originalTransactionId,
    });
    batch.set(db.collection('subscriptionLogs').doc(), {
      userId,
      subscriptionId: snap.docs[0].id,
      action: logAction,
      oldStatus: { isActive: subData.isActive, status: subData.status },
      newStatus: {
        isActive: (subUpdates.isActive as boolean) ?? subData.isActive,
        status: subUpdates.status ?? subData.status,
      },
      timestamp: now,
      source: 'apple_webhook',
      originalTransactionId,
      productId,
    });
    await batch.commit();

    console.log(`✅ appStoreWebhook: ${logAction} for user ${userId}`);
    res.status(200).json({ received: true });

  } catch (err) {
    console.error('❌ appStoreWebhook error:', err);
    // Always return 200 — non-200 causes Apple to retry; our own bugs shouldn't trigger retries
    res.status(200).json({ received: true });
  }
});
```

---

### Step 6 — Add `handleGooglePlayNotifications` (Phase 2 — Android)

```typescript
export const handleGooglePlayNotifications = functions.pubsub
  .topic('google-play-rtdn')
  .onPublish(async (message) => {
    try {
      const dataStr = Buffer.from(message.data, 'base64').toString('utf-8');
      const notification = JSON.parse(dataStr);

      if (notification.testNotification) {
        console.log('✅ handleGooglePlayNotifications: Test notification received');
        return;
      }

      if (!notification.subscriptionNotification) {
        console.log('ℹ️ handleGooglePlayNotifications: Non-subscription notification, skipping');
        return;
      }

      const { notificationType, purchaseToken } = notification.subscriptionNotification;

      const snap = await db.collection('subscriptions')
        .where('androidPurchaseToken', '==', purchaseToken)
        .limit(1).get();

      if (snap.empty) {
        console.warn('⚠️ handleGooglePlayNotifications: No subscription found for purchaseToken');
        return;
      }

      const subRef = snap.docs[0].ref;
      const subData = snap.docs[0].data();
      const userId = subData.userId as string;
      const userRef = db.collection('users').doc(userId);
      const now = admin.firestore.FieldValue.serverTimestamp();

      // Notification type integers from Google Play:
      // 1=RECOVERED, 2=RENEWED, 3=CANCELED, 4=PURCHASED, 5=ON_HOLD,
      // 6=IN_GRACE_PERIOD, 7=RESTARTED, 12=REVOKED, 13=EXPIRED
      // NOTE: nextBillingDate is NOT updated here — Pub/Sub messages don't include expiry date.
      // Full expiry-date sync requires calling the Google Play Developer API (future work).
      let subUpdates: Record<string, unknown> = { updatedAt: now };
      let userUpdates: Record<string, unknown> | null = null;
      let logAction = `google_play_${notificationType}`;

      switch (notificationType) {
        case 1: case 2: case 4: case 7: // RECOVERED, RENEWED, PURCHASED, RESTARTED
          subUpdates = { ...subUpdates, isActive: true, status: 'active', renewalAttempts: 0 };
          userUpdates = { isActive: true, lastUpdated: now };
          logAction = 'google_renewed';
          break;
        case 3: // CANCELED
          subUpdates = { ...subUpdates, status: 'canceled' };
          logAction = 'google_cancel_requested';
          break;
        case 5: case 6: // ON_HOLD, IN_GRACE_PERIOD
          subUpdates = { ...subUpdates, status: 'past_due' };
          break;
        case 12: case 13: // REVOKED, EXPIRED
          subUpdates = { ...subUpdates, isActive: false, status: 'inactive' };
          userUpdates = { isActive: false, lastUpdated: now };
          logAction = 'google_expired';
          break;
        default:
          console.log(`ℹ️ handleGooglePlayNotifications: Unhandled type ${notificationType}`);
          return;
      }

      const batch = db.batch();
      batch.update(subRef, subUpdates);
      if (userUpdates) {
        batch.set(userRef, userUpdates, { merge: true });
      }
      batch.set(db.collection('subscriptionLogs').doc(), {
        userId,
        subscriptionId: snap.docs[0].id,
        action: logAction,
        oldStatus: { isActive: subData.isActive, status: subData.status },
        newStatus: {
          isActive: (subUpdates.isActive as boolean) ?? subData.isActive,
          status: subUpdates.status ?? subData.status,
        },
        timestamp: now,
        source: 'google_play_webhook',
        notificationType,
      });
      await batch.commit();

      console.log(`✅ handleGooglePlayNotifications: ${logAction} for user ${userId}`);
    } catch (err) {
      console.error('❌ handleGooglePlayNotifications error:', err);
      // Do NOT rethrow for invalid/permanent payloads — Pub/Sub retries on thrown errors
    }
  });
```

---

### Step 7 — Add Firestore rule for `processedWebhooks`

In `firestore.rules`:
```
match /processedWebhooks/{docId} {
  allow read, write: if false; // Written by Cloud Functions admin SDK only
}
```

---

### Step 8 — Add Firestore indexes

In `firestore.indexes.json`, add to the `indexes` array:
```json
{
  "collectionGroup": "subscriptions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "originalTransactionId", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "subscriptions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "androidPurchaseToken", "order": "ASCENDING" }
  ]
}
```

---

### Step 9 — Extend `UserSubscription` Dart model

In `lib/models/user_subscription.dart`, add two optional read-only fields:
```dart
final String? originalTransactionId;
final String? androidPurchaseToken;
```

Update `fromJson`, `toJson`, `copyWith`, and `toCacheJson`. These fields are **never written
from Flutter** — they exist so the Dart model round-trips Firestore data without losing fields
the server wrote.

---

### Step 10 — Deploy and configure

**Phase 1 (Apple):**
```bash
cd functions && npm install
firebase functions:params:set APPLE_APP_ID="YOUR_NUMERIC_ID"
firebase deploy --only functions:appStoreWebhook,firestore:rules,firestore:indexes
```

In **App Store Connect → Your App → General → App Store Server Notifications**:
- Paste `https://us-central1-licenseprepapp.cloudfunctions.net/appStoreWebhook`
- Enable for both **Production** and **Sandbox**
- Click **Send test notification** → verify `✅ appStoreWebhook: Test notification received` in logs

**Phase 2 (Android):**
1. GCP Console → Pub/Sub → Create topic: `google-play-rtdn`
2. Grant `google-play-developer-notifications@system.gserviceaccount.com` the Pub/Sub Publisher role
3. Google Play Console → Monetize → Monetization settings → Real-time Developer Notifications
   → enter `projects/licenseprepapp/topics/google-play-rtdn`
4. `firebase deploy --only functions:handleGooglePlayNotifications`
5. Click **Send test notification** in Play Console → verify logs

---

## Configuration Reference

| Item | Source | How to set |
|------|--------|------------|
| Bundle ID | `com.driveusa.app` | Hardcoded in function |
| Apple App ID (numeric) | App Store Connect → App Information → Apple ID | `firebase functions:params:set APPLE_APP_ID="..."` |
| Apple Root CA | Downloaded from Apple PKI | `functions/certs/AppleRootCA-G3.cer` |
| Webhook URL (Apple) | Firebase after deploy | Paste into App Store Connect |
| GCP Pub/Sub topic | Create in GCP Console | `google-play-rtdn` |
| Play Console Pub/Sub config | Google Play Console | Full topic path |

---

## Security

- **Apple**: JWS cryptographic verification via `SignedDataVerifier` + OCSP online checks
- **Google Play**: Pub/Sub delivery authenticated via Google infrastructure
- **Idempotency**: `processedWebhooks` collection deduplicates using Apple's own `notificationUUID`
- **Error responses**: Always return HTTP 200 — non-200 triggers Apple retries for our own bugs
- **`handleMockPaymentWebhook`**: Pre-existing insecure function — should be deleted before production

---

## Verification

1. **Sandbox purchase**: Make sandbox IAP → Firestore subscription doc gains `originalTransactionId`
2. **Accelerated renewal** (Sandbox): Use App Store Connect sandbox tools to speed up billing
   → `DID_RENEW` fires → Firestore `nextBillingDate` updates, subscription stays `active` without user opening app
3. **Test notification**: Click in App Store Connect → `TEST` logged, no errors, no Firestore writes
4. **Idempotency**: Re-send same webhook payload → `⏭️ Already processed` in logs, no double-write
5. **Users collection**: After `DID_RENEW`, `users/{uid}.isActive` and `nextBillingDate` match subscription
6. **Audit trail**: `subscriptionLogs` has entries with `source: 'apple_webhook'`

---

## Known Limitations

- **Android `nextBillingDate`**: Google Play Pub/Sub messages don't include the new expiry date.
  `nextBillingDate` is not updated by the Android webhook. Full fix requires calling the Google
  Play Developer API (future work). Cloud Scheduler handles server-side expiry detection regardless.
- **`handleMockPaymentWebhook`**: Insecure pre-existing function, no signature validation — delete
  before production.
