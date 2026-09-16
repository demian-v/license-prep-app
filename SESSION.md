# Local Hardening Session — security & money path

**Branch:** `local/security-money-hardening` (base `84300d0`, off `chore/play-billing-8-migration`)
**Started:** 2026-09-16
**Last updated:** 2026-09-16 (setup phase)
**Goal:** Fix the Critical + High security and revenue risks from `driveusa-risk-register`, verified locally. **Never deploy. Never touch the live Firebase project.**

> If this session is interrupted, read **How to resume** below. Everything needed to pick up is in this file.

---

## Ground rules

1. All work stays on `local/security-money-hardening`. Not pushed. `main` and `chore/play-billing-8-migration` are untouched.
2. Emulators run under project id **`demo-driveusa`**. Firebase treats any `demo-` project as offline-only — the SDK physically cannot reach production, even if misconfigured.
3. Production is **read-only**, and only for the one-time content export. No writes, no deploys, no rule pushes.
4. Every fix needs a verification that fails before the fix and passes after. No fix is marked DONE on inspection alone.
5. Emulator wiring in the Flutter app is behind `--dart-define=USE_EMULATOR=true`, default off, so a release build can never point at localhost.

---

## How to resume

```bash
cd /Users/demianvyrozub/projects/license-prep-app
git checkout local/security-money-hardening
git log --oneline -5            # what landed last
cat SESSION.md                  # this file — check the queue below
```

Then bring the environment up (see **Environment** for current state):

```bash
export PATH="/opt/homebrew/opt/node@22/bin:$PATH"   # functions need Node 22
firebase emulators:start --project demo-driveusa --import=.emulator-data
```

Run the app against it:

```bash
flutter run -d "iPhone 16 Pro" --dart-define=USE_EMULATOR=true
```

---

## Environment setup

| # | Step | Status | Notes |
|---|---|---|---|
| E1 | Local branch created | ✅ DONE | `local/security-money-hardening` @ `84300d0` |
| E2 | Session file | ✅ DONE | this file |
| E3 | Node 22 installed | ✅ DONE | `brew install node@22` (keg-only). Prepend `/opt/homebrew/opt/node@22/bin` to PATH for any functions work |
| E4 | `emulators` block in `firebase.json` | ✅ DONE | auth 9099, functions 5001, firestore 8080, storage 9199, pubsub 8085, ui 4000 |
| E5 | Local secrets for emulator | ✅ DONE | `functions/.secret.local`, dummy values, gitignored |
| E6 | Content exported from production | ✅ DONE | 6,627 docs (~8.7 MB) via ADC, read-only, into `.local-export/` (gitignored). Seeded into emulator with `scripts/local/seed-emulator.js`. **No user data copied** |
| E7 | Flutter emulator wiring | ✅ DONE | `lib/config/emulator_config.dart`, one call in `main.dart`. Throws in release mode |
| E8 | iOS pods reinstalled | ✅ DONE | 43 pods, Sep 16. **Needs `LANG=en_US.UTF-8`** or CocoaPods dies on a Ruby 3.4 encoding bug |
| E9 | App runs on simulator against emulators | ✅ DONE | iPhone 16 Pro, login screen, Firestore probe OK (`host=127.0.0.1:8080 ssl=false`) |

## Test harness (risk #17 — prerequisite, not optional)

| # | Step | Status | Notes |
|---|---|---|---|
| T1 | Jest + ts-jest in `functions/` | ✅ DONE | `npm test` wraps `firebase emulators:exec --project demo-driveusa`. Emulators spin up, tests run, teardown is automatic |
| T2 | `@firebase/rules-unit-testing` suite | ✅ DONE | `firestore-rules.test.ts` — risks #3, #29. Own project id `demo-rules-test`, never touches seeded data |
| T3 | StoreKit configuration file | ⬜ TODO | local fake store for simulator purchase / restore / renewal / trial→paid |
| T4 | One red test per in-scope risk | 🔄 IN PROGRESS | #3 and #29 complete. **16 tests, all green**, incl. paid + trial positive controls |

---

## Fix queue — security & money

Status: ⬜ not started · 🔄 in progress · ✅ done & verified · ⏸️ blocked · ⏭️ deferred

### Critical

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #3 | Paid content corpus served with no auth — 7 callables have no `context.auth`; rules gate only on `auth != null` while `main.dart` signs everyone in anonymously | ✅ **DONE** | `content-auth.test.ts` + `firestore-rules.test.ts`, 16 green | `851a8a1` + rules |
| #4 | `handleMockPaymentWebhook` (unauthenticated POST) and test-data callables deployed to production | ✅ **DONE** | `no-test-endpoints.test.ts` — asserts absence, 5 red → green | all five deleted + orphaned `test-data-generator.ts` |

### High — money path

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #2 | `upgradeSubscription` grants 365 days yearly, free, no audit row | ✅ **DONE** | `no-free-upgrade.test.ts` | Deleted server-side **and** the whole client path: UI button, confirmation dialog, provider + service methods, model helpers, and the orphaned `UpgradeCalculator` (138 lines). ~480 lines removed in total |
| #5 | No receipt→account binding — one receipt entitles unlimited accounts | ⬜ | function test | |
| #6 | `yearly` receipts dropped client-side (`_activeProductIds` = monthly only) | ⬜ | dart test + StoreKit | **Approach changed 2026-09-16: remove yearly**, don't re-enable. Drop from `productIds` and the server allow-list |
| #7 | Home-grown 18h grace period vs Apple 16d / Google 30d | ⬜ | function test | |
| #8 | Play `PAUSED` / `PAUSE_SCHEDULE_CHANGED` (types 10, 11) not modelled | ⬜ | function test | |
| #9 | Webhooks always return 200, no dead-letter, no reconciliation | ⬜ | function test | |
| #19 | Rate limit counts failures — paying user locked out for an hour | ⬜ | function test | |
| #20 | `subscriptionsType` is a single point of failure for every purchase | ⬜ | function test | |
| #22 | Duplicate `subscriptions` docs after re-subscribe; webhooks update the corpse | ⬜ | function test | |

### High — security / abuse

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #18 | 8 admin-grade functions callable by any authenticated user | ✅ **DONE** | `admin-auth.test.ts` — 12 tests, 4 red → green, with admin positive controls | Four gated by `requireAdmin()`; the other four were the test-data callables already deleted under #4 |
| #12 | `sendEmailVerification()` never called; `emailVerified` gates nothing | ⬜ | function test + iOS | |
| #26 | Trial gate forgeable (client-supplied `deviceIdHash`), dedupe non-transactional | ⬜ | function test | |
| #29 | `users/{uid}` accepts arbitrary client writes including `isActive` | ✅ **DONE** | `firestore-rules.test.ts` | rules blocklist |

### Resolved by product decision

| Risk | What | Status | Notes |
|---|---|---|---|
| #43 | Year length disagrees: catalogue `duration: 360` vs `upgradeSubscription` `duration: 365` | ⏭️ MOOT | Only the 30-day plan is sold. The mismatch lives entirely in yearly code being removed under #2 and #6 |

### Taken in, out of the original scope

| Risk | What | Status | Why it was pulled in |
|---|---|---|---|
| #16 | No `predeploy` hook — `firebase deploy --only functions` ships stale compiled JS | ✅ **DONE** | Not optional after all: `functions/lib/index.js` was compiled **Apr 27**, five months stale. The emulator runs `lib/`, so every local verification was against April code until this was found. Added `predeploy` to `firebase.json` and deleted the dead root `index.js` shim |

**Out of scope this round** (tracked, not started): #13 #14 privacy/deletion · #21 cross-device sync · #36 CI · #49 Docker · #53 content authoring · #55 #56 store platform (already handled/mitigated) · all remaining Medium rows.

---

## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-09-16 | Skip Agent Orchestrator; Claude Code subagents + worktrees instead | ~20 of the fixes touch `functions/src/index.ts`; parallel agents on one file means merge conflicts, and with no tests nobody notices a bad merge |
| 2026-09-16 | Build the test harness before fixing | ~35 of the risks are server-side and invisible in the iOS UI. Without tests they'd ship on trust. Also closes #17 |
| 2026-09-16 | Export production content read-only rather than hand-seeding | Emulator starts blank; app is unusable without content. Seed script deferred to the #53 fix |
| 2026-09-16 | Emulators run as `demo-driveusa`, not `licenseprepapp` | `.firebaserc` points at production; a `demo-` project id makes reaching production physically impossible |
| 2026-09-16 | **Only the 30-day monthly plan is sold. Yearly is removed, not fixed** | Owner decision. Production has **zero** yearly subscriptions ever (register, verified 2026-08-20), so nobody is stranded. Turns #2 from a redesign into a deletion, #6 from an implementation into a removal, and makes #43 moot |
| 2026-09-16 | Emulators run under the REAL project id, not `demo-driveusa` | `FirebaseOptions` is a matched set; overriding only `projectId` leaves the real API key, so Firebase Installations calls `projects/demo-*/installations` with a key that does not belong to it. Owner chose to **revoke ADC first** (`gcloud auth application-default revoke`), so the machine now holds no production credentials at all — a stronger position than the `demo-` prefix gave |
| 2026-09-16 | Gate content rules on `users/{uid}.isActive`, and make trials write it | It is the server-maintained entitlement mirror the purchase path, renewal manager and schedulers already use. `createTrialSubscription` was the one path that never wrote it, so gating on it without that fix would have locked out every trial user |
| 2026-09-16 | Blocklist rather than allowlist for `users/{uid}` writes | Several services write profile fields dynamically (`email_sync_service` passes a computed map); an allowlist would break them. The blocklist covers the nine fields that decide entitlement, which is what #29 is actually about |
| 2026-09-16 | Leave the `Pods-Runner.profile.xcconfig` warning alone | Runner's Profile config points at `Flutter/Release.xcconfig`. Debug and Release are correctly wired; only Profile builds (performance profiling, never shipped) are affected. Not a register risk, and editing Xcode build config on a security branch invites unrelated breakage |

## Gotchas

- `.firebaserc` pins `licenseprepapp` (production). Always pass `--project demo-driveusa` to emulator commands.
- `functions/service-account.json` exists locally and is untracked. It has production write access — only ever use it for the read-only export.
- `functions/.env.licenseprepapp` is still **tracked in git** (risk #32). `.gitignore` lists it but gitignore does not untrack. Needs `git rm --cached` — separate cleanup, not part of this branch.
- Do not run `initializeGlobalCounterFromExistingReports` or `resetGlobalCounter` against anything (register Top-7 item 5).

## Root causes found while building the environment

**The app could not reach the emulator, and it was not a networking problem.**
`analytics_service.dart:42` called `Firebase.initializeApp()` a **second time, with
no options**, right after `main()` had initialised the default app with explicit
ones. On iOS that re-reads `GoogleService-Info.plist` and discards the emulator
settings applied moments earlier. Guarded with `if (Firebase.apps.isEmpty)`.
This is a real latent bug in the app, not a local-setup quirk — the redundant
call is in the shipped build too.

Diagnostic left in place (`🧪 Firestore settings -> host=… ssl=…` plus a probe
read) because it makes a silent misconfiguration loud. It only runs under
`USE_EMULATOR`.

## Reproduced evidence — risk #58, live on the simulator

Signing up in the app creates the `users/{uid}` document but **no subscription
and no entitlement**, and the screen says nothing about it. Cause:
`createTrialSubscription` throws `failed-precondition` unless
`isPhysicalDevice === true`, and a simulator is not a physical device. The gate
is working as designed; the defect is that the app renders `SizedBox.shrink()`
for that state instead of an explanation (#58).

Consequence for local work: **the simulator can never obtain a trial through the
app.** Use `scripts/local/grant-local-trial.js <email>` (with
`FIRESTORE_EMULATOR_HOST` set), which writes exactly what
`createTrialSubscription` would, including the `users/{uid}` entitlement mirror.

## Observed once, not reproduced

`Error in createOrUpdateUserDocument: TypeError: Cannot read properties of
undefined (reading 'serverTimestamp')` appeared in the emulator during one
signup. A focused test calling that callable passes, and
`admin.firestore.FieldValue.serverTimestamp` is defined in the test runtime.
Most likely the emulator hot-reloaded `functions/lib/` mid-rebuild. **Not
fixed, not claimed fixed** — re-check if it recurs on a stable build.

## Reproduced evidence

**Risk #3, 2026-09-16.** An unauthenticated call to `getQuizQuestions` (no `context.auth` whatsoever) returned:

```
{"id":"q1","correctAnswer":0,"explanation":"A red octagon is always a stop sign.", ...}
```

The answer key and explanation are served to an anonymous stranger. Reproduce with `cd functions && npm test`.

## Follow-ups created by this work

- `lib/models/user_subscription.dart:isUpgradeEligible` is dead code — and was already dead at the base commit `84300d0` (zero callers), so it is **not** an orphan this work created. Natural cleanup during #6, when yearly leaves the codebase.
- `lib/docs/server_side_subscription_management_implementation.md:672` documents the now-deleted test-data generation system. Stale; left alone deliberately (documentation drift, not a security fix).
- `docs/webhook.md` asks twice for `handleMockPaymentWebhook` to be removed before production. Now done — that document can drop the warning.
- Register Top-7 #2 suggests counting `subscriptionLogs` where `processedBy == 'scheduled_function'` to see how much audit trail `cleanupSubscriptionTestData` already destroyed. **Not done** — it needs a production read, and this machine deliberately has no production credentials now. Owner call.

## Gotchas found during setup

- `pod install` needs `export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`, otherwise CocoaPods 1.16.2 on Ruby 3.4 dies with `Encoding::CompatibilityError`. It exits non-zero but a piped `tail` will mask it — always check `Podfile.lock`'s date.
- Xcode warns that `Runner` has a custom base configuration so CocoaPods did not set `Pods-Runner.profile.xcconfig`. Pre-existing, affects Profile builds only. Not touched.
- `functions/package.json` pins Node 22; the machine's default is Node 20. Every functions command needs the PATH prefix.
- The functions emulator prompts for `APPLE_APP_ID` and hangs forever if unanswered. `functions/.env.local` supplies it. **Note:** the code declares `defineInt('APPLE_APP_ID', { default: 0 })` — so if it is unset in *production*, Apple notification verification runs against app id `0`. That is the unverified item in the register's Top-7 #5, and the default confirms the failure mode is real.
- Since ADC now exists, the functions emulator warns that **non-emulated** Google APIs will hit production with those credentials. Emulated services (Firestore/Auth/Storage/Functions) are unaffected. Run `gcloud auth application-default revoke` once the content export is no longer needed.
- Test fixtures use the synthetic `state: 'ZZ' / language: 'zz'` so they cannot collide with the 6,627 seeded production documents.
- **The functions emulator runs `functions/lib/`, not `functions/src/`.** After any TypeScript change run `npm --prefix functions run build`, or the emulator keeps serving stale compiled JS. `npx jest` uses ts-jest on the source, so tests can pass while the emulator still runs old code — they disagreed for most of this session's first hours.
- When the long-running emulator is already up, run `npx jest` directly. `npm test` wraps `emulators:exec`, which will fail on the already-bound ports.

## Owner action required outside the repo

- **Provision an `admins/{uid}` document** (register risk #45). The collection is empty, so `processSubscriptionsManualy`, `getSubscriptionStats`, `subscriptionSystemHealth` and `getRenewalStats` are now callable by nobody — deliberate, but it means those stats endpoints stay closed until an admin exists. It also unblocks reading the 27 filed `reports`, which today are reachable only through the Firebase console. Create it in the console; the collection is client-deny by rule.

- **Deactivate the yearly SKU in App Store Connect and Google Play Console.** Removing it from the code stops the app offering it, but if the SKU stays purchasable in either store a user could still buy it through a store-side resubscribe flow and receive nothing. Code alone does not close this.
- `subscriptionsType/2` (the yearly catalogue row) is left in production untouched — harmless once nothing references yearly, and deleting it would be a production write.
