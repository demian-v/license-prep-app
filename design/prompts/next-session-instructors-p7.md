# Next session: P7 Bookings (no money yet)

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`.

---

Resume the DriveUSA Instructors feature: **P6 Chat is complete**, start **P7
Bookings (no money yet)**.

## Read first

1. `~/.claude/CLAUDE.md`. State a 1–3 step plan and name the guidelines that
   apply before writing anything.
2. The vault TODO `raw/drive_usa/2026-09-30-Instructors TODO.md`: "State",
   "How to resume", "Decisions", the P6 section, then "Later phases".
3. Plan v2 `raw/drive_usa/2026-09-30-Instructors Plan v2.md`: **§9** (§9.1 fee
   model, §9.2 the flow — in P7 the Stripe steps sit behind a gateway, §9.3
   state machine, §9.4 deleting an account with bookings), §5 (`bookings`,
   `bookingSlots`), §10 (`contactUnlocked`, the «Забронировать» link in the
   thread header), §12 (booking pushes), §14.2 (Календарь lists), §17
   (bookings anonymised) and the §15 P7 row.
4. Load the `driveusa` skill; read the risk register before touching rules,
   and `wiki/driveusa/Development/design system/design-patterns.md` (now with
   a Chat section) before UI.

## State (2026-10-05)

- Branch `instructors`, last commit **`95124de`** (P6 Chat). Run `git status`
  first; the untracked `.agents/`, `skills-lock.json` and
  `design/memes/own/*` folders are never committed.
- Tests: Flutter 329, functions 658, all passing; analyzer baseline 1531
  lines (diff against `HEAD` in a scratchpad worktree — no new lines).
- Nothing deployed. Never deploy from this branch.

## P7 Bookings (plan §9, §15)

Give me a short P7 plan first (callables, slot locking, gateway, schedulers,
cancellation, push, UI on both sides, deletion, tests, and everything below
marked **decide**), then build. Facts already checked:

- **Who can book:** only `kind == 'school'` at **stage 2** (bookable =
  ID + licence + payouts + hours, `computeListing` in
  `functions/src/instructors.ts`). Private instructors never take bookings.
  The student must be paid (`requirePaidSubscriber`).
- **«Забронировать» is disabled today** with a reason
  (`lib/screens/instructor_detail_screen.dart:296-305`, keys
  `instructor_book_soon` / `instructor_book_after_check`). Enable it for a
  stage-2 school; keep the licence reason below stage 2. `instructor_book_soon`
  becomes orphaned — remove it from all 5 locale files.
- **Rules exist (P1):** `bookings/{id}` read by the student or the instructor,
  write `false` (`firestore.rules:383-388`); `bookingSlots/*` server-only
  (`:343-346`, one doc per 30-minute block, `tx.create()` is the lock). All
  writes go through callables.
- **No money in P7** (§15): the payment step is a `PaymentGateway` interface.
  The emulator implementation "pays" at once (straight to `confirmed`).
  P9 plugs Stripe in behind it. **Decide:** what the gateway does outside the
  emulator before P9 (I'd refuse with `failed-precondition:
  payments-unavailable`).
- **Fees are still computed and stored** (§9.1): `lessonCents`,
  `platformFeeCents`, `totalCents`, `feeKind: first|later`. First lesson =
  no fee-bearing booking with this instructor yet (the status list is in
  §9.3). Fee settings are function params (`defineInt`, already imported in
  `functions/src/index.ts:27`), never in client code.
- **Slots and time:** 30-minute boundaries, lengths from the instructor's
  `lessonDurations`, inside `availability` for that date in the instructor's
  `timezone`, ≥ 12 h ahead, ≤ 60 days ahead. Stored as UTC Timestamps.
  **Decide:** the DST-safe date maths — plan says luxon, but functions have
  no date library today (`functions/package.json`); the alternative is
  `Intl.DateTimeFormat` with the zone. Pin any new package exactly.
- **State machine (§9.3, no-money subset):** `pending_payment` (15-min
  `expiresAt`) → `confirmed` | `expired`; `confirmed` → `completed` (end
  passed) | `refunded` (student ≥ 24 h before, or instructor any time) |
  `late_cancelled` (student < 24 h). `disputed` / `payout_released` and
  no-show are P9–P10. Slots are freed on `expired`, `refunded` and
  instructor cancel.
- **Schedulers:** an expiry sweep for `pending_payment` and
  `markBookingsCompleted` (every 15 min). The existing ones use
  `functions.pubsub.schedule(...)` (`index.ts:1518`, `:1752`, `:1927`); the
  emulator runs pubsub. They must be capped/paged (risk #25: the old
  schedulers stopped at 100 docs).
- **On confirm:** set `contactUnlocked: true` on
  `conversations/{studentUid_instructorUid}` — **create the thread if it
  doesn't exist** (same fields as `sendMessage` creates, `functions/src/chat.ts`),
  and push the instructor «Новая бронь» (route `booking/<id>`). Masking then
  stops and the student's thread header shows the contacts card
  (`getInstructorContactInfo`, already built).
- **Push:** add booking kinds to `functions/src/push.ts` (5-locale texts in
  `TEXTS`, as `photo_*`). `booking/<id>` is parsed by `PushRoute` but dropped
  in `HomeScreen._openPushRoute` (`lib/screens/home_screen.dart:92`) — give
  it a screen. **Decide:** which events push which side (confirm → instructor
  per §12; cancellations → the other side?).
- **UI, instructor:** Календарь gets «Предстоящие уроки» and «Прошедшие»
  under the grid (the screen's doc comment at
  `lib/screens/instructor_calendar_screen.dart:18` points here; income is
  P9). Cancel a lesson (frees slots, student refunded in P9).
- **UI, student:** a slot picker (date → free half-hour starts for the chosen
  length), a price summary (lesson + «Сервисный сбор» + total; the button
  says only «Забронировать», owner rule 13), and a booking detail page.
  **Decide:** where a student sees their lessons — the Инструкторы segments
  are Поиск · Избранное · Сообщения today. **Decide:** times shown in the
  instructor's timezone (where the lesson happens) or the student's.
- **Thread header link** «Забронировать» (§10) for a stage-2 school.
- **Account deletion (§9.4, §17):** `preDeleteAccountCheck` blocks deletion
  with upcoming `confirmed` bookings (either side) — «У вас N предстоящих
  уроков — отмените их перед удалением аккаунта.» Bookings are
  **anonymised**, never deleted (financial records): keep amounts and ids,
  drop names. `functions/src/account-deletion.ts` has the `redact` action
  from P6 for exactly this.
- **Analytics (§14.3):** `booking_created`, `booking_confirmed` (no ids, no
  PII). `booking_refunded` waits for P9.
- **Seed:** the stage-2 schools with hours are `seed-instr-01` Lakeview and
  `seed-instr-04` Northside (IL); Prairie Road (`-06`) is stage 2 with no
  hours (a "nothing to book" case). Add a couple of bookings in different
  states so both sides' lists have content.

## Environment

- The background-task limit is 2 hours. Start emulators and `flutter run`
  **detached**:
  `nohup firebase emulators:start --only auth,firestore,functions,storage,pubsub --project licenseprepapp > <scratchpad>/emulators.log 2>&1 &`
  and `nohup sh -c "tail -f /dev/null | flutter run -d <udid> --dart-define=USE_EMULATOR=true --pid-file <scratchpad>/flutter.pid" > <scratchpad>/flutter-run.log 2>&1 &`.
  Hot reload `kill -USR1 $(cat …/flutter.pid)`, restart `-USR2` (new l10n
  keys need a restart). After a functions change, `cd functions && npm run
  build` (the emulator serves `lib/`).
- Re-seed after every emulator start **and after running jest** (jest
  overwrites `config/instructors.launchStates`):
  `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-instructors.js`.
- Functions tests against the running emulators:
  `cd functions && STORAGE_RULES_PROJECT=licenseprepapp npx jest --forceExit`.
- Accounts (password = `SEED_PASSWORD` in that script): `seed-student-paid@`
  (IL, paid; has chat threads with `seed-instr-01` unlocked and `-03`),
  `seed-student-trial@` (locked), `seed-student-md@` (MD), `seed-instr-01..24@`.
- **Two simulators** (P6 recipe): iPhone 16 Pro `012437EB-D365-4F29-8296-367FAC033473`
  (student) + iPhone 16 `142438B7-D80A-46F0-82FD-FC0DC80FB2BB` (instructor), a
  `flutter run` each — start the second after the first has built. With the
  simulator tool the first tap on a text field only focuses it, and
  screenshots lag typing by a beat (screenshot again before retyping).
  Pushes: the emulator logs `push (emulator, not sent) {…}`; hand it to the
  app with `xcrun simctl push <udid> com.driveusa.app file.apns` (data keys
  top level + a unique `gcm.message_id`).
- **Watch for:** in P6 a student app's Firestore listeners once delivered
  nothing for ~1 min after three hot reloads with a thread open (not
  reproduced since; risk register 2026-10-05). If live lists go stale, try a
  hot restart before debugging.

## Working rules (unchanged)

Emulators only, never deploy. Never commit `.agents/` or `skills-lock.json`.
Commits are authored **and** committed as `demian-v
<81762762+demian-v@users.noreply.github.com>`, with **no `Co-Authored-By:
Claude` line**; check with `git log -1 --format='%an <%ae> | %cn <%ce>'`.
Commit and push only when I say. Jest + Flutter tests and the analyzer
baseline diff (no new lines). 5 locales for every new string. Bento design,
`ForwardPageRoute` / `BackPageRoute`. Simulator screenshots as proof. Report
bugs, then ask before fixing. Update the vault TODO, plan, wiki
(`cloud-functions`, `security-rules`, `account-deletion`) and memory in the
same session.
