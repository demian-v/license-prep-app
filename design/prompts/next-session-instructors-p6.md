# Next session: P6 Chat

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`.

---

Resume the DriveUSA Instructors feature: **P5 Push is complete**, start **P6
Chat**.

## Read first

1. `~/.claude/CLAUDE.md`. State a 1–3 step plan and name the guidelines that
   apply before writing anything.
2. The vault TODO `raw/drive_usa/2026-09-30-Instructors TODO.md`: "State",
   "How to resume", "Decisions", the P5 section, then "Later phases" (the P6
   line has a "Start here" note).
3. Plan v2 `raw/drive_usa/2026-09-30-Instructors Plan v2.md`: **§10 (chat)**,
   §5 (the `conversations` data model), §12 (the `sendMessage` push), §16
   (masking-regex tests), §17 (deletion: conversations are anonymised, not
   deleted) and the §15 P6 row.
4. Load the `driveusa` skill; read the risk register before touching rules,
   and `wiki/driveusa/Development/design system/design-patterns.md` before UI.

## State (2026-10-05)

- Branch `instructors`, last commit **`57fcf6a`** (CI green after a re-run;
  the red email was a GitHub runner that never started). P5 commits:
  `4237bdf` push (tokens, permission at the end of the instructor wizard,
  moderation push, tap → route, in-app banner, UIScene shim in
  `AppDelegate.swift`); `57fcf6a` fix: EXIF orientation kept when stripping
  photo metadata (found on a real iPhone). Run `git status` first.
- Tests: Flutter 318, functions 591, all passing; no new analyzer lines.
- APNs key `4C5G9Z79U7` is uploaded to Firebase (dev + prod); real-device push
  verified on the owner's iPhone 12 Pro.
- Nothing deployed. Never deploy from this branch.

## P6 Chat (plan §10)

Give me a short P6 plan first (callables, masking, UI screens, push, unread
badge, reports, deletion, tests, and anything you need me to decide), then
build. Facts already checked:

- **Rules exist (P1):** `conversations/{studentUid_instructorUid}` and
  `messages/{id}` are server-written; participants read
  (`firestore.rules:358-366`, `participantUids` contains `auth.uid`). So every
  write goes through callables (`sendMessage`, `markConversationRead`); the
  app reads live with Firestore listeners.
- **Who starts a thread:** only a paid student (`requirePaidSubscriber`), only
  with a `listed` instructor at **stage ≥ 1**; instructors can reply but not
  start. Rate limit 5 new threads per student per day. Production has no
  stage ≥ 1 instructor until P10 (Didit); the seed has stage 1 and 2 profiles
  (`scripts/local/seed-instructors.js:102-106`).
- **«Написать» is disabled today** with a reason
  (`lib/screens/instructor_detail_screen.dart:278-291`, keys
  `instructor_chat_soon` / `instructor_chat_after_id`). Enable it for
  stage ≥ 1; keep the reason for stage 0.
- **Masking** while `contactUnlocked == false`: phone-like runs (7+ digits
  with spaces/dots/dashes/brackets), emails, URLs/domains, `@handles`, and
  whatsapp/telegram/viber/signal + digits → `•••`, `masked: true`, quiet line
  «Контакты откроются после первой брони». Spelled-out numbers getting through
  is accepted. Server-side, with a table of test cases.
- `contactUnlocked` turns true after the first **confirmed booking**, which is
  P7. So P6 builds the flag and the masking; the thread header shows contacts
  only once unlocked. `getInstructorContactInfo` does **not** exist yet (only
  `getInstructorContacts`, which is the instructor's own, for Профиль).
- Messages: text only, ≤ 2000 chars, no attachments, edits or deletes.
  Denormalise `instructorName`, the instructor's photo **path** (not a URL —
  P3b decision), `studentDisplayName`.
- **Unread:** `markConversationRead` resets the caller's count. Badge = the sum
  across the user's conversations, on Инструкторы (students) and Чат
  (instructors). `lib/widgets/super_enhanced_footer.dart` has **no badge**
  support yet.
- **UI placeholders:** `lib/screens/chat_list_screen.dart` (39 lines, empty
  state) is both the instructor Чат tab and the student «Сообщения» segment
  (`ChatListScreen(embedded: true)`, `instructors_screen.dart:216`). The
  thread screen is new.
- **Push:** `sendMessage` notifies the other side through
  `sendPushToUser` (`functions/src/push.ts`). It only supports fixed per-kind
  texts today; chat needs a **dynamic** title (sender's first name) and the
  **masked** preview ≤ 80 chars. Route `chat/<conversationId>` —
  `HomeScreen._openPushRoute` (`home_screen.dart`) parses it but **drops** it
  today: open the thread. Don't show the in-app banner when the user is
  already in that thread.
- **Student permission moment:** call
  `PushService.instance.requestPermissionAndRegister()` after a student's first
  message is sent (never blocks the send).
- **Report message:** long-press → the shared `ReportSheet` → `reports`. The
  `reports` rule (`firestore.rules:178-200`) allows `quiz_question`,
  `theory_section`, `profile_section`, `instructor`; add `message` with its
  own reason set and an entity that ties it to a conversation the reporter is
  in.
- **Account deletion (§17):** `functions/src/account-deletion.ts` has no
  conversation handling yet. Anonymise, don't delete: the other side keeps the
  thread, the deleted side shows as «Удалённый пользователь».

## Environment

- The background-task limit is 2 hours. Start emulators and `flutter run`
  **detached**:
  `nohup firebase emulators:start --only auth,firestore,functions,storage,pubsub --project licenseprepapp > <scratchpad>/emulators.log 2>&1 &`
  and `nohup sh -c "tail -f /dev/null | flutter run -d <iPhone 16 Pro udid> --dart-define=USE_EMULATOR=true --pid-file <scratchpad>/flutter.pid" > <scratchpad>/flutter-run.log 2>&1 &`.
  Hot reload `kill -USR1 $(cat …/flutter.pid)`, restart `-USR2` (new l10n
  keys need a restart). After a functions change, `cd functions && npm run
  build` (the emulator serves `lib/`).
- Re-seed after every emulator start:
  `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-instructors.js`.
- Accounts (password = `SEED_PASSWORD` in that script): `seed-student-paid@`
  (IL, paid), `seed-student-trial@` (locked), `seed-student-md@` (MD),
  `seed-instr-01..24@` (log in as one to reply), mid-signup
  `seed-signup-school@` / `seed-signup-instructor@example.com`.
- **Two-sided chat on the simulator:** one simulator per side works (the
  iPhone 16 Pro plus a second one), both on `127.0.0.1`. Pushes: the emulator
  logs `push (emulator, not sent) {…}`; hand that payload to the app with
  `xcrun simctl push booted com.driveusa.app file.apns` (data keys at the top
  level, plus a `gcm.message_id`).
- The simulator keyboard drops fast typing: type slowly, one field at a
  time, or paste via `xcrun simctl pbcopy <udid>` + long-press → Paste.
- **Real iPhone (optional):** emulators must listen on `0.0.0.0` — use an
  untracked copy `firebase.device.json` with `"host": "0.0.0.0"` per emulator
  and `--config firebase.device.json`, run with
  `--dart-define=EMULATOR_HOST=<Mac LAN IP>`, delete the copy afterwards. The
  debug build replaces the owner's App Store install. Claude can't drive the
  phone or iPhone Mirroring; the owner taps.

## Working rules (unchanged)

Emulators only, never deploy. Never commit `.agents/` or `skills-lock.json`.
Commits are authored **and** committed as `demian-v
<81762762+demian-v@users.noreply.github.com>`, with **no `Co-Authored-By:
Claude` line**; check with `git log -1 --format='%an <%ae> | %cn <%ce>'`.
Commit and push only when I say. Jest + Flutter tests and the analyzer
baseline diff (no new lines). 5 locales for every new string. Bento design,
`ForwardPageRoute` / `BackPageRoute`. Simulator screenshots as proof. Report
bugs, then ask before fixing. Update the vault TODO, plan, wiki
(`cloud-functions`, `security-rules`) and memory in the same session.
