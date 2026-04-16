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
Apple:   Apple servers → HTTPS POST → appStoreWebhook (onRequest) → Firestore
Android: Google Play → Pub/Sub topic → handleGooglePlayNotifications (pubsub.onPublish) → Firestore
```

`originalTransactionId` (iOS) and `androidPurchaseToken` (Android) are stored server-side
inside `validatePurchaseReceipt` when the subscription is first created — no Flutter changes
required, no race conditions.

---

## Files Modified

| File | Change |
|------|--------|
| `functions/package.json` | Added `@apple/app-store-server-library` |
| `functions/certs/AppleRootCA-G3.cer` | New — bundled Apple root certificate (public, safe to commit) |
| `functions/src/receipt-validation.ts` | Stores `originalTransactionId` / `androidPurchaseToken` in all Firestore write paths |
| `functions/src/index.ts` | Added `appStoreWebhook`, `handleGooglePlayNotifications`, `appleAppId` param, `googleCredentials` secret |
| `firestore.rules` | Added `processedWebhooks` rule |
| `lib/models/user_subscription.dart` | Added optional read-only fields for round-tripping |

**Not in `firestore.indexes.json`:** Single-field indexes (`originalTransactionId`,
`androidPurchaseToken`) are created automatically by Firestore — no explicit entry needed.

---

## Key Corrections vs. Original Plan

The original plan had 3 critical bugs, found during review before any code was written:

### Bug B1 — Certificate path was wrong (would crash on every cold start)
`__dirname` at runtime = `functions/lib/` (TypeScript compiles `src/` → `lib/`).
Original plan used `../../certs/` which resolves to the parent of `functions/`.
**Fixed:** `../certs/AppleRootCA-G3.cer` — one level up from `lib/`, which is `functions/certs/`.

### Bug B2 — DID_CHANGE_RENEWAL_STATUS ignored subtype
Apple uses one notification type for two opposite actions:
- `AUTO_RENEW_DISABLED` → user turned off auto-renew (set status `canceled`)
- `AUTO_RENEW_ENABLED` → user turned auto-renew back ON (restore status `active`)

Original plan set `status: 'canceled'` unconditionally, permanently canceling subscriptions when
users re-enabled auto-renew.
**Fixed:** Decode `signedRenewalInfo` alongside `signedTransactionInfo` and branch on
`renewalInfo.autoRenewStatus === AutoRenewStatus.ON`.

### Bug B3 — Android Pub/Sub had no idempotency
Google Cloud Pub/Sub guarantees at-least-once delivery — duplicate messages are normal.
Original plan processed every delivery unconditionally.
**Fixed:** Use `message.messageId` as dedup key in `processedWebhooks` collection (prefixed
`gp_` to avoid collisions with Apple's `notificationUUID`).

### Bug B4 — Android webhook left `nextBillingDate` in the past
Without updating `nextBillingDate` after an Android renewal, the 6-hour Cloud Scheduler would
re-enter grace period on every run (sees `nextBillingDate <= now` AND `status='active'`), causing
a permanent active→past_due flip-flop.
**Fixed:** On renewal events (types 1, 2, 4, 7), call the Google Play Developer API
(`subscriptionsv2.get`) to fetch the real expiry time. If the API call fails, fall back to a
heuristic: extend `nextBillingDate` by one billing cycle duration.

---

## Post-Implementation Audit Fixes

After the initial implementation, a code audit identified 3 additional bugs in the implementation
of the Android webhook (B4 fix). All were fixed and redeployed on 2026-04-14.

### Bug P1 — `expiryTime` parsed as integer instead of date string (B4 fix was silently harmful)
Google Play `subscriptionsv2.get()` returns `lineItems[0].expiryTime` as an RFC 3339 string
(e.g. `"2026-05-14T19:30:00Z"`). The implementation used `parseInt(expiryTimeStr, 10)` which
extracts only the leading digits before `"-"` — returning the year as milliseconds
(e.g. `2026ms = Jan 1, 1970`). `2026 > 0` is true, so `nextBillingDate` was being set to 1970
whenever the Play API call succeeded, causing the scheduler to immediately re-enter grace period.
This made B4 actively worse in the success path.

**Fixed:** `parseInt(expiryTimeStr, 10)` → `new Date(expiryTimeStr).getTime()`

```typescript
// Before (wrong — returns year as milliseconds ≈ epoch)
const expiryMs = parseInt(expiryTimeStr, 10);

// After (correct — parses RFC 3339 to Unix milliseconds)
const expiryMs = new Date(expiryTimeStr).getTime();
```

### Bug P2 — `handleGooglePlayNotifications` missing `runWith` for secrets (B4 fix never ran)
The function called `googleCredentials.value()` to authenticate against the Google Play API,
but was defined without `.runWith({ secrets: [googleCredentials] })`. Firebase Functions v1
requires secrets to be declared in `runWith` — without it, the runtime provides an empty string.
The Google Play API call always failed silently and the heuristic fallback always ran instead.

**Fixed:** Added `.runWith({ secrets: [googleCredentials] })` to the function definition.

```typescript
// Before
export const handleGooglePlayNotifications = functions.pubsub
  .topic('play-rtdn')
  .onPublish(async (message) => { ... });

// After
export const handleGooglePlayNotifications = functions
  .runWith({ secrets: [googleCredentials] })
  .pubsub.topic('play-rtdn')
  .onPublish(async (message) => { ... });
```

> **Note on ordering:** P2 must be fixed before P1 matters in production. Without `runWith`,
> the API call never ran (heuristic always fired). Fixing `runWith` first makes the API call
> reachable; fixing the parse ensures the returned date is correct.

### Bug P3 — `packageName` read from wrong path in Pub/Sub payload
In Google's RTDN Pub/Sub payload, `packageName` is a **top-level** field, not inside
`subscriptionNotification`. The implementation accessed
`notification.subscriptionNotification.packageName` which is always `undefined`, silently
falling back to the hardcoded `'com.driveusa.app'` default on every invocation.

**Fixed:** Changed to `notification.packageName`.

---

## Setup Instructions

### Step 1 — Bundle Apple Root Certificate

Download `AppleRootCA-G3.cer` from `https://www.apple.com/certificateauthority/` and save to
`functions/certs/AppleRootCA-G3.cer`. This is a public certificate — safe to commit.

> **Why not `loadRootCAs()` from the library?**
> That function does not exist. The Apple README uses it as pseudocode. The actual
> `SignedDataVerifier` constructor takes `Buffer[]` — you supply the certificates yourself.

### Step 2 — Set the Apple App ID parameter

```bash
firebase functions:params:set APPLE_APP_ID="YOUR_NUMERIC_ID"
```

Apple ID found in: App Store Connect → Your App → General → App Information → Apple ID.

> **Why not `functions.config()`?**
> Firebase Functions v7 deprecated `functions.config()` — it returns an empty object at runtime.
> This project uses `defineSecret` / `defineInt` from `firebase-functions/params`.

### Step 3 — Verify Bundle ID before deploying

`APPLE_BUNDLE_ID = 'com.driveusa.app'` is hardcoded in `index.ts`. If this does not match the
actual bundle ID in App Store Connect, every notification will fail JWS verification silently
(caught exception → 200, no processing). Confirm in App Store Connect before deploying.

### Step 4 — Deploy Phase 1 (Apple)

```bash
cd functions && npm install
firebase deploy --only functions:appStoreWebhook,firestore:rules
```

In **App Store Connect → Your App → General → App Store Server Notifications**:
- Paste `https://us-central1-licenseprepapp.cloudfunctions.net/appStoreWebhook`
- Enable for both **Production** and **Sandbox**
- Click **Send test notification** → verify `✅ appStoreWebhook: Test notification received` in logs

### Step 5 — Deploy Phase 2 (Android)

```bash
firebase deploy --only functions:handleGooglePlayNotifications
```

1. GCP Console → Pub/Sub → Create topic: `play-rtdn`
2. Grant `google-play-developer-notifications@system.gserviceaccount.com` the **Pub/Sub Publisher** role
3. Google Play Console → Monetize → Monetization settings → Real-time Developer Notifications
   → enter `projects/licenseprepapp/topics/play-rtdn`
4. Click **Send test notification** in Play Console → verify logs

---

## Security

- **Apple**: JWS cryptographic verification via `SignedDataVerifier` + OCSP online checks
- **Google Play**: Pub/Sub delivery authenticated via Google infrastructure
- **Idempotency (Apple)**: `processedWebhooks` deduplicates using Apple's own `notificationUUID`
- **Idempotency (Android)**: `processedWebhooks` deduplicates using `gp_<message.messageId>`
- **Error responses**: Always return HTTP 200 — non-200 triggers Apple retries for our own bugs
- **`handleMockPaymentWebhook`**: Pre-existing insecure function — delete before production

---

## Configuration Reference

| Item | Source | How to set |
|------|--------|------------|
| Bundle ID | `com.driveusa.app` | Hardcoded in `index.ts` — verify in App Store Connect |
| Apple App ID (numeric) | App Store Connect → App Information → Apple ID | `firebase functions:params:set APPLE_APP_ID="..."` |
| Apple Root CA | Downloaded from Apple PKI | `functions/certs/AppleRootCA-G3.cer` |
| Google Credentials | Already configured | `GOOGLE_CREDENTIALS` secret in Secret Manager |
| Webhook URL (Apple) | Firebase after deploy | Paste into App Store Connect |
| GCP Pub/Sub topic | Create in GCP Console | `play-rtdn` |
| Play Console Pub/Sub config | Google Play Console | Full topic path |

---

## Verification Checklist

1. **Cert loading**: Deploy to emulator → confirm function starts without `ENOENT`
2. **Test notification (Apple)**: Click in App Store Connect → `TEST` logged, no Firestore writes
3. **Sandbox purchase**: Make sandbox IAP → subscription doc gains `originalTransactionId`
4. **Accelerated renewal**: Apple sandbox tools → `DID_RENEW` → `nextBillingDate` updates, `status='active'`
5. **Idempotency (Apple)**: Re-send same `signedPayload` → `⏭️ Already processed` in logs, no duplicate `subscriptionLogs`
6. **Cancel + re-enable (Apple)**: Disable auto-renew → `status='canceled'`. Re-enable → `status='active'` (not `'canceled'` again — Bug B2 fix)
7. **Android Pub/Sub dedup**: Replay same Pub/Sub message twice → one `subscriptionLogs` entry, `processedWebhooks` has `gp_<messageId>` entry
8. **Android nextBillingDate**: After Android RENEWED event → `nextBillingDate` advances; scheduler no longer enters grace period
9. **Existing subscriber**: Find subscription without `originalTransactionId` → trigger Apple webhook → `subscription_not_found` logged → make one purchase → field stored → next webhook finds it

---

## Known Limitations

- **Existing subscribers self-heal**: Subscribers who purchased before this deployment don't have
  `originalTransactionId` / `androidPurchaseToken` stored. Webhooks for them log
  `subscription_not_found` and are discarded until the user makes any new purchase (renewal or
  manual), which writes the field. The Cloud Scheduler continues to handle their subscription
  state in the interim.
- **`handleMockPaymentWebhook`**: Insecure pre-existing function with no signature validation —
  delete before production.
