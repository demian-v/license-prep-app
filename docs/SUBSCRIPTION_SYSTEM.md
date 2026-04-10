# Subscription System — Architecture & Reference

Last updated: 2026-04-07  
Branch at time of writing: `ios_prod_1`

---

## Overview

Subscription management is split between **Cloud Functions** (server-side writes) and the **Flutter client** (reads + cache). All writes that activate, cancel, or upgrade a subscription go through a Cloud Function. The client never writes directly to the `subscriptions` collection.

---

## Firestore Collections

### `subscriptions/{autoId}`

One document per subscription lifecycle event. A user may have multiple documents over time (e.g., trial → paid → canceled → new trial is prevented by duplicate check).

| Field | Type | Notes |
|---|---|---|
| `id` | string | Matches the document ID |
| `userId` | string | Firebase Auth UID of the owner |
| `packageId` | int | 3 = trial, other IDs from `subscription_packages` collection |
| `planType` | string | `"trial"`, `"monthly"`, `"yearly"` |
| `status` | string | See status table below |
| `isActive` | bool | Whether the user currently has app access |
| `duration` | int | Duration in days (3 for trial, 30 for monthly, 365 for yearly) |
| `price` | double | 0 for trial |
| `trialUsed` | int | 0 during trial; 1 after trial converts to paid |
| `trialEndsAt` | Timestamp | Trial expiry date (only meaningful for `planType=trial`) |
| `nextBillingDate` | Timestamp | When the subscription period ends / next charge occurs |
| `createdAt` | Timestamp | Server-set on document creation |
| `updatedAt` | Timestamp | Server-set on every update |

#### `status` values

| Value | Meaning | `isActive` |
|---|---|---|
| `"active"` | Subscription is running normally | `true` |
| `"canceled"` | User canceled; may still have access until `nextBillingDate` | `true` or `false` |
| `"inactive"` | Period expired; no access | `false` |
| `"expired"` | Alias for inactive used by some Cloud Scheduler paths | `false` |

> **Rule:** `isActive` is the access gate, not `status`. A canceled subscription with `isActive=true` still has full app access.

---

### `users/{userId}`

Billing dates are denormalized here for backwards compatibility. Cloud Function writes go to `subscriptions`; the Flutter client then calls `_syncUserBillingDates()` to mirror them here.

| Field | Notes |
|---|---|
| `status` | Mirrors subscription status — set on signup, not kept in sync by server |
| `lastBillingDate` | Date of last charge (or signup date for trial) |
| `nextBillingDate` | Trial/subscription end date — must match `subscriptions.nextBillingDate` |

---

## Cloud Functions (all in `functions/src/index.ts`)

### `createTrialSubscription` — callable

Called during new user signup. Replaces the old client-side `_createInitialTrialSubscription`.

**Input:** none (uses `context.auth.uid`)  
**Checks:**
- User must be authenticated
- No existing subscription document for this userId (prevents duplicate trials)

**Writes to `subscriptions`:**
```
planType: "trial", status: "active", isActive: true
packageId: 3, duration: 3, price: 0, trialUsed: 0
trialEndsAt: now + 3 days
nextBillingDate: now + 3 days
createdAt/updatedAt: serverTimestamp()
```

**Returns:** `{ subscriptionId: string }`

**Why it exists:** Client was computing dates locally, causing a 2017-timestamp bug when the device clock was wrong. Server timestamps are now authoritative.

---

### `cancelSubscription` — callable

Called when the user taps "Cancel Subscription".

**Input:** none (uses `context.auth.uid`)  
**Checks:**
- User must be authenticated
- Must have a document with `isActive=true`

**Logic:**
- If `nextBillingDate` is in the future → `isActive = true` (user keeps access for paid days)
- If `nextBillingDate` is in the past / missing → `isActive = false` (access removed immediately)
- Always sets `status = "canceled"`

**Returns:** `{ success: true, isActive: bool }`

---

### `upgradeSubscription` — callable

Called when a monthly subscriber taps "Upgrade to Yearly".

**Input:** `{ targetPlanType: "yearly", packageId: int }`  
**Checks:**
- User must be authenticated
- Must have a document with `isActive=true` AND `planType="monthly"` (trial users cannot upgrade for free)
- `targetPlanType` must equal `"yearly"` (only monthly→yearly is supported)

**Logic (proration):**
- `remainingDays = ceil((nextBillingDate - now) / 1 day)` clamped to 0
- `newBillingDate = now + 365 + remainingDays days`

**Writes:** `planType: "yearly"`, `duration: 365`, `nextBillingDate`, `status: "active"`, `isActive: true`

**Returns:** `{ success: true, newBillingDate: ISO string }`

**IAP:** No new purchase required — free proration for existing monthly subscribers. This is intentional product behavior.

---

### `validatePurchaseReceipt` — callable (unchanged)

Handles initial purchase (monthly or yearly). Validates App Store / Play Store receipts before activating a subscription. Not modified in this change.

---

### `checkExpiredSubscriptions` — scheduled (every 1 hour, unchanged)

Server-side expiry sweep. Sets `isActive=false`, `status="expired"` for subscriptions past their `nextBillingDate`. This is the authoritative expiry mechanism — the client-side check in `session_manager.dart` is a best-effort mirror.

---

### `renewActiveSubscriptions` — scheduled (every 6 hours, unchanged)

Extends `nextBillingDate` for auto-renewing subscriptions.

---

## Flutter Client Architecture

### Write paths (what calls which CF)

| User action | Flutter file | Cloud Function called |
|---|---|---|
| New user signup | `direct_auth_service.dart:createUserDocuments()` | `createTrialSubscription` |
| Buy monthly/yearly | `receipt_validation` flow | `validatePurchaseReceipt` |
| Cancel subscription | `subscription_management_service.dart:cancelSubscription()` | `cancelSubscription` |
| Upgrade to yearly | `subscription_management_service.dart:upgradeSubscription()` | `upgradeSubscription` |
| Expiry detection (client) | `session_manager.dart:_performSubscriptionStatusCheck()` | none — direct write, try-catch wrapped |

### Read pattern

All subscription reads go through `SubscriptionManagementService.getUserSubscription(userId)`, which queries Firestore for the most recent active subscription. Results are cached in `SharedPreferences` under `"user_subscription_cache"`.

After every CF write, the client re-fetches from Firestore:
```dart
final updated = await getUserSubscription(userId) ?? currentSubscription;
```
The server is the source of truth; the local cache is refreshed from the re-fetch.

### `_syncUserBillingDates`

After any cancel or upgrade CF call, the client calls `_syncUserBillingDates(userId, lastBilling, nextBilling)` to mirror dates into the `users` collection. This is a denormalization shim kept for backwards compatibility — other parts of the app read from `users` for billing display. It should be removed in a future cleanup once all reads are migrated to use `subscriptions`.

---

## Security Model

### Firestore rules (pending Step 6 deploy)

```javascript
match /subscriptions/{subscriptionId} {
  // Read: owner only
  allow read: if request.auth != null && request.auth.uid == resource.data.userId;
  // Write: blocked for all clients — only Cloud Functions (admin SDK) can write
  allow write: if false;
}

match /counters/global_report_counter {
  allow read: if request.auth != null;
  // Enforce exactly +1 increments; prevent resets or arbitrary values
  allow update: if request.auth != null
    && request.resource.data.value == resource.data.value + 1
    && request.resource.data.keys().hasOnly(['value', 'lastUpdated', 'description']);
  allow create: if false;
  allow delete: if false;
}
```

**Before these rules are deployed:** Firestore rules still allow direct client writes. The CF layer is in place but not yet enforced at the database level.

---

## Subscription Lifecycle (happy path)

```
Signup
  └─ createTrialSubscription CF
       └─ subscriptions doc: planType=trial, status=active, isActive=true, trialEndsAt=+3d

Trial expires (server sweep)
  └─ checkExpiredSubscriptions CF
       └─ subscriptions doc: status=expired, isActive=false

User purchases
  └─ validatePurchaseReceipt CF
       └─ subscriptions doc: planType=monthly|yearly, status=active, isActive=true

Monthly user upgrades
  └─ upgradeSubscription CF
       └─ subscriptions doc: planType=yearly, duration=365, nextBillingDate=+365+remainingDays

User cancels
  └─ cancelSubscription CF
       └─ subscriptions doc: status=canceled
            ├─ isActive=true  (if nextBillingDate in future — access until period ends)
            └─ isActive=false (if already past nextBillingDate)

Period ends post-cancel (server sweep)
  └─ checkExpiredSubscriptions CF
       └─ subscriptions doc: isActive=false
```

---

## What Changed (2026-04-07)

| Before | After |
|---|---|
| Trial subscription created client-side with local timestamps | Created by `createTrialSubscription` CF with server timestamps |
| Cancel wrote directly to Firestore from Flutter | Goes through `cancelSubscription` CF |
| Upgrade wrote directly to Firestore from Flutter; no eligibility check | Goes through `upgradeSubscription` CF; validates `planType=monthly` server-side |
| 2017-date bug on signup (device clock issue) | Fixed — CF uses `admin.firestore.Timestamp` |
| Any user could self-activate via REST API | Blocked (pending rules deploy) |
| Trial users could upgrade to yearly for free | Blocked server-side (CF requires `planType=monthly`) |
| `session_manager` crash if rules block expiry write | Wrapped in try-catch; failure is logged and swallowed |

### Files modified
- `functions/src/index.ts` — added `createTrialSubscription`, `cancelSubscription`, `upgradeSubscription`
- `lib/services/direct_auth_service.dart` — replaced `_createInitialTrialSubscription` with CF call
- `lib/services/subscription_management_service.dart` — cancel and upgrade now call CFs + re-fetch; removed `upgrade_calculator.dart` import
- `lib/services/session_manager.dart` — wrapped `updateSubscriptionStatus` call in try-catch
