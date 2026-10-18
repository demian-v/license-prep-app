# Next session: P9 Stripe Connect

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`.

---

Resume the DriveUSA Instructors feature: **P8 Reviews is complete**, start
**P9 Stripe Connect** (real money, test mode only).

## Read first

1. `~/.claude/CLAUDE.md`. State a 1–3 step plan and name the guidelines that
   apply before writing anything.
2. The vault TODO `raw/drive_usa/2026-09-30-Instructors TODO.md`: "State",
   "How to resume", "Decisions", the P7 and P8 sections, then "Later phases".
3. Plan v2 `raw/drive_usa/2026-09-30-Instructors Plan v2.md`: **§9.1** (fees,
   and "verify Stripe's pricing page before P9"), **§9.2** (separate charges
   + transfers, payouts setup), **§9.3** (state machine, the late-paid
   expired booking, webhooks + dedupe), §9.4 (deletion blockers that arrive
   with P9), §9.5 (what P7 built), §12 (refund / payouts pushes), §14.2
   (Профиль payouts card, Календарь «Прошедшие и доход»), §14.3 (the
   `booking_refunded` event), §17 (close the Express account after the last
   payout), §18a (admin tool: web dashboard, hide not delete — P10) and the
   §15 P9 row ("check the store policy first").
4. Load the `driveusa` skill; read the **risk register** before touching
   rules, secrets or money (the defineInt-reads-0 entry, the P7 "no cap on
   holds" residual, #1/#32 on leaked secrets), and
   `wiki/driveusa/Development/design system/design-patterns.md` (Bookings
   and Reviews sections) before UI.
5. Use Context7 for the current `stripe` (Node) and `flutter_stripe` docs —
   don't write Stripe calls from memory.

## State (2026-10-07)

- Branch `instructors`, last commit **`9fd07fd`** (P8). Run `git status`
  first; the untracked `.agents/`, `skills-lock.json` and
  `design/memes/own/*` folders are never committed.
- Tests: Flutter 371, functions 703 (47 suites), all passing; analyzer
  baseline 1531 lines (diff against `HEAD` in a scratchpad worktree — no new
  lines).
- Nothing deployed. Never deploy from this branch. **The repo is public:**
  no key, secret or account id in any committed file, log line or test.

## P9 Stripe Connect (plan §9, §15)

First check the store policy and give me the owner setup list, then a short
P9 plan (gateway, PaymentSheet, webhook, payouts onboarding, release,
refunds, holds cap, deletion, seed, tests, and everything below marked
**decide**), then build. Facts already checked:

- **The seam exists (P7):** `PaymentGateway` (`functions/src/bookings.ts:114`)
  with `begin(bookingId)`; the emulator gateway confirms at once (`:119`);
  `paymentGateway()` (`:127`) returns null outside the emulator, so
  `createBooking` (`:218`) refuses `payments-unavailable` **before** locking
  anything. P9 puts Stripe behind it: after the slot transaction, create a
  PaymentIntent on the platform account (`transfer_group = bookingId`,
  `metadata.bookingId`) and return the `client_secret`.
  `confirmBooking(bookingId)` (`:297`) is already the helper the webhook
  calls (returns false when not pending). The expiry sweep has a
  `// P9: the gateway also cancels the PaymentIntent here` (`:411`);
  `runMarkBookingsCompleted` (`:423`) must add `payoutReleaseAt = end + 48h`.
  **Decide:** keep the instant emulator gateway for jest/seed and use real
  Stripe test mode on the simulator (I'd keep both, chosen by whether the
  Stripe secret is set).
- **Store policy (check first, §15):** driving lessons are a real-world
  service used outside the app, which Apple (Guideline 3.1.5 "Goods and
  Services Outside of the App") and Google Play's payments policy allow to
  be paid without in-app purchase. Read the current text of both and quote
  the clause before writing payment code; the paid subscription itself stays
  in-app purchase.
- **Owner setup (I do these, not you):** a Stripe account with **Connect
  (Express)** enabled and the platform profile filled; test-mode keys put by
  me into the git-ignored `functions/.secret.local` (`.gitignore:71`) as
  `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` — never pasted in chat; the
  Stripe CLI logged in for `stripe listen --forward-to
  localhost:5001/licenseprepapp/us-central1/stripeWebhook`. Write me the exact
  list. Secrets follow the existing `defineSecret` pattern
  (`receipt-validation.ts:17`); jest gets dummies in
  `__tests__/helpers/env.ts` and a Stripe mock (no network in tests).
  **Decide:** how the app gets the **publishable** key (I'd return it from
  the callable with the `client_secret`, so no build-time define).
- **App package:** `flutter_stripe` is new. The pubspec warns that `pub add`
  once bumped 20+ packages — pin by hand, show me the `pubspec.lock` diff
  before keeping it. Known requirements to verify in its docs: Android
  `MainActivity` must extend **`FlutterFragmentActivity`** (today
  `FlutterActivity`, `android/app/src/main/kotlin/com/driveusa/app/MainActivity.kt:5`;
  there is also a stale `com/example/license_prep_app/MainActivity.kt` —
  report, don't delete) and an AppCompat/MaterialComponents theme; iOS
  target is 15.0 (`Podfile:2`). **Decide:** Apple Pay / Google Pay in the
  PaymentSheet now (needs a merchant id + domain setup) or cards only first
  (I'd do cards first).
- **Webhook (§9.3):** one HTTPS `stripeWebhook`, signature verified with
  `STRIPE_WEBHOOK_SECRET`, dedupe on `processedWebhooks/stripe_<event.id>`
  **inside the same transaction** as the state change (the Apple/Google
  handlers check-then-write, `index.ts:2200` — don't copy that), failures to
  `recordWebhookFailure` (`webhook-dead-letter.ts:42`). Events:
  `payment_intent.succeeded` → `confirmBooking`; a success for an
  **expired** booking → re-lock the slots, or refund automatically and push
  the student if one is taken; `account.updated` with charges + payouts
  enabled → `stripeAccountId`, `payoutsEnabled: true` (feeds `stage`,
  `instructors.ts:161`); `charge.dispute.created` → **decide** what we
  record.
- **Payouts onboarding (§9.2, §14.2):** `startInstructorPayouts` creates or
  reuses the Express account (`instructorPrivate.stripePendingAccountId`,
  reused on retry) and returns an Account Link; a «Настроить выплаты» card in
  the instructor Профиль opens it and shows the state. Only `kind == 'school'`
  takes payments (§6.2). Weekly payouts (§9.1).
- **Release (§9.2 step 4):** `releaseInstructorPayouts` (hourly, paginated
  like the other sweeps): `completed`, no open no-show, past
  `payoutReleaseAt` → `transfers.create({ amount: lessonCents, destination,
  source_transaction: chargeId, transfer_group })` → `payout_released`; a
  `late_cancelled` lesson pays out after start + 48 h. Idempotency keys on
  every Stripe write.
- **Refunds (§9.3):** school cancel and student ≥ 24 h → refund on the
  platform charge (before any transfer); after a transfer: reversal first,
  then refund. **Decide:** does a free cancel refund the platform fee too
  (I'd refund the full total; Stripe keeps its own fee)? Push the student
  «Возврат оформлен» (§12) and log `booking_refunded` (§14.3, not built yet).
- **No-show (§9.3):** `completed → disputed` via `reportNoShow` within 48 h
  holds the payout; resolution is `adminResolveNoShow` in P10's dashboard.
  **Decide:** build `reportNoShow` + `disputed` now (I'd build it, since it
  must block the release) and leave resolution to P10.
- **Holds cap (risk register, P7 residual):** with real money a student
  could hold many half hours for 15 min each. **Decide** the limit (I'd
  allow 2 open `pending_payment` holds per student).
- **Deletion (§9.4, §17):** add the two blockers — an open `disputed`
  booking, and (instructor) a completed lesson not yet paid out — next to
  `upcomingBookingCount` (`bookings.ts:464`); the Express account is closed
  or rejected after the last payout.
- **Instructor money UI:** Календарь «Прошедшие и доход» (the income part,
  `instructor_calendar_screen.dart:23`), the lesson page's «Вы получите»
  with payout state (pending / released). Students: payment errors and the
  PaymentSheet cancel path on the booking page.
- **Seed:** stage-2 seed schools have `payoutsEnabled: true` and no Stripe
  account — fine for the instant gateway; for the Stripe path, onboard one
  test Express account through the app and note how to re-use it.
- **Pricing (§9.1):** re-check Stripe's US pricing (card %, Connect
  per-account and per-payout fees) and update the §9.1 table if it changed.

## Environment

- The background-task limit is 2 hours. Start emulators and `flutter run`
  **detached**:
  `nohup firebase emulators:start --only auth,firestore,functions,storage,pubsub --project licenseprepapp > <scratchpad>/emulators.log 2>&1 &`
  and `nohup sh -c "tail -f /dev/null | flutter run -d <udid> --dart-define=USE_EMULATOR=true --pid-file <scratchpad>/flutter.pid" > <scratchpad>/flutter-run.log 2>&1 &`.
  Hot reload `kill -USR1 $(cat …/flutter.pid)`, restart `-USR2` (new l10n
  keys need a restart; an edit made while `flutter run` was still building
  is missed — `touch` the file and restart). A new native plugin
  (`flutter_stripe`) needs a full `flutter run` (pod install), not a
  restart. After a functions change, `cd functions && npm run build` (the
  emulator serves `lib/`).
- The booking fee params live in the git-ignored `functions/.env.local`;
  without them the functions emulator stops at an interactive prompt. Jest
  sets them in `functions/src/__tests__/helpers/env.ts` (an unset `defineInt`
  reads **0**, not its default). Secrets for the emulator go in
  `functions/.secret.local`.
- **The emulator never runs schedules by itself.** Fire one by publishing to
  its topic:
  `curl -X POST -H "Content-Type: application/json" "http://127.0.0.1:8085/v1/projects/licenseprepapp/topics/firebase-schedule-<name>:publish" -d '{"messages":[{"data":"e30="}]}'`.
- Re-seed after every emulator start **and after running jest** (jest
  overwrites `config/instructors.launchStates`):
  `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-instructors.js`.
  If it fails with `CANCELLED: call already cancelled` at the chat-thread
  reset, retry a REST `DELETE` on that conversation doc
  (`Authorization: Bearer owner`) until it returns 200, then seed again.
- Functions tests against the running emulators:
  `cd functions && STORAGE_RULES_PROJECT=licenseprepapp npx jest --forceExit`.
- Accounts (password = `SEED_PASSWORD` in that script): `seed-student-paid@`
  (IL, paid; lessons with Lakeview `-01` — one completed, two upcoming — and
  Northside `-04`, including one that ended but is still `confirmed`),
  `seed-student-trial@` (locked), `seed-student-md@` (MD),
  `seed-instr-01..24@`. Stripe test cards (e.g. `4242 4242 4242 4242`, a
  3-D Secure card, a declined card) are Stripe's published test numbers.
- **Two simulators:** iPhone 16 Pro `012437EB-D365-4F29-8296-367FAC033473`
  (student) + iPhone 16 `142438B7-D80A-46F0-82FD-FC0DC80FB2BB` (instructor —
  sign in as `seed-instr-01` for Lakeview), a `flutter run` each — start the
  second after the first has built. With the simulator tool the first tap on
  a text field only focuses it, and screenshots lag a beat (screenshot again
  before retyping or tapping; on a page that just scrolled, a long-press can
  land one row off). Pushes: the emulator logs `push (emulator, not sent)
  {…}`; hand it to the app with `xcrun simctl push <udid> com.driveusa.app
  file.apns` (data keys top level + a unique `gcm.message_id`); the in-app
  banner hides after 4 s, so tap it at once.
- If live Firestore lists go stale after several hot reloads, hot-restart
  before debugging (risk register, 2026-10-05).

## Working rules (unchanged)

Emulators and Stripe **test mode** only, never deploy, never a live key.
Never commit `.agents/` or `skills-lock.json`. Commits are authored **and
committed** as `demian-v <81762762+demian-v@users.noreply.github.com>`, with
**no `Co-Authored-By: Claude` line**; check with
`git log -1 --format='%an <%ae> | %cn <%ce>'`. Commit and push only when I
say. Jest + Flutter tests and the analyzer baseline diff (no new lines).
5 locales for every new string. Bento design, `ForwardPageRoute` /
`BackPageRoute`. Simulator screenshots as proof. Report bugs, then ask
before fixing. Update the vault TODO, plan, wiki (`cloud-functions`,
`security-rules`, `account-deletion`, design patterns, risk register) and
memory in the same session.
