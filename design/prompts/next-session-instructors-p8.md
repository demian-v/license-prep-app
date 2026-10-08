# Next session: P8 Reviews

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`.

---

Resume the DriveUSA Instructors feature: **P7 Bookings is complete**, start
**P8 Reviews**.

## Read first

1. `~/.claude/CLAUDE.md`. State a 1–3 step plan and name the guidelines that
   apply before writing anything.
2. The vault TODO `raw/drive_usa/2026-09-30-Instructors TODO.md`: "State",
   "How to resume", "Decisions", the P7 section, then "Later phases".
3. Plan v2 `raw/drive_usa/2026-09-30-Instructors Plan v2.md`: **§11** (reviews),
   §5 (`instructors/{uid}/reviews/{studentUid}`, `ratingSum/Count/Avg`),
   §9.3 + §9.5 (what "completed" means, how P7 built it), §12 (the "Leave a
   review" push on completion), §13 (how the listing uses ratings), §14.2
   (Профиль: "My reviews"), §17 (reviews the user wrote are deleted with the
   numbers adjusted) and the §15 P8 row.
4. Load the `driveusa` skill; read the risk register before touching rules,
   and `wiki/driveusa/Development/design system/design-patterns.md` (Chat and
   Bookings sections) before UI.

## State (2026-10-05)

- Branch `instructors`, last commit **`87bde26`** (P7 = `db46bf6`). Run
  `git status` first; the untracked `.agents/`, `skills-lock.json` and
  `design/memes/own/*` folders are never committed.
- Tests: Flutter 354, functions 682 (46 suites), all passing; analyzer
  baseline 1531 lines (diff against `HEAD` in a scratchpad worktree — no new
  lines).
- Nothing deployed. Never deploy from this branch.

## P8 Reviews (plan §11, §15)

Give me a short P8 plan first (callable, eligibility, the rating maths,
where a student leaves a review, the push, the instructor's own list,
reports, deletion, seed, tests, and everything below marked **decide**),
then build. Facts already checked:

- **Data already exists (P1):** `instructors/{uid}/reviews/{studentUid}` —
  one review per student per instructor — with `studentDisplayName`
  ("Anna K."), `rating` 1–5, `comment` ≤ 500, `lastBookingId`, `createdAt`,
  `updatedAt`. Rule: the **owner instructor** reads, nobody writes
  (`firestore.rules:331-335`). Students read through `getInstructorReviews`
  (`functions/src/instructors.ts:114`, newest 50, no uid / booking id).
- **The numbers:** `ratingSum`, `ratingCount`, `ratingAvg` on the public
  doc. Plan §11: `submitReview` does it in **one transaction** — insert:
  `sum += r, count += 1`; update: `sum += r - old`; `ratingAvg = sum /
  count` (rounded to 1 decimal, as the seed does). The app shows «Новый»
  under 3 reviews (`InstructorListing.isNew`, `lib/models/instructor_listing.dart:73`)
  and ranks those as 4.0 (`:194`); the «Рейтинг 4+» filter needs ≥ 3.
- **Eligibility (§11):** the caller has a booking with this instructor in
  `completed` (or `payout_released`, P9). P7 sets `completed` in
  `runMarkBookingsCompleted` (`functions/src/bookings.ts:419`). **Decide:**
  may a student whose paid plan has lapsed still review a lesson they took
  (I'd allow it: the lesson happened)? **Decide:** editing — §11 allows an
  update; is there also a "delete my review"?
- **Comment text:** reviews are shown to every paid student. **Decide:**
  run `maskContacts` (`functions/src/chat.ts`) on comments so a review
  can't carry a phone number past the chat masking (I'd mask).
- **Where a student leaves it — decide:** the completed lesson's page
  (`lib/screens/booking_detail_screen.dart`, a «Оставить отзыв» action), and/or
  a prompt in «Мои уроки», and/or the instructor's detail page. The sheet:
  5 stars + optional comment, «Отправить». After sending, the lesson page
  shows the review (with «Изменить»).
- **Push (§12):** `markBookingsCompleted` → the student gets «Как прошёл
  урок?» / "Leave a review", route `booking/<id>` (already routed by
  `HomeScreen._openPushRoute`). Add the kind to `functions/src/push.ts`
  `TEXTS` (5 locales; `sendPushToUser` takes `vars(lang)` for a
  `{name}` / `{time}` body). Send once, after the transition, outside the
  transaction (as `confirmBooking` does).
- **Instructor side (§14.2):** «Мои отзывы» in the instructor Профиль — the
  owner rule already lets them read their own subcollection directly. The
  listing card / detail page already show rating + reviews (P4). Replies
  are v2.
- **Review reports (§7, P4 left a comment at `firestore.rules:191-193`):**
  `reports` gets `contentType: 'review'`. Problem: the review's doc id **is
  the student's uid**, and `getInstructorReviews` deliberately never sends
  it. **Decide:** how a report names the review without exposing the uid —
  e.g. the callable returns an opaque `reviewId` (hash of instructor +
  student) and a report goes through a small callable instead of a direct
  rule write.
- **Account deletion (§17):** the student's reviews are deleted **and the
  numbers adjusted in a transaction**. Finding them: there is no
  collection-group index (`firestore.indexes.json` has `"fieldOverrides":
  []`, and risk #15 says indexes are not deployed). Suggestion (avoids a new
  index): the student's own `bookings` (`where('studentUid', '==', uid)`)
  give every instructor they could have reviewed — read those reviews
  **before** the bookings are anonymised in the same deletion
  (`collectUserDataForDeletion`, `functions/src/account-deletion.ts`). An
  instructor deleting their account already removes reviews **on** them
  (`:66`).
- **Seed:** reviews today have fake student ids (`seed-student-1..5`, plus
  `lastBookingId` placeholders, `scripts/local/seed-instructors.js:131`).
  `seed-student-paid` has a **completed** Lakeview lesson (`seed-booking-lv-1`)
  and no review yet — the happy path. Consider a confirmed seed lesson that
  has already ended, so firing `markBookingsCompleted` (see Environment)
  shows the review push.
- **Analytics:** none of the 9 §14.3 events is review-related. **Decide**
  whether to add `review_submitted` (no ids).

## Environment

- The background-task limit is 2 hours. Start emulators and `flutter run`
  **detached**:
  `nohup firebase emulators:start --only auth,firestore,functions,storage,pubsub --project licenseprepapp > <scratchpad>/emulators.log 2>&1 &`
  and `nohup sh -c "tail -f /dev/null | flutter run -d <udid> --dart-define=USE_EMULATOR=true --pid-file <scratchpad>/flutter.pid" > <scratchpad>/flutter-run.log 2>&1 &`.
  Hot reload `kill -USR1 $(cat …/flutter.pid)`, restart `-USR2` (new l10n
  keys need a restart; an edit made while `flutter run` was still building
  is missed — `touch` the file and restart). After a functions change,
  `cd functions && npm run build` (the emulator serves `lib/`).
- The booking fee params live in the git-ignored `functions/.env.local`;
  without them the functions emulator stops at an interactive prompt. Jest
  sets them in `functions/src/__tests__/helpers/env.ts` (an unset `defineInt`
  reads **0**, not its default).
- **The emulator never runs schedules by itself.** Fire one by publishing to
  its topic:
  `curl -X POST -H "Content-Type: application/json" "http://127.0.0.1:8085/v1/projects/licenseprepapp/topics/firebase-schedule-markBookingsCompleted:publish" -d '{"messages":[{"data":"e30="}]}'`.
- Re-seed after every emulator start **and after running jest** (jest
  overwrites `config/instructors.launchStates`):
  `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-instructors.js`.
  If it fails with `CANCELLED: call already cancelled` at the chat-thread
  reset, retry a REST `DELETE` on that conversation doc
  (`Authorization: Bearer owner`) until it returns 200, then seed again.
- Functions tests against the running emulators:
  `cd functions && STORAGE_RULES_PROJECT=licenseprepapp npx jest --forceExit`.
- Accounts (password = `SEED_PASSWORD` in that script): `seed-student-paid@`
  (IL, paid; lessons with Lakeview `-01` and Northside `-04`, threads with
  `-01` unlocked and `-03`), `seed-student-trial@` (locked),
  `seed-student-md@` (MD), `seed-instr-01..24@`.
- **Two simulators:** iPhone 16 Pro `012437EB-D365-4F29-8296-367FAC033473`
  (student) + iPhone 16 `142438B7-D80A-46F0-82FD-FC0DC80FB2BB` (instructor —
  sign in as `seed-instr-01` for Lakeview), a `flutter run` each — start the
  second after the first has built. With the simulator tool the first tap on
  a text field only focuses it, and screenshots lag a beat (screenshot again
  before retyping or tapping). Pushes: the emulator logs `push (emulator,
  not sent) {…}`; hand it to the app with `xcrun simctl push <udid>
  com.driveusa.app file.apns` (data keys top level + a unique
  `gcm.message_id`); the in-app banner hides after 4 s, so tap it at once.
- If live Firestore lists go stale after several hot reloads, hot-restart
  before debugging (risk register, 2026-10-05).

## Working rules (unchanged)

Emulators only, never deploy. Never commit `.agents/` or `skills-lock.json`.
Commits are authored **and committed** as
`demian-v <81762762+demian-v@users.noreply.github.com>`, with **no
`Co-Authored-By: Claude` line**; check with
`git log -1 --format='%an <%ae> | %cn <%ce>'`. Commit and push only when I
say. Jest + Flutter tests and the analyzer baseline diff (no new lines).
5 locales for every new string. Bento design, `ForwardPageRoute` /
`BackPageRoute`. Simulator screenshots as proof. Report bugs, then ask
before fixing. Update the vault TODO, plan, wiki (`cloud-functions`,
`security-rules`, `account-deletion`, design patterns) and memory in the
same session.
