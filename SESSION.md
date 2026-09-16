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
| E9 | App runs on simulator against emulators | ⬜ TODO | acceptance gate for setup phase |

## Test harness (risk #17 — prerequisite, not optional)

| # | Step | Status | Notes |
|---|---|---|---|
| T1 | Jest + ts-jest in `functions/` | ✅ DONE | `npm test` wraps `firebase emulators:exec --project demo-driveusa`. Emulators spin up, tests run, teardown is automatic |
| T2 | `@firebase/rules-unit-testing` suite | ✅ DONE | `firestore-rules.test.ts` — risks #3, #29. Own project id `demo-rules-test`, never touches seeded data |
| T3 | StoreKit configuration file | ⬜ TODO | local fake store for simulator purchase / restore / renewal / trial→paid |
| T4 | One red test per in-scope risk | 🔄 IN PROGRESS | #3 and #29 done. **13 tests: 9 red, 4 green controls** |

---

## Fix queue — security & money

Status: ⬜ not started · 🔄 in progress · ✅ done & verified · ⏸️ blocked · ⏭️ deferred

### Critical

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #3 | Paid content corpus served with no auth — 7 callables have no `context.auth`; rules gate only on `auth != null` while `main.dart` signs everyone in anonymously | 🔄 red tests written | `content-auth.test.ts` — 4 red, 1 positive control | |
| #4 | `handleMockPaymentWebhook` (unauthenticated POST) and test-data callables deployed to production | ⬜ | function test | |

### High — money path

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #2 | `upgradeSubscription` grants 365 days yearly, free, no audit row | ⬜ | function test | |
| #5 | No receipt→account binding — one receipt entitles unlimited accounts | ⬜ | function test | |
| #6 | `yearly` receipts dropped client-side (`_activeProductIds` = monthly only) | ⬜ | dart test + StoreKit | |
| #7 | Home-grown 18h grace period vs Apple 16d / Google 30d | ⬜ | function test | |
| #8 | Play `PAUSED` / `PAUSE_SCHEDULE_CHANGED` (types 10, 11) not modelled | ⬜ | function test | |
| #9 | Webhooks always return 200, no dead-letter, no reconciliation | ⬜ | function test | |
| #19 | Rate limit counts failures — paying user locked out for an hour | ⬜ | function test | |
| #20 | `subscriptionsType` is a single point of failure for every purchase | ⬜ | function test | |
| #22 | Duplicate `subscriptions` docs after re-subscribe; webhooks update the corpse | ⬜ | function test | |

### High — security / abuse

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #18 | 8 admin-grade functions callable by any authenticated user | ⬜ | function test | |
| #12 | `sendEmailVerification()` never called; `emailVerified` gates nothing | ⬜ | function test + iOS | |
| #26 | Trial gate forgeable (client-supplied `deviceIdHash`), dedupe non-transactional | ⬜ | function test | |
| #29 | `users/{uid}` accepts arbitrary client writes including `isActive` | 🔄 red tests written | `firestore-rules.test.ts` | |

**Out of scope this round** (tracked, not started): #13 #14 privacy/deletion · #21 cross-device sync · #36 CI · #49 Docker · #53 content authoring · #55 #56 store platform (already handled/mitigated) · all remaining Medium rows.

---

## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-09-16 | Skip Agent Orchestrator; Claude Code subagents + worktrees instead | ~20 of the fixes touch `functions/src/index.ts`; parallel agents on one file means merge conflicts, and with no tests nobody notices a bad merge |
| 2026-09-16 | Build the test harness before fixing | ~35 of the risks are server-side and invisible in the iOS UI. Without tests they'd ship on trust. Also closes #17 |
| 2026-09-16 | Export production content read-only rather than hand-seeding | Emulator starts blank; app is unusable without content. Seed script deferred to the #53 fix |
| 2026-09-16 | Emulators run as `demo-driveusa`, not `licenseprepapp` | `.firebaserc` points at production; a `demo-` project id makes reaching production physically impossible |

## Gotchas

- `.firebaserc` pins `licenseprepapp` (production). Always pass `--project demo-driveusa` to emulator commands.
- `functions/service-account.json` exists locally and is untracked. It has production write access — only ever use it for the read-only export.
- `functions/.env.licenseprepapp` is still **tracked in git** (risk #32). `.gitignore` lists it but gitignore does not untrack. Needs `git rm --cached` — separate cleanup, not part of this branch.
- Do not run `initializeGlobalCounterFromExistingReports` or `resetGlobalCounter` against anything (register Top-7 item 5).

## Reproduced evidence

**Risk #3, 2026-09-16.** An unauthenticated call to `getQuizQuestions` (no `context.auth` whatsoever) returned:

```
{"id":"q1","correctAnswer":0,"explanation":"A red octagon is always a stop sign.", ...}
```

The answer key and explanation are served to an anonymous stranger. Reproduce with `cd functions && npm test`.

## Gotchas found during setup

- `pod install` needs `export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`, otherwise CocoaPods 1.16.2 on Ruby 3.4 dies with `Encoding::CompatibilityError`. It exits non-zero but a piped `tail` will mask it — always check `Podfile.lock`'s date.
- Xcode warns that `Runner` has a custom base configuration so CocoaPods did not set `Pods-Runner.profile.xcconfig`. Pre-existing, affects Profile builds only. Not touched.
- `functions/package.json` pins Node 22; the machine's default is Node 20. Every functions command needs the PATH prefix.
- The functions emulator prompts for `APPLE_APP_ID` and hangs forever if unanswered. `functions/.env.local` supplies it. **Note:** the code declares `defineInt('APPLE_APP_ID', { default: 0 })` — so if it is unset in *production*, Apple notification verification runs against app id `0`. That is the unverified item in the register's Top-7 #5, and the default confirms the failure mode is real.
- Since ADC now exists, the functions emulator warns that **non-emulated** Google APIs will hit production with those credentials. Emulated services (Firestore/Auth/Storage/Functions) are unaffected. Run `gcloud auth application-default revoke` once the content export is no longer needed.
- Test fixtures use the synthetic `state: 'ZZ' / language: 'zz'` so they cannot collide with the 6,627 seeded production documents.
- When the long-running emulator is already up, run `npx jest` directly. `npm test` wraps `emulators:exec`, which will fail on the already-bound ports.
