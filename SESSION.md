# Local Hardening Session — security & money path

**Branch:** `local/security-money-hardening` (base `84300d0`, off `chore/play-billing-8-migration`)
**Started:** 2026-09-16
**Last updated:** 2026-09-16
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
| E3 | Node 22 installed | ⬜ TODO | **Blocker.** Machine has only Node 20.19.5; `functions/package.json` wants 22. Plan: `brew install node@22` (keg-only, does not change global node) |
| E4 | `emulators` block in `firebase.json` | ⬜ TODO | auth, functions, firestore, storage, ui |
| E5 | Local secrets for emulator | ⬜ TODO | `functions/.secret.local` with dummy `APPLE_SHARED_SECRET` / `GOOGLE_CREDENTIALS` |
| E6 | Content exported from production | ⬜ TODO | read-only via Admin SDK + `functions/service-account.json` → `.emulator-data/` |
| E7 | Flutter emulator wiring | ⬜ TODO | `USE_EMULATOR` dart-define in `lib/main.dart` |
| E8 | iOS pods reinstalled | ⬜ TODO | `Podfile.lock` is from Apr 27, predates Billing 8 |
| E9 | App runs on simulator against emulators | ⬜ TODO | acceptance gate for setup phase |

## Test harness (risk #17 — prerequisite, not optional)

| # | Step | Status | Notes |
|---|---|---|---|
| T1 | Jest + ts-jest in `functions/` | ⬜ TODO | unit tests for Cloud Functions |
| T2 | `@firebase/rules-unit-testing` suite | ⬜ TODO | proves `firestore.rules` actually denies what we think |
| T3 | StoreKit configuration file | ⬜ TODO | local fake store — lets the simulator do purchase / restore / renewal / trial→paid |
| T4 | One red test per in-scope risk | ⬜ TODO | written before its fix |

---

## Fix queue — security & money

Status: ⬜ not started · 🔄 in progress · ✅ done & verified · ⏸️ blocked · ⏭️ deferred

### Critical

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #3 | Paid content corpus served with no auth — 7 callables have no `context.auth`; rules gate only on `auth != null` while `main.dart` signs everyone in anonymously | ⬜ | rules test + callable test | |
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
| #29 | `users/{uid}` accepts arbitrary client writes including `isActive` | ⬜ | rules test | |

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
