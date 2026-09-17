# Local Hardening Session — security & money path

## STATUS AT A GLANCE — read this first

| | |
|---|---|
| **Branch** | `local/security-money-hardening` (base `84300d0`) — **pushed to `origin` 2026-09-16 at the owner's request.** `main` untouched, nothing deployed |
| **Commits** | 82 |
| **Tests** | 255 Cloud Functions (Jest, 27 suites, **serial** — see Gotchas) + 75 Dart. **6 Dart failures are pre-existing** in `counter_service_test.dart` — verified identical on base commit `84300d0` |
| **Analyzer** | 0 errors |
| **Register rows addressed** | 43 of 59 |
| **Deployed?** | **NO.** Nothing here has ever run in production. The deploy path itself has never been exercised |

**Risks fixed on this branch:** #2 #3 #4 #5 #6 #7 #8 #11 #12 #13 #14 #15 #16 #18 #19 #20 #22 #23 #24 #25 #27 #29 #30 #32 #34 #38 #39 #40 #41 #43 #45 #46 #47 #48 #50 #51 #52 #54 #58 #59
**Partial, with reasons below:** #9 (no reconciliation job) · #21 (no sync built) · #26 (needs attestation) · #35 (no mail transport exists) · #49 (Artifact Registry migration is an owner action)

**Biggest open question:** none of this protects anyone until it ships. Everything below is verified locally and nothing has ever run in production.

### Start here — #31 is still the next code row

**This session (2026-09-17) did not start on #31.** It closed five other rows
and part of two more, all verified on the iOS simulator and the emulator suite.
#31 remains the next one, for the reason the previous handoff gave: it is
Android release signing and ProGuard, and **the release path runs on the Windows
machine, not this Mac**, so the fix cannot be verified here. Decide with the
owner how to verify before starting. The groundwork below was checked, not
copied from the register.

**What is actually true about #31:**

| Claim | Verified |
|---|---|
| `android/key.properties` is untracked | Yes — and that is **correct**, it holds keystore passwords. `android/.gitignore:11` and `.gitignore:51` both ignore it. Not the bug. |
| No fallback when it is missing | Yes. `android/app/build.gradle:17-20` does `if (keystorePropertiesFile.exists())` and otherwise carries on, so `storeFile` at `:42` becomes `null` and a release build proceeds **without failing**. |
| `proguard-rules.pro` is missing | Yes. `android/app/build.gradle:63` references it, and the file **has never existed in git history** — `git log --all -- android/app/proguard-rules.pro` is empty. It is not gitignored, so it is genuinely absent. |
| `minifyEnabled` is on | Yes, `:61`, with `shrinkResources true` at `:62`. Both added in `59f33e1`, the same commit that referenced the missing ProGuard file. |

**The interesting part, and what to check first:** a release build on the
Windows machine **succeeded** on 2026-08-29 with Billing 8. So the missing
ProGuard file does not fail the build — AGP tolerates it. That means
minification has been running with only `proguard-android-optimize.txt` and no
app-specific keep rules, on a Flutter app using Firebase, `in_app_purchase` and
reflection-heavy libraries. The classic failure mode is a **release-only runtime
crash** that never appears in debug. Worth establishing whether that is
happening before writing rules.

**Suggested shape of the fix** (not prescriptive):
1. Make a release build **fail loudly** when `key.properties` is absent, instead
   of silently producing an unsigned or debug-signed artifact. Debug builds must
   keep working without it.
2. Add `android/app/proguard-rules.pro` with the keep rules Flutter, Firebase
   and Play Billing need, or turn `minifyEnabled` off until rules exist. Turning
   it off is the safer interim if a release crash is already suspected.

**After #31,** the remaining rows are listed under *The rest of the risk
register*. Two are product decisions, not bugs (#33, #37) — ask first.

### What 2026-09-17 closed

| Row | What | Verified by |
|---|---|---|
| #30 | iOS had **no entitlements file at all** and `com.apple.developer.associated-domains` sat in `Info.plist`, where iOS ignores it. Universal links have therefore never worked — the other half of the dead email-verification deep link | `plutil -lint`, `xcodebuild -showBuildSettings` for all three Runner configs, simulator build + launch |
| #15 | `firebase.json` had no `firestore.indexes` key, so indexes have **never been deployed**; the file listed 3 of them. Now enumerates all 18 composite queries in `functions/src` | `firestore-indexes.test.ts` — 19 tests, 15 red before |
| #11 | The counter rule contradicted its own writer: `create: if false` blocked the first-ever increment, and `hasOnly` ran against the **merged** document, so one run of an admin helper bricked every later increment | `counter-rules.test.ts` — 10 tests, 2 red before |
| #27 | Apple's sandbox flag and Google's `testPurchase` were logged and discarded, so test subscriptions were stored as real revenue | `store-environment.test.ts` — 5 tests, all red before |
| #34 | ~1,839 `print`/`debugPrint` calls reach release logs, ~122 carrying a user id, email or report id. Fixed structurally in ~10 lines rather than at 122 call sites | `release_logging_test.dart` — 8 tests |
| #35 | **PARTIAL.** The three notification helpers returned a hardcoded `true`, which callers wrote into `subscriptionLogs.emailSent` — an audit trail claiming mail nobody received. They now return `false`. Actually *sending* mail is still blocked on a provider | `email-honesty.test.ts` — 3 tests, 2 red before |
| #49 | **PARTIAL.** Base images pinned (`flutter:3.41.7`, `nginx:1.27-alpine`); both tags confirmed to resolve before pinning. The gcr.io → Artifact Registry half is an owner action | registry manifest checks |

**Also fixed, not a register row:** the emulator would not start. The #40 work
added `defineInt('SUBSCRIPTION_LOG_RETENTION_DAYS')`, which no env file
supplied, so `firebase emulators:start` hung forever on an interactive prompt —
and so would a real `firebase deploy`. A `default: 0` does **not** suppress the
prompt, the same trap `APPLE_APP_ID` already had. Added to both
`functions/.env.local` and `functions/.env.licenseprepapp` (both untracked).

**Before touching anything, run the bring-up in *How to resume*.** The emulator
starts empty every time: re-seed content AND images, then grant a local trial,
or every screen will look broken and you will debug a phantom.

**Branch:** `local/security-money-hardening` (base `84300d0`, off `chore/play-billing-8-migration`)
**Started:** 2026-09-16
**Last updated:** 2026-09-17 — closed #11 #15 #27 #30 #34, part of #35 and #49; #31 still next
**Goal:** Fix the Critical + High security and revenue risks from `driveusa-risk-register`, verified locally. **Never deploy. Never touch the live Firebase project.**

> If this session is interrupted, read **How to resume** below. Everything needed to pick up is in this file.

---

## Ground rules

1. All work stays on `local/security-money-hardening`. The owner asked for it to be pushed on 2026-09-16, so `origin/local/security-money-hardening` now exists and pushing further commits there is fine. **`main` and `chore/play-billing-8-migration` stay untouched, and nothing here is deployed** — pushing a branch is not shipping. No PR has been opened; that is the owner's call.
2. Emulators run under the real project id **`licenseprepapp`**. The `demo-driveusa` idea was abandoned: `FirebaseOptions` is a matched set, so a fake project id breaks the API key. The safety net instead is that **ADC was revoked** — this machine holds no credential that can reach production Firestore. Do not re-run `gcloud auth application-default login` without a reason.
3. Production is **read-only**, and only for the one-time content export. No writes, no deploys, no rule pushes.
4. Every fix needs a verification that fails before the fix and passes after. No fix is marked DONE on inspection alone.
5. Emulator wiring in the Flutter app is behind `--dart-define=USE_EMULATOR=true`, default off, so a release build can never point at localhost.

---

## How to resume

```bash
cd /Users/demianvyrozub/projects/license-prep-app
git checkout local/security-money-hardening
git log --oneline -10           # what landed last
```

Bring the environment up. **Every functions command needs the Node 22 prefix** —
the machine's default is Node 20 and `functions/package.json` pins 22:

```bash
export PATH="/opt/homebrew/opt/node@22/bin:$PATH"
firebase emulators:start --project licenseprepapp --only firestore,auth,functions,storage,pubsub
```

Seed content into a fresh emulator (data is in-memory and lost on restart):

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-emulator.js
```

Then seed placeholder images, or every theory section and quiz question with a
picture shows "Image unavailable". The content export copies Firestore documents
only; the real picture files are in production Cloud Storage and this machine has
no credential to read them:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-emulator-images.js
```

Run the tests. **After ANY TypeScript change, build first** — the emulator runs
`functions/lib/`, not `functions/src/`, so tests and the emulator will otherwise
disagree silently:

```bash
npm --prefix functions run build && (cd functions && npx jest)
```

Two things about the functions suite that will otherwise waste your time:

- **`npm test` cannot run while the dev emulator is up.** It starts its own
  emulators via `firebase emulators:exec` and dies with *"Could not start
  Authentication Emulator, port taken."* Stop the long-running emulator, run
  `npm test`, then start it again and re-seed. `npx jest <file>` on its own does
  NOT do this — it reuses whatever emulator is already running, which is why it
  is the right choice for iterating on one suite.
- **The emulator only serves the functions it loaded at startup.** Adding a new
  Cloud Function and rebuilding is not enough; it will not appear until the
  emulator restarts. Tests see it immediately because they build and load fresh,
  so a new function can pass its suite while being absent from the running app.

```bash
flutter test
```

Build and run the app (about 6 minutes; `LANG` is required or CocoaPods fails):

```bash
LANG=en_US.UTF-8 flutter build ios --simulator --debug --dart-define=USE_EMULATOR=true
```

```bash
xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch booted com.driveusa.app
```

The simulator can never obtain a trial through signup (`isPhysicalDevice` is
false there, by design). Grant one the way a real device would:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp node scripts/local/grant-local-trial.js <email>
```

It looks the account up in the `users` collection, so sign up in the app first —
after an emulator restart every account is gone and it will report *"No user
with email ..."* until you do.

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
| #5 | No receipt→account binding — one receipt entitles unlimited accounts | ✅ **DONE** | `receipt-binding.test.ts` — 8 tests incl. wiring + renewal positive controls | Guard refuses a receipt bound to another `userId`, before any write |
| #6 | `yearly` receipts dropped client-side (`_activeProductIds` = monthly only) | ✅ **DONE** | `test/in_app_purchase_products_test.dart` — 3 tests (first real Dart coverage) | Yearly removed from what the app **offers**; receipts for it are now **forwarded, not dropped**. Server allow-list keeps yearly on purpose |
| #7 | Home-grown 18h grace period vs Apple 16d / Google 30d | ✅ **DONE** | `grace-period.test.ts` — 6 tests | Grace measured in elapsed time (30 days, `billing-grace.ts`), shared by the scheduler **and** the entitlement gate |
| #8 | Play `PAUSED` / `PAUSE_SCHEDULE_CHANGED` (types 10, 11) not modelled | ✅ **DONE** | `play-notifications.test.ts` — 8 tests | Mapping extracted to a pure, tested function; types named in code, not in a comment |
| #9 | Webhooks always return 200, no dead-letter, no reconciliation | ⚠️ **PARTIAL** | `webhook-dead-letter.test.ts` — 5 tests | Dead-letter queue + bounded failure signalling done. **The daily reconciliation job is NOT done** — see below |
| #19 | Rate limit counts failures — paying user locked out for an hour | ✅ **DONE** | `rate-limit.test.ts` — 6 tests, 5 red → green, incl. fail-open | Separate success (10/h) and failure (30/h) budgets; fails open on infrastructure errors |
| #20 | `subscriptionsType` is a single point of failure for every purchase | ✅ **DONE** | `metadata-resilience.test.ts` — 6 tests, 4 red → green | Built-in defaults for monthly/yearly/trial; Firestore still wins when a row exists. Also stopped the outer catch flattening every `HttpsError` into `internal` |
| #22 | Duplicate `subscriptions` docs after re-subscribe; webhooks update the corpse | ✅ **DONE** | `duplicate-subscriptions.test.ts` — 5 tests incl. the RV-C1 regression guard | Re-subscribe reuses the document matching the receipt identity; both webhooks now fan updates out to every match via `webhook-fanout.ts` |

### High — security / abuse

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #18 | 8 admin-grade functions callable by any authenticated user | ✅ **DONE** | `admin-auth.test.ts` — 12 tests, 4 red → green, with admin positive controls | Four gated by `requireAdmin()`; the other four were the test-data callables already deleted under #4 |
| #12 | `sendEmailVerification()` never called; `emailVerified` gates nothing | ⚠️ **PARTIAL** | `trial-gate.test.ts` — 2 tests + verified live (Auth emulator issued `VERIFY_EMAIL`) | Verification email is sent at signup. **The trial is deliberately NOT gated on it** — owner product decision, see below. So `emailVerified` still gates nothing; the farming exposure remains and needs attestation, not a door gate |
| #26 | Trial gate forgeable (client-supplied `deviceIdHash`), dedupe non-transactional | ⚠️ **PARTIAL** | `trial-gate.test.ts` — 6 tests incl. a real concurrency race | Dedupe is now transactional; `trialDevices` anonymised on account deletion. **The forgeable client input is NOT fixable in code** — see below |
| #29 | `users/{uid}` accepts arbitrary client writes including `isActive` | ✅ **DONE** | `firestore-rules.test.ts` | rules blocklist |

### Resolved by product decision

| Risk | What | Status | Notes |
|---|---|---|---|
| #43 | Year length disagrees: catalogue `duration: 360` vs `upgradeSubscription` `duration: 365` | ⏭️ MOOT | Only the 30-day plan is sold. The mismatch lives entirely in yearly code being removed under #2 and #6 |

### Taken in, out of the original scope

| Risk | What | Status | Why it was pulled in |
|---|---|---|---|
| #58 | New user with no trial saw a silent dead end (`SizedBox.shrink()`) | ✅ **DONE** | Unavoidable once #12 gates the trial: refusing a trial without explaining it would send every unverified signup to a blank screen. The branch now renders a real card, and says *"verify your email"* specifically when that is the reason |
| #32 | `functions/.env.licenseprepapp` tracked in git, no `.env` rule at all | ✅ **DONE** | `git ls-files` | Untracked + blanket `.env` rules. File contains only `APPLE_APP_ID`, not a secret — the risk was the *next* one |
| #39 | Hardcoded `state: 'IL'` when starting exams and practice | ✅ **DONE** | code + app | Topics already honoured the user's state; **questions did not**, so a New York user got Illinois questions |
| #48 | Local subscription cache trusted whenever the Firestore read fails | ✅ **DONE** | code | Server is authoritative when it answers; an **expired** cache is discarded when it does not |
| #54 | Web and mobile point at different Storage buckets | ✅ **DONE** | config | Web was the odd one out — both authoritative Firebase config files say `firebasestorage.app` |
| #59 | App version hardcoded `1.0.0`, tagging every analytics event | ✅ **DONE** | app | Real version from `PackageInfo` in analytics **and** the profile screen |
| #21 | Cross-device progress sync does not exist; failure is invisible; local key unscoped | ⚠️ **PARTIAL** | `progress_storage_test.dart` — 3 tests | Local storage **scoped per user** (was one shared key) + the silence documented. **Sync itself is NOT built** — see below |
| #13 | Privacy policy promises deletion the code cannot deliver (2 of at least 8 locations) | ✅ **DONE** | `account-deletion.test.ts` — 11 tests | All personal locations deleted incl. the `sessions` subcollection; billing records **anonymised**, per the policy's own tax carve-out |
| #14 | Deletion needs no reauth, is not atomic, silently leaves store subscriptions billing | ✅ **DONE** | `account-deletion.test.ts` | Recent-login required (10 min), chunked writes past Firestore's 500 limit, and the user is warned **before** deleting |
| #23 | Orphan-auth trap — a failed signup left an Auth user with no document, unrecoverable in-app | ✅ **DONE** | `user-provisioning.test.ts` — 5 tests | `provisionUserDocument` auth trigger + `set/merge` in both updaters so already-orphaned accounts heal |
| #24 | Interrupted signup meant no entitlement, forever | ✅ **DONE** | server dedupe tests + in-app | `SubscriptionProvider.initialize` retries the trial once when no subscription exists at all |
| #25 | Schedulers capped at 100 documents per run, no cursor, no queue-depth signal | ✅ **DONE** | `sweep.test.ts` (4) + `scheduler-uncapped.test.ts` — 150 expired trials all swept | Cursor pagination + a wall-clock budget; scheduler timeouts raised 60s → 540s |
| #16 | No `predeploy` hook — `firebase deploy --only functions` ships stale compiled JS | ✅ **DONE** | Not optional after all: `functions/lib/index.js` was compiled **Apr 27**, five months stale. The emulator runs `lib/`, so every local verification was against April code until this was found. Added `predeploy` to `firebase.json` and deleted the dead root `index.js` shim |

### Taken in on 2026-09-17

| Risk | What | Status | Verified by | Notes |
|---|---|---|---|---|
| #30 | iOS has no entitlements file and `associated-domains` is misplaced in `Info.plist` | ✅ **DONE** | `plutil -lint`, `xcodebuild -showBuildSettings` × 3 configs, simulator build + launch | The key was inert where it sat, so universal links have **never** worked. Making it real means the App ID must now carry the Associated Domains capability — **owner action, see below**, or a device/archive build will fail to provision where it previously succeeded doing nothing |
| #15 | `firestore.indexes.json` never deployed, and incomplete | ✅ **DONE** | `firestore-indexes.test.ts` — 19 tests, 15 red → green | Enumerated all 18 composite queries in `functions/src`. The three pre-existing entries were **kept, not rewritten**: `firebase deploy` offers to DELETE indexes absent from the file, so removing an entry is how a deploy drops a working production index |
| #11 | The counter rule contradicts its own writer | ✅ **DONE** | `counter-rules.test.ts` — 10 tests, 2 red → green | Two defects: `create: if false` blocked the first-ever increment (a merge-set on a missing document is a create), and `hasOnly` ran against the **merged** document, so one run of `initializeGlobalCounterFromExistingReports` bricked every later increment. Now `diff(resource.data).affectedKeys()` |
| #27 | Sandbox vs production detected but never persisted | ✅ **DONE** | `store-environment.test.ts` — 5 tests, 5 red → green | Unknown stores as `null`, never `production` — a default would recreate the defect. A renewal that does not know omits the key rather than promoting a sandbox subscription into a real one |
| #34 | ~1,839 `print`/`debugPrint` calls reach release logs, ~122 carrying PII | ✅ **DONE** | `release_logging_test.dart` — 8 tests | Fixed structurally in ~10 lines, not at 122 call sites: `debugPrint` is reassigned and the app runs inside a Zone that drops `print`. Wraps all of startup, not just `runApp` |
| #35 | Email mocks return `true`; `emailSent` records mail nobody received | ⚠️ **PARTIAL** | `email-honesty.test.ts` — 3 tests, 2 red → green | The three helpers now return `false`. **Sending mail is still not possible** — same provider blocker as the email-verification work. These tests will fail when a transport is wired in; that is the right moment to revisit them |
| #49 | Unpinned Docker base images; deprecated `gcr.io` | ⚠️ **PARTIAL** | registry manifest checks (both tags return 200) | Pinned `flutter:3.41.7` and `nginx:1.27-alpine`. **Artifact Registry migration deliberately not done** — it needs a repository, IAM for the Cloud Build service account and a trigger update (#36), and repointing the paths without those breaks the web deploy rather than fixing it |

**Out of scope this round** (tracked, not started): #13 #14 privacy/deletion · #21 cross-device sync · #36 CI · #49 Docker · #53 content authoring · #55 #56 store platform (already handled/mitigated) · all remaining Medium rows.

---

## To do next

Agreed but not started. Nothing here is in the current branch.

### 1. Email verification by 6-digit code — SERVER HALF BUILT 2026-09-17

**Provider chosen: Resend** (owner, 2026-09-17), sending from
`driveusaservice@driveusallc.com` on the `driveusallc.com` domain.

**Done** (`52452b6`): the whole server side, with 51 tests.

| Piece | Where |
|---|---|
| Policy — code generation, hashing, expiry, attempt cap, send throttling | `functions/src/email/verification-code.ts` (pure, no Firestore or network) |
| Transport, behind a swappable interface | `functions/src/email/sender.ts` |
| Callables — send, verify, status | `functions/src/email/verification-callables.ts` |
| Templates, five languages | `email-templates.ts` (`VERIFICATION_CODE_TEMPLATES`) |
| Rules | `emailVerificationCodes/{uid}` client-deny both ways |

Limits: 10-minute expiry · 5 wrong guesses then the code is burned · 60s
resend cooldown · 5 sends per hour.

**It works locally without a key.** `createEmailSender` returns a log transport
under the emulator, which prints the code, so the flow is exercisable end to
end today. In production with no key it **throws** rather than pretending — that
is #35's lesson encoded, not merely documented.

**The Flutter half is also done** (`fd6ab4e`), with 14 widget tests.

| Piece | Where |
|---|---|
| Callable wrapper, typed outcomes instead of string matching | `lib/services/email_verification_service.dart` |
| Code screen — six boxes, paste, countdown, per-reason errors | `lib/screens/verification_code_screen.dart` |
| Resume-on-relaunch | `lib/screens/signup_resume_gate.dart` |
| Strings, five locales, added to the coverage guard | `lib/localization/l10n/*.json` |

Flow is now **email+password → code → language → state**.

Two properties not to break:
- `SignupResumeGate` is scoped to `user.state == null`. Gating on
  `emailVerified` alone would send **every existing account** to a verification
  screen, since all of them predate this and have the flag false.
- The gate **fails open**: if the status call cannot be answered the user
  continues to state selection. Verification is a step in signup, not a door in
  front of entitlement.

**Verified end to end on the simulator** on 2026-09-17: signed up, read the code
from the log transport, submitted a wrong code (the server's own attempt counter
came back as "4 attempts left"), then the right one, landing on language
selection. Auth shows `emailVerified=true` for the completed account and `false`
for an abandoned one.

**Still to do:**
- The content prefetch, which fires **after state selection** — state and language are both known only at that point.

**Owner steps outstanding:**
1. Add the four DNS records Resend listed (DKIM TXT, two SPF CNAMEs, DMARC TXT) in Google Cloud DNS, then click *I've already added the records* and wait for Verified.
2. Create a Resend API key with sending access, then `firebase functions:secrets:set RESEND_API_KEY --project licenseprepapp`. **Never paste it into a file** (cf. #1, #32).
3. Free tier is 3,000/month and 100/day — the daily cap is the tighter one, worth checking against expected signup volume.

### 1b. The original plan, for context

Replaces the link flow. A code typed in the app avoids both broken paths: the
hosting rewrite that sends every `/__/auth/action` to `password-reset.html`
(which has no `verifyEmail` handling at all — confirmed), and the misplaced
Associated Domains entitlement that breaks deep links (#30).

**Flow:** email + password → code screen → verified → account finalised **with**
the 3-day trial. The trial still feels instant because verification sits inside
signup rather than gating afterwards. Someone who abandons at the code screen
resumes there on next login, so nobody is stranded with an account and no trial.

**Blocker: there is no way to send email at all.** `nodemailer` is commented out
in `subscription-manager.ts`, and `email-templates.ts` (1,382 lines, five
languages) is imported by nothing — risk #35. The forgot-password mail cannot be
reused: `FirebaseAuth.sendPasswordResetEmail()` asks Google to send it, so none
of that sending is our code, and Firebase's three built-in emails cannot carry
our own code.

| Step | Who |
|---|---|
| Pick a provider (Resend ~3k/mo, Brevo ~300/day, SendGrid ~100/day) | owner |
| Verify the sending domain — SPF/DKIM DNS records. **This decides inbox vs spam** | owner |
| `firebase functions:secrets:set MAIL_API_KEY` — never in a tracked file (cf. #1, #32) | owner |
| Code generation: 6 digits, stored **hashed**, ~10 min expiry, max 5 attempts, resend throttled | me |
| Verify callable; on success set Firebase's real `emailVerified` via the Admin SDK | me |
| Sender behind a small interface so the vendor is swappable | me |
| Code-entry screen: six boxes, paste support, resend countdown, resume-on-relaunch | me |
| Verification-code template added to `email-templates.ts`, reusing its existing structure | me |

**~2–3 days once mail sending exists.** Can start before the provider is chosen:
the sender writes codes to the emulator log locally, so the whole flow is
testable end to end, and production becomes a config change.

**Honest limit:** this raises the cost of multiple accounts from *typing any
string* to *controlling a real inbox*. Throwaway inbox services still work, so it
is strong friction, not a wall. It does cleanly deliver the other two goals — a
confirmed-real address, and a genuine marketing list.

### 2. App Check / device attestation — deferred

Written up in the vault: `wiki/driveusa/Development/infra/app-check-attestation-plan.md`.

### 3. The rest of the risk register

**16 of the 59 rows are still open, and they are all Medium or lower** — the
Criticals and Highs in the agreed scope are done. Remaining: #1 (history
cleanup only; the leaked secret is already rotated and dead), #10, #17, #28,
**#31 (next)**, #33, #35 (the sending half), #36, #37, #42, #44, #49 (the
Artifact Registry half), #53, #55, #56, #57.

Of those, the ones that are **not** blocked on an owner decision, store
sandbox access or the Windows machine are #10 (a wrong config guide — docs
only), #17 (the 6 `counter_service_test.dart` failures, a harness gap),
#28 (`nginx.conf` and Firebase Hosting implement different rules for the same
paths) and #42 (`packageId` written as three different types). Those four are
the natural next batch after #31.

Worth knowing before picking one:
- **#33 and #37 are product decisions, not bugs** — whether to widen past IL/NY,
  and whether to switch single-device enforcement on. Ask the owner first.
- **#50** overlaps something already seen on screen this session: a missing
  translation key renders as the raw key string, because `translate()` returns
  the key rather than null when it misses.
- **#55/#56 are store-deadline work** and need sandbox access, like #9.

**#21 is deliberately partial.** Two of its three problems are closed: progress is no longer stored under one unscoped key (two accounts on one device shared quiz scores, exam results and study progress), and the failure is no longer dressed up as offline tolerance. Legacy unscoped data migrates once to whoever signs in first — a guess, but the same data they can already see, and each account is separate from then on.

**Cross-device sync itself is not built**, and it is a feature, not a fix: five Cloud Functions written from scratch, a Firestore schema and rules for `progress/{uid}` (currently rule-denied), serialisation for `Exam` (which has none), a migration for existing local progress, and a **conflict-resolution decision** — when two devices disagree, which wins? That last one is the owner's call, not a technical one. **Sixteen** mapped callables have no server implementation (the register said ten); they are now listed in a comment at the mapping in `firebase_functions_client.dart` so nobody assumes a name means an endpoint.

**Known gap left by #13/#14:** the client's partial-delete fallback still exists for the case where Cloud Functions is unavailable. It deletes the Auth account and `users/{uid}` but not the other personal data, so a deletion completed that way is incomplete until the callable next succeeds. Closing it properly needs a server-side deletion queue — worth doing alongside the #9 reconciliation job.

## Corrections found in the register

Rows whose stated premise did not survive checking. Recorded so the next reader
does not act on the wrong cause.

- **#50 — the strings were only a third of it.** Six auth screens really did
  have zero `translate()` calls, but translating them alone would have changed
  nothing on screen: `main.dart` passed `forceEnglish: user == null`, and
  `AuthProvider` called `setLanguage('en')` on every logout. Either one alone
  reproduces "a returning Russian user meets an English login screen". Also, the
  "33 keys referenced in code exist in no JSON file" count is stale — measured
  109 distinct keys, of which 2 were missing.

- **#51 — the dead code was not shipping.** The row says debug and example code
  "ships inside release builds" and costs "dead weight in the shipped binary".
  Dart compiles from `main.dart`'s import graph and none of the five files was
  imported, so none reached the binary. Verified against the compiled kernel:
  `FirebaseDebugTestWidget`, `ApiSwitcherExample` and `QuizCacheIntegrationExample`
  appeared 0 times each, against 6 for a reachable widget as a control. The real
  cost was 890 lines in the repo that read as live code. The other half of the
  row — the analytics helper pointing at `com.example.license_prep_app` — was
  entirely real.
- **#40 — the rate-limit query did not degrade with collection size.** It is
  indexed on (userId, timestamp, action). What it lacked was a limit, so cost
  scaled with one user's attempts in the window.
- **#46 — not one orphan per cold start.** Firebase persists the anonymous
  session across launches, so it is one per install, plus one per logout, plus
  one per signup. Still unbounded, by a different route.
- **#21 undercounts.** Sixteen mapped callables have no server implementation,
  not ten.
- **#18 listed eight unguarded callables**; four had already been removed by the
  time the rest were gated.

## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-09-16 | Skip Agent Orchestrator; Claude Code subagents + worktrees instead | ~20 of the fixes touch `functions/src/index.ts`; parallel agents on one file means merge conflicts, and with no tests nobody notices a bad merge |
| 2026-09-16 | Build the test harness before fixing | ~35 of the risks are server-side and invisible in the iOS UI. Without tests they'd ship on trust. Also closes #17 |
| 2026-09-16 | Export production content read-only rather than hand-seeding | Emulator starts blank; app is unusable without content. Seed script deferred to the #53 fix |
| 2026-09-16 | Keep striped placeholder images locally; do NOT pull the real ones | Owner's call. The real files are only in production Cloud Storage and ADC is revoked, so fetching them means briefly restoring production access. None of the remaining register rows are about artwork, and layout/sizing are already testable with placeholders. Pointing Storage at production instead does not work: the rules need `request.auth != null` and the local user's token comes from the Auth emulator, which production rejects. **Do not re-open this without asking** — review artwork on a real device instead |
| 2026-09-16 | Emulators run as `demo-driveusa`, not `licenseprepapp` | `.firebaserc` points at production; a `demo-` project id makes reaching production physically impossible |
| 2026-09-16 | **Only the 30-day monthly plan is sold. Yearly is removed, not fixed** | Owner decision. Production has **zero** yearly subscriptions ever (register, verified 2026-08-20), so nobody is stranded. Turns #2 from a redesign into a deletion, #6 from an implementation into a removal, and makes #43 moot |
| 2026-09-16 | Emulators run under the REAL project id, not `demo-driveusa` | `FirebaseOptions` is a matched set; overriding only `projectId` leaves the real API key, so Firebase Installations calls `projects/demo-*/installations` with a key that does not belong to it. Owner chose to **revoke ADC first** (`gcloud auth application-default revoke`), so the machine now holds no production credentials at all — a stronger position than the `demo-` prefix gave |
| 2026-09-16 | Gate content rules on `users/{uid}.isActive`, and make trials write it | It is the server-maintained entitlement mirror the purchase path, renewal manager and schedulers already use. `createTrialSubscription` was the one path that never wrote it, so gating on it without that fix would have locked out every trial user |
| 2026-09-16 | Blocklist rather than allowlist for `users/{uid}` writes | Several services write profile fields dynamically (`email_sync_service` passes a computed map); an allowlist would break them. The blocklist covers the nine fields that decide entitlement, which is what #29 is actually about |
| 2026-09-16 | #13 anonymises billing records instead of deleting them | `privacy_policy.md` promises "all personal data deleted within 30 days" **and** "Subscription Data: Retained as required for billing and tax purposes" — two promises in tension. Stripping the personal link from `subscriptions` and `subscriptionLogs` honours both: the financial facts survive an audit, the person does not appear in them |
| 2026-09-16 | #14's reauth gate forced a change to the client fallback | The client fell back to a direct partial delete on **any** function failure — removing only `users/{uid}` while reporting success, and bypassing the new recent-login requirement entirely. A deliberate refusal is now rethrown instead of falling through; the fallback survives only for genuine unavailability, and is labelled PARTIAL in the log so it is not mistaken for a complete deletion |
| 2026-09-16 | #23 is fixed in two places on purpose | The auth trigger stops *new* accounts being orphaned, but does nothing for accounts already orphaned in production. `set/merge` in the two updaters heals those the moment the user touches a setting. Neither alone covers both populations |
| 2026-09-16 | #24 recovers the trial in `SubscriptionProvider.initialize`, not at login | It is the one place that already knows whether a subscription exists, and it runs on every session. Safe to retry because the server dedupes — `already-exists` for the user, `failed-precondition` for the device — so it either repairs a genuinely missed trial or is harmlessly refused. Guarded to one attempt per provider instance so a standing refusal is not a callable on every rebuild |
| 2026-09-16 | **REVERSED same day:** the trial is granted instantly, with no email-verification gate | I first built the gate (the owner picked it from options I wrote), then the owner corrected the product intent: **a registered user gets the 3-day trial immediately and is blocked only when it expires; verification is a step in the signup flow, not a gate on the trial.** The gate is removed and there are now tests asserting an unverified user still gets a trial, so a future hardening pass cannot quietly reverse it. Cost accepted: the trial is only as scarce as email addresses, which is #12's farming exposure. The durable answer is device attestation, not blocking new users at the door |
| 2026-09-16 | #58 was still worth doing, and stays | It was pulled in to soften the gate, but it is independently correct: it is the "trial expired — subscribe" state the owner wants, and before it that branch rendered nothing at all |
| 2026-09-16 | #26 anonymises `trialDevices` on account deletion rather than deleting it | The register frames the never-cleaned-up record as unfair to legitimate reinstallers, and deletion is also what risk #13 promises. But **deleting it would make account deletion the easiest possible trial-farming tool** — delete, re-register, collect another trial, repeat. Stripping `firstUserId` / `firstSubscriptionId` and keeping the hash satisfies the deletion promise while the gate keeps working |
| 2026-09-16 | #6 removes yearly from what is OFFERED, but keeps honouring its receipts | The register's wording ("drop from the server allow-list") would have recreated the defect one layer down: a legacy or in-flight yearly purchase would be charged and receive nothing, which is precisely #6's residual risk. Offering and honouring are separate decisions — the app stops selling yearly, the backend keeps accepting it. The locking invariant is a test: never offer a product whose receipt we would discard |
| 2026-09-16 | #9 bounds webhook retries rather than refusing them | The old comments ("Always return 200 — non-200 causes Apple to retry for our own bugs", "Do NOT rethrow") were guarding against retry storms, which is a real concern. Bounding retries by a persisted attempt count on the dead letter gets redelivery for transient failures without letting a permanent bug loop forever. After the budget, the platform is acked and the record is parked for manual replay |
| 2026-09-16 | #7 measures grace in elapsed time, not scheduler passes | Counting passes was the wrong unit: the renewal queries are capped at 100 documents per run (#25), so "3 attempts" meant three pickups, not 18 hours, for anyone behind a backlog. Elapsed time from `nextBillingDate` cannot be distorted by scheduler delay |
| 2026-09-16 | The #3 entitlement gate now shares the same grace window | The gate required `nextBillingDate > now`, which reproduced #7 one layer up: it would lock out a paying customer the moment a renewal ran late, while the store was still retrying. Both now read `isWithinStoreGrace`, so the scheduler and the gate cannot disagree about who is entitled. **Tradeoff:** a stale-active document the scheduler never reaches is now honoured for up to 30 days past expiry instead of 0 |
| 2026-09-16 | #22 keys document reuse on receipt identity, not on relaxing the `isActive` filter | The obvious fix — dropping `isActive == true` from `findExistingSubscription` — would reintroduce **BUG RV-C1**, where a dead trial gets resurrected into a paid plan with stale fields. Matching on `originalTransactionId` / `androidPurchaseToken` instead reuses only documents that genuinely represent the same store subscription. A dead trial carries no receipt identity, so it still falls through and a clean document is created. There is a named regression test for exactly this |
| 2026-09-16 | #20 falls back to built-in defaults rather than failing the purchase | The customer has already been charged by the time `getSubscriptionMetadata` runs. Failing shut costs them a purchase they paid for; falling back costs an operational alarm. Firestore still wins whenever a row exists, and an unknown product id with no default is still refused |
| 2026-09-16 | #19 keeps the Firestore query shape byte-identical | The existing production composite index on `subscriptionLogs (userId, timestamp, action)` serves the current triple-action query. Splitting it in two, or dropping the action filter, would need a *different* index — and `firebase.json` does not deploy indexes (#15), so a query-shape change could break **every** purchase in production. Success/failure partitioning is done in code instead |
| 2026-09-16 | The rate limiter now fails OPEN | It exists to deter abuse, not to be the reason a paid purchase fails. Its call site sits outside `validatePurchaseReceipt`'s try block, so a Firestore error there surfaced as a bare `internal` **after the customer was charged**. Abuse stays bounded by store-side receipt verification and the #5 receipt→account binding. Tradeoff accepted knowingly: during a Firestore outage, validation rate limiting is off |
| 2026-09-16 | #5 fixes the binding; the webhook `.limit(1)` fan-out is deferred to #22 | The register lists `.limit(1)` as a *compounding* factor of #5, not part of its fix. Fanning a webhook update across N documents means restructuring two large handlers that build one update block for one ref — that is exactly what #22 is about. Interim: the limit is removed and duplicates are logged, so the condition is visible instead of silent |
| 2026-09-16 | Superseded the 2026-04-21 "accept receipt sharing as known-issue" decision | Owner asked for #5 directly on 2026-09-16. The earlier reasoning (time-limited, self-healing, zero revenue impact) was about shipping under deadline, not about the defect being acceptable long-term |
| 2026-09-17 | Email verification is a **code**, not a link | A link has to travel through `/__/auth/action`, which `firebase.json` rewrites to `password-reset.html` for every mode — a page with no `verifyEmail` handling at all — and it needs the Associated Domains entitlement that only became real in #30 and is still unverified on a device. A 6-digit code avoids both and was testable the day it was written. It also closes register owner-action 3 by design rather than by fixing the rewrite |
| 2026-09-17 | The mail transport **throws** in production rather than falling back | #35 was not "we picked the wrong mail library", it was "the code claimed to send mail it never sent". A silent fallback to a logging transport would reproduce that exactly, one layer down. Locally the log transport is used and says so (`transport: 'log'`); in production a missing key is a misconfiguration and must be loud |
| 2026-09-17 | nodemailer **removed**, not kept at the upgraded version | Resend is an HTTP API, so no SMTP client has any future role here. Removal clears the same 8 Dependabot alerts as the upgrade did, and also deletes a dependency that shipped in the deployed bundle while being imported by nothing |
| 2026-09-17 | The verification code screen sits **after email+password, before state selection** | Owner-confirmed. It also fixes the original cache-prefetch plan: prefetching "while the user types the code" is impossible, because state and language are not known until the state screen. The prefetch moves to state-confirm instead |
| 2026-09-17 | The functions suite runs serially | Two suites both call `processExpiredSubscriptions`, which is global by nature. Scoping fixtures is not enough when the function under test ignores scope. See Gotchas |
| 2026-09-17 | #15 **adds** index entries and keeps every existing one | `firebase deploy` offers to delete indexes that are in the project but not in the file. Rewriting the file from scratch — even to something more "correct" — is therefore a way to drop working production indexes. Keeping the three original entries means the first deploy can only add. The remaining exposure is indexes production has that nobody here can see, which is why the pre-deploy diff is an owner action rather than something claimed done |
| 2026-09-17 | #27 stores an unknown environment as `null`, never `production` | Defaulting to production would recreate the exact defect the row describes: something we are not certain about still counted as a real sale. For the same reason a renewal that does not know the environment omits the key instead of writing one, so it cannot quietly promote a known sandbox subscription into real revenue |
| 2026-09-17 | #34 is fixed structurally, not at the call sites | The register frames it as ~1,839 `print` calls, which reads as a 1,839-edit change. Rewriting that many call sites is a large diff with real regression risk, and `avoid_print` would then report 1,839 findings that bury real ones. Suppressing both paths in release — `debugPrint` reassigned, `print` dropped by the Zone — is ~10 lines, covers every call site including ones added later, and leaves debug diagnosis untouched. `avoid_print` stays off deliberately |
| 2026-09-17 | #35 makes the mocks return `false` rather than building a mail sender | The row has two halves: an audit trail that lies, and no way to send mail. The first is closed now and is the one that matters for the money-state log — `emailSent: true` for mail nobody received is worse than no record. The second needs a provider, a verified domain and `MAIL_API_KEY`, which are owner steps already specced. Building a half-real sender in between would produce the same false confidence in a new place |
| 2026-09-17 | #30 is done even though it can make a device build start failing | The entitlement was inert where it sat, so universal links have never worked and the email-verification deep link cannot be fixed without this. Making it real surfaces a latent provisioning gap rather than creating one — the App ID either has the capability or it never did. Recorded as an owner action so the failure is expected rather than mysterious |
| 2026-09-16 | Leave the `Pods-Runner.profile.xcconfig` warning alone | Runner's Profile config points at `Flutter/Release.xcconfig`. Debug and Release are correctly wired; only Profile builds (performance profiling, never shipped) are affected. Not a register risk, and editing Xcode build config on a security branch invites unrelated breakage |

## Gotchas

- **Images are missing locally until you seed them.** "Image unavailable" on a theory section or quiz question means the Storage emulator is empty, not that the app is broken — the log line is `Firebase Storage: Unknown error - No object exists at the desired reference`. Run `scripts/local/seed-emulator-images.js` (144 flat-colour placeholders, colour derived from the path so different images stay visibly different). They are obvious placeholders; the real pictures only exist in production.
- **The emulator restarts empty.** No import/export is configured, so stopping the emulators wipes Firestore and Auth. After every restart, re-run `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/local/seed-emulator.js` (6,627 content docs) and sign up again.
- **The simulator can never get a trial through the app.** `createTrialSubscription` refuses with `failed-precondition: Trial unavailable on this device` unless `isPhysicalDevice === true`. That gate is pre-existing (commit `eab687b`) and correct — a real iPhone gets the 3-day trial instantly on signup. Locally, use `scripts/local/grant-local-trial.js <email>`, which writes exactly what a real device would have received. Verified end to end 2026-09-16: trial banner shows "Free Trial Active — Days left: 3" and the Theory tab lists all modules.
- **firebase-tools stubs `firebase-admin` and breaks `admin.firestore.*` statics.** Fixed in commit `6028011` by importing `FieldValue`/`Timestamp` from `firebase-admin/firestore`. If this ever regresses, the symptom is every timestamp-writing callable failing with `internal: INTERNAL` and the emulator logging "Cannot read properties of undefined (reading 'serverTimestamp')" — production is unaffected, so it only ever shows up locally.

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

## Reproduced evidence

### Risk #58, live on the simulator

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

### Risk #3 evidence

**Risk #3, 2026-09-16.** An unauthenticated call to `getQuizQuestions` (no `context.auth` whatsoever) returned:

```
{"id":"q1","correctAnswer":0,"explanation":"A red octagon is always a stop sign.", ...}
```

The answer key and explanation are served to an anonymous stranger. Reproduce with `cd functions && npm test`.

## Follow-ups created by this work

- **The auth translations want a native-speaker review (#50).** The Spanish, Polish, Russian and Ukrainian strings for the 48 new auth keys are mine. They are standard UI phrasing and read naturally, and the Russian login screen was checked on device, but nobody who speaks these languages has read them. Worth one pass before release.
- **~441 inline `_translate` literals remain in 9 screens (#50, deliberately not touched).** `profile_screen`, `state_selection_screen`, `personal_info_screen`, `exam_screen`, `test_screen`, `quiz_question_screen` and three widgets keep per-file translation maps instead of using the JSON files. Nothing renders in the wrong language today — those maps do carry real translations — so this is consistency, not a bug. Moving them is a large refactor whose main risk is introducing the raw-key rendering that `localization_coverage_test.dart` now guards against. Do it only with that test in place.

- **There is still no "my reports" screen (#45 follow-up).** The rules and the query are correct now — a user may read reports carrying their own `userId`, and `getUserReports` is a cheap equality query instead of a denied whole-collection read. But `getCurrentUserReports` has **no callers in `lib/`**, so nothing surfaces reports to the person who filed them. Building that is a feature, deliberately out of scope here. Until it exists, reporting is still one-way from the user's point of view, even though the data layer no longer prevents it.
- **The 6 failing `counter_service_test.dart` tests are a harness gap, not a bug** (diagnosed 2026-09-16). Every one fails with `[core/no-app] No Firebase App '[DEFAULT]' has been created` — `CounterService` builds `FirebaseFirestore.instance` in a field initialiser, and the test never calls `Firebase.initializeApp`. Pre-existing on base `84300d0`. Fixing it means either a mock Firebase in `setUpAll` or injecting the Firestore instance; neither is in any register row.

- **The `anonymous_user_configured` analytics event is now misnamed** (#46 follow-up, `main.dart:491`). It fires on the branch where no local user is loaded — which used to coincide with an anonymous Auth session and now just means "not signed in". Left alone deliberately: renaming an analytics event breaks continuity in whatever dashboards already chart it, which is the owner's call, not a code cleanup.

- **`ContentLoadingManager` still never reloads content, even now that its listener fires (#41 follow-up).** Both callbacks are guarded by `_hasInitializedContent`, which is only set inside `initializeContent()` — and nothing calls that. So a state or language change reaches the manager and it logs "skipping content update". Fixing #41 was the prerequisite (before it, the state listener could not fire at all); making the manager actually do its job needs someone to decide where `initializeContent()` belongs in the startup sequence, or to conclude the manager is redundant now that each screen fetches its own content and remove it. Not decided here.

- **`preloadRelatedContent` would crash on first use — left alone deliberately.** `content_provider.dart:499` does `orElse: () => null as TrafficRuleTopic`, which throws whenever the topic is not already in `_topics`; the `if (topic == null)` below it is unreachable. `flutter analyze` reports both. It is currently harmless because the method has **zero callers** (`grep -rn "preloadRelatedContent" lib test` finds only its own declaration), so it is dead code rather than a live crash. Not fixed during #38 to keep that change surgical. Either fix it with `firstWhereOrNull` and wire up a caller, or delete it — dead code that crashes on first use is worse than no code.

- **#3 follow-up, done 2026-09-16 (commit `15a662f`).** The gate worked but the app never said so: the Theory tab showed *"No theory modules found ... for state 'ILLINOIS' with your current language settings"*, blaming state and language for a paywall, and logged `theory_module_list_empty(reason: state)`. Three layers were swallowing the refusal, and fixing only the inner one did nothing — `firebase_content_api.dart` has an inner catch around the Functions call **and** an outer catch that returns `[]`, so the inner rethrow was caught again one line later. Both now rethrow when `isEntitlementDenial(e)`, across all four content fetchers. `ContentProvider` exposes `contentRequiresSubscription` (cleared on every fetch, so a refusal cannot outlive a purchase) and no longer calls `loadHardcodedTopics()` on a denial — that outage fallback had been serving bundled content to exactly the users the server had just refused, a partial paywall bypass. Theory, traffic-rules and topic-quiz screens render `SubscriptionRequiredView`. Verified on the simulator with an unentitled account.

- **App Check / attestation is planned but deferred** — written up in the vault at `wiki/driveusa/Development/infra/app-check-attestation-plan.md` (linked from the infra index). Covers what it fixes, what it does not, the console/Apple/Play prerequisites, and why enforcement must be staged against a single production project.
- **#26 is partial, and the remaining part is not a code fix.** `deviceIdHash` and `isPhysicalDevice` arrive from the client, so a modified build sends any 64-hex string with `isPhysicalDevice: true` and collects an endless supply of trials. No server-side check can close that: the server cannot tell a real device from a claim about one. It needs **device attestation** — Firebase App Check with DeviceCheck (iOS) and Play Integrity (Android). The register already calls for App Check under risk #3. Until then the device gate is a speed bump, not a control, and `isPhysicalDevice` in particular blocks only honest simulator users — which is why local testing needs `scripts/local/grant-local-trial.js`.
- **The iOS device hash is weaker than it looks.** Memory from an earlier session: the Keychain UUID it derives from is wiped on uninstall, so delete-and-reinstall already yields a fresh hash and therefore a fresh trial — without any client modification at all. Attestation would not fix this either; it needs a server-side identifier that survives reinstall, or accepting that trials are per-install.

- **#9 is only half done, deliberately.** The register's action for it is two things: a failure path (done) and *"a daily reconciliation job that re-reads store state for any subscription whose nextBillingDate has passed"* (not done). Reconciliation genuinely needs live Apple/Google API calls — it cannot be written or verified against the emulator, and a half-built version that silently reconciles nothing would be worse than none. It also needs the `admins`/credentials story settled. **Recommend doing it as its own piece of work with store sandbox access.** What exists now means a failed webhook is retried and, if it still fails, recorded rather than lost — which is the part that stops silent data loss.

- **Play type 9 (DEFERRED) and 20 (PENDING_PURCHASE_CANCELED) are still unmodelled.** Both are now *named* in `play-notifications.ts` and fall through to the `handled: false` branch, which logs a warning instead of passing silently. Out of #8's scope (the register names only 10 and 11). DEFERRED matters slightly: it pushes the billing date out, so `nextBillingDate` goes stale and the renewal scheduler reads the subscriber as `past_due` — harmless now that grace is 30 days (#7), but worth modelling if deferrals are ever used.

- **Gap in the #5 work, found during #20 and fixed there.** `validatePurchaseReceipt`'s outer catch flattened every error into `internal`, including the `permission-denied` the receipt-binding guard raises. The #5 tests passed because they call `createOrUpdateSubscription` directly. The catch now rethrows `HttpsError` unchanged. **End-to-end verification of that specific path is still missing** — reaching it needs a live Apple/Google response, so it is verified by the direct-call test plus inspection, not by an end-to-end test.

- `lib/models/user_subscription.dart:isUpgradeEligible` is dead code — and was already dead at the base commit `84300d0` (zero callers), so it is **not** an orphan this work created. Natural cleanup during #6, when yearly leaves the codebase.
- `lib/docs/server_side_subscription_management_implementation.md:672` documents the now-deleted test-data generation system. Stale; left alone deliberately (documentation drift, not a security fix).
- `docs/webhook.md` asks twice for `handleMockPaymentWebhook` to be removed before production. Now done — that document can drop the warning.
- Register Top-7 #2 suggests counting `subscriptionLogs` where `processedBy == 'scheduled_function'` to see how much audit trail `cleanupSubscriptionTestData` already destroyed. **Not done** — it needs a production read, and this machine deliberately has no production credentials now. Owner call.

### More gotchas

- `pod install` needs `export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`, otherwise CocoaPods 1.16.2 on Ruby 3.4 dies with `Encoding::CompatibilityError`. It exits non-zero but a piped `tail` will mask it — always check `Podfile.lock`'s date.
- Xcode warns that `Runner` has a custom base configuration so CocoaPods did not set `Pods-Runner.profile.xcconfig`. Pre-existing, affects Profile builds only. Not touched.
- `functions/package.json` pins Node 22; the machine's default is Node 20. Every functions command needs the PATH prefix.
- **The functions suite runs SERIALLY (`maxWorkers: 1`), on purpose.** All 27 suites share one Firestore and Auth emulator, and several call functions that are global by nature — `processExpiredSubscriptions` sweeps every expired trial in the collection, whoever created it. Two suites calling that at once cannot be scoped apart: one deactivates the other's fixtures. That failed roughly one run in three before it was pinned. Do not "speed the suite up" by restoring parallel workers without solving that first; it costs ~100s against ~60s, which is the right trade for a suite that is emulator-IO bound anyway.
- **Tests must scope their queries to their own data.** `scheduler-uncapped` used to assert on the whole `subscriptions` collection and delete every trial in it during setup. Global assertions against a shared emulator are fragile by construction — prefer asserting on documents the suite created itself.
- **A `defineInt` with `default: 0` still prompts.** Both `APPLE_APP_ID` and `SUBSCRIPTION_LOG_RETENTION_DAYS` declare a default of `0`, and the Firebase CLI asks for them anyway — `firebase emulators:start` hangs forever on `? Enter an integer value for ...`, and a real `firebase deploy` would do the same. Both are now supplied in `functions/.env.local` (emulator) and `functions/.env.licenseprepapp` (deploy); **both files are untracked**, so a fresh clone hits this again. If a future param is added with a falsy default, add it to both files in the same commit.
- The functions emulator prompts for `APPLE_APP_ID` and hangs forever if unanswered. `functions/.env.local` supplies it. **Note:** the code declares `defineInt('APPLE_APP_ID', { default: 0 })` — so if it is unset in *production*, Apple notification verification runs against app id `0`. That is the unverified item in the register's Top-7 #5, and the default confirms the failure mode is real.
- Since ADC now exists, the functions emulator warns that **non-emulated** Google APIs will hit production with those credentials. Emulated services (Firestore/Auth/Storage/Functions) are unaffected. Run `gcloud auth application-default revoke` once the content export is no longer needed.
- Test fixtures use the synthetic `state: 'ZZ' / language: 'zz'` so they cannot collide with the 6,627 seeded production documents.
- **The functions emulator runs `functions/lib/`, not `functions/src/`.** After any TypeScript change run `npm --prefix functions run build`, or the emulator keeps serving stale compiled JS. `npx jest` uses ts-jest on the source, so tests can pass while the emulator still runs old code — they disagreed for most of this session's first hours.
- When the long-running emulator is already up, run `npx jest` directly. `npm test` wraps `emulators:exec`, which will fail on the already-bound ports.

## TODO — work that needs another machine, or a decision

> **The Android half of this list now lives in the vault**, at
> `wiki/driveusa/Development/infra/android-verification-checklist.md`, because
> the vault is what syncs to the Windows PC — a checklist buried on a branch
> would not be readable from the machine that has to run it. It covers the
> missing Gradle verification, #31 signing and ProGuard, the #34 release-logging
> change, `minSdkVersion`, and the post-deploy purchase checks. Keep it there,
> not here.



Deferred deliberately (owner's call, 2026-09-17): these cannot be verified on
this Mac, and are not worth chasing before a real device is in hand. Each row
gives the symptom to watch for and the fix, so nobody has to re-derive it.

### 1. iOS Associated Domains entitlement (#30)

**When:** the first build onto a real iPhone, or the first archive for
TestFlight. Simulator builds are unaffected and will keep working.

**Likely outcome: nothing happens.** The Runner target uses automatic signing,
and Xcode usually adds a missing capability to the App ID by itself.

**Symptom if it does go wrong:** the build fails at the signing step, with
wording like *"Provisioning profile ... doesn't support the Associated Domains
capability"* or *"doesn't include the com.apple.developer.associated-domains
entitlement"*.

**Fix, about two minutes:**
1. [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) → Identifiers → `com.driveusa.app`
2. Tick **Associated Domains**, Save
3. Xcode → Settings → Accounts → **Download Manual Profiles**
4. Build again

**Escape hatch:** if it blocks a release and there is no time, delete the
`CODE_SIGN_ENTITLEMENTS` line from the three Runner configurations in
`ios/Runner.xcodeproj/project.pbxproj`. That restores the previous behaviour —
the app builds, and universal links stay broken, which is where they were
before this branch anyway.

**While the device is out:** universal links also need an
`apple-app-site-association` file served from `licenseprepapp.web.app` and
`licenseprepapp.firebaseapp.com`. Without it the entitlement is necessary but
not sufficient. Test by tapping a verification link in Mail: it should open the
app, not Safari. This and the `/__/auth/action` rewrite (owner action below) are
the two halves of the dead email-verification link — check them together.

### 3. Dependency advisories — nodemailer done, the Firebase tree is not

**nodemailer: REMOVED 2026-09-17** (`c857083`, superseding the earlier upgrade in
`61e8f22`). Resend is an HTTP API, so no SMTP client is needed at all. This
clears 8 of the 9 Dependabot alerts including both highs. Zero behavioural
risk — nothing imports it. Upgraded rather than removed so the #35 decision
stays open; removal is probably right once a provider is picked, since Resend,
Brevo and SendGrid are all HTTP APIs needing no SMTP client.

**The alerts will not drop on GitHub until this branch merges**, because
Dependabot raises them against the default branch.

**What remains, and it is bigger than the Dependabot count suggested.**
`npm audit --omit=dev` — production dependencies only, which is what actually
deploys — reports **25 advisories (4 critical, 8 high)**. Dependabot showed 9;
the two tools measure different things, so do not read the smaller number as the
whole picture.

All four criticals trace to one chain:

```
firebase-admin@12.7.0 → @firebase/database-compat → @firebase/database
  → faye-websocket@0.11.4 → websocket-driver@0.7.4   (critical)
```

That is the Realtime Database client, which this project does not use — it
arrives with `firebase-admin` regardless. Current versions:

| Package | Current | Latest |
|---|---|---|
| `firebase-admin` | 12.7.0 | **14.4.0** (two majors behind) |
| `firebase-functions` | 7.0.6 | 7.4.0 (minor) |
| `googleapis` | 169.0.0 | 181.0.0 |
| `axios` | 1.13.2 | 1.20.0 |

**Do not run `npm audit fix --force`.** It would move `firebase-admin` across
two majors on the functions that handle every payment, unattended. The sane
order is `firebase-functions` 7.0.6 → 7.4.0 first (a minor, and the emulator
already warns about it), then `axios`, then `firebase-admin` as its own piece of
work with the full suite run after. Treat it as a tracked task, not a quick fix.

### 3b. The original finding, for context

Checked 2026-09-17. All nine open alerts are in `functions/`, and **eight of
them — including both "high" ones — are `nodemailer`**, pinned at `^7.0.6`
against a fix in `9.1.1`.

The useful part: **nothing imports nodemailer.** The import at
`subscription-manager.ts:5` is commented out, the `createEmailTransporter`
helper that would have used it is inside a comment block, and the remaining
matches are prose. It is a direct dependency shipped in the functions bundle
that no code path can reach — the same dead weight risk #35 describes, now also
carrying the repo's only high-severity alerts.

Two ways to close it, and the choice belongs with #35:

- **Upgrade** `nodemailer` and `@types/nodemailer` to `^9.1.1`. One line, zero
  behavioural risk because nothing imports it. Clears 8 alerts.
- **Remove both packages.** Also clears 8 alerts and deletes the dead weight.
  Worth preferring *if* #35 lands on Resend, Brevo or SendGrid, because those
  are HTTP APIs and need no SMTP client at all. Nodemailer is only worth keeping
  if the decision is to send over raw SMTP.

The ninth alert is `qs` (medium, `>= 2.2.5 < 6.16.0`), which is **transitive**,
not declared in `functions/package.json`. It most likely arrives via
`firebase-functions` — which the emulator already warns is outdated — so
updating that dependency is the thing to try before reaching for an `overrides`
entry.

None of this is a register row and none of it is urgent: the vulnerable code is
unreachable. But it is cheap, and it is the whole of the repo's alert list.

### 4. Gradle build to verify the dead-buildscript removal

`chore/remove-dead-buildscript` was merged into `main` on 2026-09-17 at the
owner's request (`004d043`). Its own commit message asks for a Gradle build
before merging, and **that has still not happened** — neither the authoring
machine nor this Mac has an Android SDK.

The static reasoning is sound and the evidence is good: the Windows release
build of `84300d0` stamped `androidGradlePluginVersion=8.13.0`, the version from
`settings.gradle:21`, proving the removed block's `8.4.0` classpath was ignored.
The failure mode is also contained — if that block were load-bearing, Gradle
fails loudly at build time rather than shipping anything broken.

**Fold this into the same Windows session as #31**, which needs that machine
anyway: run a release build, confirm it succeeds, and confirm the bundle still
reports AGP 8.13.0. If it fails, `git revert 004d043` restores the block.

Note that `main` is no longer byte-identical to the commit that produced the
live 1.0.5 build — `84300d0` is, and `004d043` adds this one unverified change
on top.

### 2. Practice tests, and the renewal scheduler (found 2026-09-17 via #15)

The index diff showed production was missing two indexes its own code needs.
Both were deployed on 2026-09-17, so both should now work — but neither has
been exercised against production, so confirm rather than assume:

- **Practice tests.** Production held **no** `practiceTests` index at all, while
  `getPracticeTests` filters on three fields and orders by a fourth. That query
  cannot have been served. On device, open the practice-test list and confirm it
  populates.
- **Renewals.** Production held `subscriptions (trialUsed, status, nextBillingDate)`
  — the query shape from *before* the SM-MOD-2 fix added the `isActive` filter.
  The index never followed the code, so `renewActiveSubscriptions` was likely
  failing. Check the Cloud Functions logs for that scheduler after the next run
  and confirm it no longer reports a FAILED_PRECONDITION / missing-index error.

## Owner action required outside the repo

- **Enable the Associated Domains capability for `com.driveusa.app`** — **deferred to the real-device test run at the owner's request (2026-09-17); see the TODO section above for the symptom and the fix.** (from #30). The entitlement was previously in `Info.plist`, where iOS ignores it, so it has never been exercised. Now that it is in a real `Runner.entitlements`, a device or archive build **will fail to provision** unless the App ID carries the capability in the Apple Developer portal. Simulator builds are unaffected, which is why this is not visible from this machine. Universal links also need `apple-app-site-association` served from `licenseprepapp.web.app` and `licenseprepapp.firebaseapp.com` — worth checking at the same time as the `/__/auth/action` rewrite problem below, since the two together are why the email-verification deep link is dead.

- ~~Diff the deployed indexes before the first deploy after #15~~ — **done 2026-09-17, and it mattered.** The owner ran `firebase firestore:indexes --project licenseprepapp`: **8 of production's 11 indexes were absent** from the file derived from the query code, so a `--force` deploy would have offered to delete all eight. Worst of them, this file's own claim was wrong — the receipt rate-limit index is `subscriptionLogs (action, userId, timestamp)`, not `(userId, timestamp, action)`. The two entries that predated this branch were stale too: production holds neither of them. `firestore.indexes.json` is now production's 11 verbatim plus three genuine gaps, and **`firestore:indexes` was deployed to production on 2026-09-17** — 0 deletions, 3 additions, verified by re-reading the index list afterwards. Rules were **not** deployed; the CLI only compile-checks them under `--only firestore:indexes`.

  **Standing rule from here on:** never run `firebase deploy --force` on this project. Re-run the diff whenever a query's filters change, and add the production index to both `firestore.indexes.json` and the `IN_PRODUCTION` list in `firestore-indexes.test.ts` in the same commit.

- **Migrate the web image from `gcr.io` to Artifact Registry** (the open half of #49, 2026-09-17). Google has deprecated Container Registry. This needs an Artifact Registry repository, `roles/artifactregistry.writer` for the Cloud Build service account, and an update to the Cloud Build trigger — whose definition is not in version control (#36). `cloudbuild.yaml` was deliberately left pointing at `gcr.io`, because repointing it before the repository exists breaks the web deploy instead of fixing it.

- **Split sandbox out of the revenue figures** (follow-up to #27, 2026-09-17). Subscriptions and `subscriptionLogs` now carry an `environment` field, but `getSubscriptionStats` does not filter on it, and every document written before this change has no field at all — which reads as unknown, not as production. Deciding how to treat those historical rows is an owner call; the honest options are to leave them unknown, or to backfill from the store reports.


- **Delete the anonymous Auth users already in production** (from #46, 2026-09-16). The app no longer creates them, but every one made before this change is still there, inflating the Auth user count and its billing. They are identifiable in the Firebase console by having no provider and no email, and none of them has a `users/{uid}` document. Deleting them needs Admin SDK access against production, which this machine deliberately does not have. Safe to remove: an anonymous account that was never linked cannot be signed back into, and nothing in Firestore references it.

- **`subscriptionLogs` retention: no action needed — leave `SUBSCRIPTION_LOG_RETENTION_DAYS` at 0** (from #40, revisited 2026-09-16). The switch exists if it is ever wanted, but checking the actual constraints says not to use it:
  - `privacy_policy.md:107` promises subscription data is *"retained as required for billing and tax purposes"* — open-ended, so keeping it breaks no commitment.
  - `privacy_policy.md:108` promises personal data is gone within 30 days of account deletion, and #14 satisfies that by **anonymising** these rows (userId replaced), not deleting them. So a deleted user's rows are no longer personal data and retention does not conflict with the promise.
  - Cost is negligible: roughly 3 rows per active subscriber per month at ~1.5 KB all-in including index entries. At 10,000 subscribers that is ~45 MB/month, about ten cents a month of Firestore storage after a full year.
  - The query-performance half of #40 is already fixed by the scan cap, and does not depend on collection size.

  If a number is ever needed for a policy document, **24 months** is the usual range for billing audit logs. Note that the 7-year figure people reach for applies to financial and tax records — Apple and Google are the merchant of record here, so the authoritative tax records are the store payout reports, not these rows. Worth confirming with whoever handles compliance before publishing a number. Setting it is one config value and the sweep already handles it.

- **Bump the content version after editing content** (from #47, 2026-09-16). `getContentVersion` reads `contentMeta/current.version`; changing it makes every device drop cached content on next launch instead of waiting out a 24 h TTL. Without a bump, a content correction still takes up to 24 h to reach people — the mechanism exists now, but somebody has to pull the lever. `scripts/local/bump-content-version.js` does it against the emulator and is the model for production; there is no admin UI (risk #53). In production the document can also be edited by hand in the Firebase console: set `version` to any different integer.

- **Decide what happens to `scripts/deletion-manifest.json`** (raised 2026-09-16 during #52). It is the plan from a real destructive run against production — 452 users and 208 subscriptions deleted on 2026-04-18 — and it lists real Firebase Auth UIDs for the 7 accounts that were kept. It is untracked and gitignored, so it cannot reach git; the only remaining question is whether that record should stay on a dev machine at all. **Not deleted, because it is not reversible and it may be the only record of who was preserved.** The companion `deletion-log-20260418-122749.txt` holds counts only, no UIDs, and is harmless.

- ~~Four translation keys rendered as raw keys on screen~~ — **done, and the sweep is done too (#50).** `AppLocalizations.translate()` returns the KEY when a string is missing, never null, so a `?? 'fallback'` in calling code is dead and the user sees `no_subscription_title`. The register's count of 33 such keys was stale: a measured sweep found 109 distinct `translate()` keys in `lib/`, of which 2 were missing everywhere. All five locale files now carry identical key sets, and `test/localization_coverage_test.dart` fails the build if that ever drifts again. **No owner action.**
- **Check the email-verification deep link works in production.** `firebase.json` rewrites *every* `/__/auth/action` to `password-reset.html`, but verification links arrive as `/__/auth/action?mode=verifyEmail`. The app routes an `oobCode` to `EmailVerificationScreen` (`main.dart`), and that flow was dead code until now, so it has never been exercised with a real link. Worth testing end to end before this reaches users, or verification emails will land on the password-reset page.
- **`webhookDeadLetter` is a new collection holding raw Apple/Google payloads.** It is client-deny by rule, but it is store data about real users and has **no retention policy**. Fold it into the deletion and TTL work of risks #13 and #40, and check it periodically for `status: 'exhausted'` records, which are failures nobody has replayed.

- **Check production for receipts already shared across accounts.** The binding guard stops new sharing, but says nothing about rows created before it. Query `subscriptions` grouped by `originalTransactionId` / `androidPurchaseToken` and look for any value held by more than one `userId`. The webhooks now log `🚨 ... subscriptions share ...` if it happens live. Needs a production read, which this machine no longer has credentials for.

- **Provision an `admins/{uid}` document** (register risk #45). The collection is empty, so `processSubscriptionsManualy`, `getSubscriptionStats`, `subscriptionSystemHealth` and `getRenewalStats` are now callable by nobody — deliberate, but it means those stats endpoints stay closed until an admin exists. It also unblocks **admin triage** of filed `reports`. Note #45 changed half of this: a user can now read back reports carrying their own `userId`, so reporting is no longer write-only at the data layer — but nothing reads other people's reports without an admin document, and no screen surfaces reports to users yet either. Create it in the console; the collection is client-deny by rule.

- **Deactivate the yearly SKU in App Store Connect and Google Play Console.** Removing it from the code stops the app offering it, but if the SKU stays purchasable in either store a user could still buy it through a store-side resubscribe flow and receive nothing. Code alone does not close this.
- `subscriptionsType/2` (the yearly catalogue row) is left in production untouched — harmless once nothing references yearly, and deleting it would be a production write.
