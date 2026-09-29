# Next session — result memes and a Share button

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`.

---

## Goal

Add a light, funny picture (a "meme") to the result of every test. The picture
depends on how well the user scored. The pictures live in Firebase and stay
small. The result screens get a second design pass so the picture fits, and
each result screen gets a **Share** button that opens a sheet with the motion
of <https://motion.dev/examples/vue-sheet-modal>.

The three test modules and their result screens:

| Module (ru UI) | Result screen |
|---|---|
| Экзамен | `lib/screens/exam_result_screen.dart` |
| Билеты (practice tickets) | `lib/screens/practice_result_screen.dart` |
| По темам (learn by topics) | `lib/screens/quiz_result_screen.dart` |

They share `lib/widgets/bento_result_parts.dart` (`BentoVerdictCard`,
`BentoStatTile`, `BentoStatRow`, `BentoResultBody`). Today the verdict card
shows `assets/images/success_fail/success.png` or `fail.png`.

Score buckets as I asked for them: **0–30 %, 31–60 %, 61–90 %, 91–100 %**.
There are 10 candidate pictures per bucket.

Branch: `security-plus-design`. Do not commit or push unless I ask. Never
touch `main`. Never commit `.agents/` or `skills-lock.json`.

## Read first

1. `~/.claude/CLAUDE.md`. State a short plan and name the guidelines that
   apply before writing code.
2. Load the `driveusa` skill and follow its vault conventions.
3. Vault, `wiki/driveusa/Development/design system/`:
   - `design-patterns.md`: the Bento vocabulary and my review rules 1–15.
   - `design-tokens.md`: colours, Rubik, Solar, radii and motion.
   - `design-implementation-status.md`: what each result screen looks like
     today.
4. The vault's `driveusa-risk-register.md`, before touching Firestore or
   Storage rules.
5. Memory: `reference_simulator_verification.md`. It covers how we verify on
   the simulator and the emulators (hot reload via the pid file, test
   accounts, trials, `// TEMP-…` launchers, frame capture for motion).

## Decisions to raise with me before building

Put these to me at STOP 1. Don't pick silently.

1. **Picture rights.** Pictures found on Google are usually copyrighted. Memes
   built on photos of real people also raise likeness issues in a paid app.
   For each candidate, record the source page, the author and the licence.
   Prefer sources whose licence allows commercial use inside an app
   (CC0/public domain, Pixabay/Unsplash-style licences, sticker packs with
   stated app-use terms). Flag any candidate whose licence you can't
   establish. Tell me if drawing or generating our own set would be safer.
2. **Bucket edges vs. the pass mark.** An exam passes at 36/40 = **90 %**
   (`lib/models/exam.dart:44-47`). The topic quiz passes at 90 % of its
   questions (`lib/screens/quiz_result_screen.dart:45-50`). With my buckets,
   a passing 90 % gets a "61–90" picture. Propose clean edges, for example
   `< 30`, `30–59`, `60–89`, `≥ 90` = passed, and let me choose.
3. **A new package for sharing.** The app has no share package (`pubspec.yaml`).
   `share_plus` is the usual choice. The standing rule is "no new packages",
   so ask me first.
4. **What gets shared.** Options: an image of the result card (score + meme +
   app name, rendered through a `RepaintBoundary`), plain text with a store
   link, or both. Also say which store links exist.
5. **Analytics.** Logging a `result_shared` event would be new logic in
   `analytics_service`, so ask before adding it.

## Hard rules for this feature

- **The Тесты/Экзамен freeze is lifted only for the three result screens and
  `bento_result_parts.dart`.** The question screens and the Тесты tab itself
  stay frozen.
- New code for this feature is allowed: a meme service or model, the share
  sheet, and new Storage/Firestore rules. Existing providers, services,
  subscription and session checks, and analytics stay untouched. If you find
  a bug, tell me and ask before fixing it.
- **Emulators only.** Use Firestore 8080, Storage 9199 and Auth 9099 with
  `--dart-define=USE_EMULATOR=true`. There is no staging: the live project
  `licenseprepapp` is production. Uploading pictures, or deploying rules or
  data, to it needs my explicit OK in chat.
- **Pictures must be light jokes.** Nothing hurtful, mocking, political,
  crude, or aimed at a group. The joke is about the score or studying, never
  about the person.
- Keep the Bento look (rules in `design-patterns.md`): top-aligned, no
  two-line titles, and colour meanings green = done/correct, red = wrong,
  amber = time/access, blue = current/action.
- Motion only through `AppMotion`, one-shot, and it must respect reduced
  motion.
- New user-facing text goes into **all five** `lib/localization/l10n/*.json`
  files, or `localization_coverage_test` fails.

## Phase 1 — find the candidates (then STOP 1)

1. Search for teacher/school/"exam results" sticker packs and meme sets that
   fit each bucket. Aim for light, friendly humour: a teacher's proud face,
   a sleepy cat over a textbook, a "we'll get there" thumbs-up.
2. Download **10 per bucket** into a review folder. Don't commit it:
   ```
   design/memes/candidates/
     b1-0-30/01-<slug>.<ext> … 10-…
     b2-31-60/…
     b3-61-90/…
     b4-91-100/…
     SOURCES.md
   ```
3. `SOURCES.md` has one table per bucket with these columns: file, source
   URL, author, licence, size, why it fits the bucket, and concerns.
4. Build a contact sheet per bucket as a PNG grid, using PIL from the venv at
   `/private/tmp/claude-501/dv/venv` or a fresh one. Send the sheets to me.
5. **STOP 1.** Wait for my picks and my answers to the decisions above.

## Phase 2 — redesign the result screens (then STOP 2)

1. Take screenshots of all three result screens today, in passed and
   not-passed states. Reach them on the simulator with a `// TEMP-…`
   launcher.
2. Propose how the meme sits in the layout. Ideas: the meme becomes the
   picture in `BentoVerdictCard`; the score pill overlaps the meme; stat tiles
   below. Keep one layout shared by all three screens through
   `bento_result_parts.dart`.
3. Show me the proposal as simulator screenshots, not only a description.
4. **STOP 2.** Apply my feedback before storing anything.

## Phase 3 — store and load the pictures

1. Optimise my chosen pictures:
   - WebP, longest side about 512 px, target **≤ 60 KB** each.
   - Keep the alpha channel for stickers.
   - Record the sizes before and after.
2. **Storage:** put them under `result_memes/<bucket>/<id>.webp`. Add a
   `storage.rules` block with read for signed-in users and no writes, matching
   `quiz_images`/`theory_images`.
3. **Firestore:** a collection such as `result_memes/{id}` with these fields:
   `bucket`, `storagePath`, `width`, `height`, `bytes`, `active`, `order`.
   Add a `firestore.rules` read rule for signed-in users and add it to the
   rules test suite.
4. **Seeding:** a seed script next to `scripts/local/grant-local-trial.js`
   that uploads to the emulators only and refuses to run without
   `FIRESTORE_EMULATOR_HOST`.
5. **App side:**
   - Pick one active meme for the bucket at random, and avoid repeating the
     last one shown.
   - Show it with `cached_network_image` (already a dependency).
   - Fall back to the current `success.png` / `fail.png` when offline, when
     the collection is empty, or when a load fails. No spinner flash; reserve
     the picture's space.
6. **Tests:** bucket-edge tests (0, 30, 31, 60, 61, 89, 90, 91, 100 % and the
   edges I chose), the fallback path, and the rules test.

## Phase 4 — Share button and sheet motion

1. **Study the motion first.** The example's source is behind the Motion+
   paywall, so study it live:
   - Open the example in the built-in browser and use "Open fullscreen".
   - Capture frames of open, drag and dismiss.
   - Write down what you see: how the page behind reacts (scale, corner
     radius, dim), the sheet's spring entrance, the staggered content, the
     swipe-to-dismiss threshold and velocity. Show me the frames before
     building.
2. **Build it with Flutter built-ins.** Use a custom route or
   `showModalBottomSheet` with a custom transition. No motion package. Durations
   and curves come from `AppMotion`, with a spring through
   `SpringSimulation` if needed.
   - Don't add an app-wide `bottomSheetTheme`; it would restyle the frozen
     Экзамен sheet.
3. **Sheet content** depends on decision 4: a preview of the share card plus
   the share actions.
4. **Share button:** a Bento secondary action on each result screen, placed
   so it doesn't compete with the main "try again / back" action.
5. **Verify on the simulator:**
   - The sheet opens and closes, drag-to-dismiss works, and the system share
     sheet appears.
   - Capture the motion with the screenshot loop and send me a contact sheet.
   - Test in at least two languages (ru + en).

## Verification (same as the design rollout)

- `flutter analyze`: 0 errors, and **no new warnings** against a baseline
  taken at the start. Count lines matching `^ *warning •` and diff them with
  `:line:col` stripped. The count at `3b5148a` is 165 for the whole project,
  153 in `lib/`.
- `flutter test`: everything green. The count at `3b5148a` is 192 tests.
- Simulator screenshots for every screen state. Remove every `// TEMP-…`
  launcher and check with `grep -rn "TEMP-" lib/`. Hot-restart the running app
  afterwards so no temporary buttons stay on screen.
- Vault, same session:
  - `design-implementation-status.md` (result screens, share sheet).
  - `design-patterns.md` (meme slot, share sheet motion).
  - A new article on the meme data (collection, Storage path, rules, seed
    script, licences). Add it to the area `_index.md`.
  - The risk register, if the new rules or the share flow add a risk.

## Done means

- Each of the three result screens shows a meme for its bucket, loaded from
  Firebase on the emulators and cached, with an offline fallback.
- The Share button opens the new sheet with the approved motion and shares
  what I chose.
- Analyzer, tests and the vault are as above. Then report briefly, with
  screenshots, and wait for "commit and push".
