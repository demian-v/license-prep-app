# Next session: P5 Push notifications

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`.

---

Resume the DriveUSA Instructors feature: **P4 is complete**, start **P5 Push
notifications**.

## Read first

1. `~/.claude/CLAUDE.md`. State a 1–3 step plan and name the guidelines that
   apply before writing anything.
2. The vault TODO `raw/drive_usa/2026-09-30-Instructors TODO.md`: "State",
   "How to resume", "Decisions", then "Later phases" (the P5 line has a
   "Start here" note).
3. Plan v2 `raw/drive_usa/2026-09-30-Instructors Plan v2.md` §12 (push) and
   §15 (P5 row). P6 chat, P7 bookings and P9 payments all send pushes, which
   is why P5 comes first.
4. Load the `driveusa` skill; read the risk register before touching rules,
   and `wiki/driveusa/Development/design system/design-patterns.md` before UI.

## State (2026-10-05)

- Branch `instructors`, last commit **`3fe855f`**. P4 commits: `783afe1`
  listing, filters, detail page, favourites, instructor reports; `1b33b5b`
  detail cards as tiles, hours as a day list, star/filter icons, no hero for
  paid students; `3fe855f` onboarding Инструкторы step (first card + tab).
  Run `git status` first.
- Tests: Flutter 304, functions 574, all passing; no new analyzer lines.
- Nothing deployed. Never deploy from this branch.

## P5 Push (plan §12)

Give me a short P5 plan first (packages, token flow, the server sender,
permission moment, tests, what needs me in the Apple / Firebase consoles),
then build. Facts already checked:

- `pubspec.yaml`: `firebase_core ^4.0.0`, `cloud_functions ^6.0.0`,
  `firebase_crashlytics` pinned to `5.0.0` because `flutter pub add` once
  bumped 20+ packages and broke the build. **Pin `firebase_messaging` (and
  `flutter_local_notifications`) by hand** to the release that pairs with
  `firebase_core 4.0.x`, and show me the `pubspec.lock` diff before running
  `pod install`. Adding packages is a download: ask me first.
- iOS has **no push setup yet**: `ios/Runner/Runner.entitlements` holds only
  Associated Domains (no `aps-environment`), and there is no Background Modes
  → remote notifications. Android has no `POST_NOTIFICATIONS` permission.
- The APNs auth key upload (Firebase console) and the Push Notifications
  capability on the App ID (Apple Developer) are **mine to do**. Tell me
  exactly what to click; don't enter credentials anywhere.
- `firestore.rules` already has `users/{uid}/fcmTokens/{tokenId}` (P1): owner
  read/write, keys `token, platform, updatedAt`, token ≤ 4096. Plan: doc id =
  sha256(token), written by the owner, so no function is needed.
- Messages are **notification + data** (`apns.payload.aps.alert` +
  `data.route`), never data-only on iOS. Routes: `chat/<id>`,
  `booking/<id>`, `profile`.
- Permission is asked at the first moment it makes sense (a student's first
  message, the end of an instructor's registration), never at app start.
- Tokens: refreshed on `onTokenRefresh`, deleted on logout, pruned when a send
  returns `registration-token-not-registered`. Account deletion already
  removes `users/{uid}/fcmTokens/*` (P3b).
- **Nothing sends a push yet:** chat (P6) and bookings (P7) don't exist. So P5
  is the plumbing (permission, tokens, the server sender, tap → route) plus
  one real sender to prove it end to end. A good first one from §12:
  **moderation result**, e.g. `onInstructorUpload` telling the instructor
  their photo was approved or rejected → route `profile`. The student's
  permission moment (first message) arrives with P6: build the call now and
  wire it there.
- The functions emulator cannot deliver real FCM: put the sender behind a
  small interface and mock it in jest; on the simulator, check delivery with
  `xcrun simctl push` and a local payload.

## Environment

- The background-task limit is 2 hours, and it killed the emulators and
  `flutter run` last time. Start both **detached**:
  `nohup firebase emulators:start --only auth,firestore,functions,storage,pubsub --project licenseprepapp > <scratchpad>/emulators.log 2>&1 &`
  and `nohup sh -c "tail -f /dev/null | flutter run -d <iPhone 16 Pro udid> --dart-define=USE_EMULATOR=true --pid-file <scratchpad>/flutter.pid" > <scratchpad>/flutter-run.log 2>&1 &`.
  Hot reload: `kill -USR1 $(cat …/flutter.pid)`, restart `-USR2` (new l10n
  keys need a restart).
- Re-seed after every emulator start:
  `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-instructors.js`.
- Accounts (password = `SEED_PASSWORD` in that script): `seed-student-paid@`
  (IL, paid → listing), `seed-student-trial@` (locked preview),
  `seed-student-md@` (MD → «Скоро»), `seed-instr-01..24@`, mid-signup
  `seed-signup-school@` / `seed-signup-instructor@example.com`.
- Seed instructors have no photos. For approved photos, upload JPEGs to the
  Storage emulator under `instructorUploads/<uid>/photo/<id>.jpg` (the
  emulator trigger publishes them).
- The simulator keyboard drops fast typing: paste via
  `xcrun simctl pbcopy booted` + long-press → Paste.

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
