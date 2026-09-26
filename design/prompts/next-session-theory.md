# Next session — Bento on the Теория tab

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`.

---

## Goal

Restyle the **Теория** tab of DriveUSA in the **Bento** direction, which is
already done on the whole Тесты tab. Change **only design, layout, animation
and motion**. Keep every feature, callback, translation key, route, and
class/method/file name. Business logic (providers, services, subscription and
session checks, analytics, Firebase calls) is off-limits. If you find a bug,
tell me and ask before fixing it.

Branch: `security-plus-design`. Everything up to the end of the Тесты tab is
committed and pushed (`e044ca4`, then the Тесты-tab commit on top). **Push
only to `security-plus-design` — never touch `main`.** Do not commit unless I
ask.

## Standing rules from me

- **Do NOT change the Тесты and Экзамен screens.** They are frozen ("they are
  perfect").
- **Stop after every 2 restyled pages** and let me review. Keep the app open
  in the iOS Simulator the whole time.
- **Keep the 3D pictures.** Solar-only cards looked empty. Ask me before
  replacing any raster picture with a glyph.
- **Keep the trial card exactly as it is.**
- **No two-line titles.** On a pushed page, put the page name **beside the
  round back button**, one line, scaled down rather than wrapped
  (`bentoHeadingAppBar` in `lib/widgets/bento_result_parts.dart`). If a name
  is long and adds nothing, drop it (quiz pages have no title at all).

## Read first (in this order)

1. `~/.claude/CLAUDE.md`. State a 1–3 step plan and name the guidelines that
   apply before writing code.
2. Load the `driveusa` skill. Vault conventions: update docs in the same
   session, `file:line` citations, honest Open Questions.
3. Vault: `/Users/demianvyrozub/Desktop/Obsidian/The vault/wiki/driveusa/Development/design system/`
   - **`design-patterns.md`** — the owner rules, the component vocabulary,
     and the refactor recipe. Build from this.
   - `design-tokens.md` — colours and contrast, Rubik and **the lighter
     weight scale**, Solar (how to add an icon), radii, motion.
   - `design-implementation-status.md` — what is migrated, known issues,
     dead code, local environment.
4. Reference code (copy from here, don't reinvent):
   - `lib/widgets/bento_question_parts.dart`: `bentoRoundIconStyle`, round
     app-bar buttons, pill tray, question card, option tile, action buttons,
     explanation card.
   - `lib/widgets/bento_result_parts.dart`: `bentoHeadingAppBar`, verdict
     card, stat tiles.
   - `lib/screens/topic_quiz_screen.dart`: **the closest model for Теория.**
     A list of destinations with 3D pictures (`_TopicCard`: picture left,
     title beside it, count pill bottom-right, lift on press), and the
     heading beside the back button.
   - `lib/screens/saved_items_screen.dart`: expandable cards, the
     empty/error state (`_buildMessage`), the leave motion.
   - `lib/theme/bento_tokens.dart`, `AppColors.shadowCard`, `AppMotion`,
     `StaggerIn`, `PressScale`.
   - Screenshots: `design/screenshots/rollout/{topic-list,topic-quiz,saved,results}/`.

## Screens, in order (stop after each pair)

**Pair 1**

1. **Теория tab** — `lib/screens/theory_screen.dart` and
   `lib/widgets/module_card.dart`.
   - Module cards have an index-cycled pastel gradient
     (`module_card.dart:46-100`: blue/green/orange/purple/teal/indigo/…).
     This is decorative colour and must go. Use white Bento cards.
   - The completion tick is green (`module_card.dart:176`). That is fine
     semantically (done = correct/green). Keep it small and put it beside the
     title, not in its own row.
   - Keep the `onSelect` chain verbatim: session validation, then the
     subscription block dialog (`_showPremiumBlockDialog`), then analytics,
     then the single-topic shortcut straight to content
     (`theory_screen.dart:350-450`).
   - The empty/error state uses grey Material colours (`:293`, `:309`).
2. **Module topics** — `lib/screens/theory_module_screen.dart`.
   - Material `AppBar` with a title (`:160`), blue CircleAvatar numbers
     (`:217`), and a green/blue progress bar (`:249-258`).
   - Keep the auto-redirect for a one-topic module (`pushReplacement`,
     `:139-153`). It is behaviour, not design.

**Pair 2**

3. **Rule content** — `lib/screens/traffic_rule_content_screen.dart` (861
   lines, the long reading page).
   - A **looping title pulse** (`_titleAnimationController.repeat`, `:70`)
     breaks the one-shot motion rule. Remove it (no business effect).
   - Purple/blue gradient section tints (`:232-234`).
   - Keep every **⚠ report button**. There is one per section
     (`_showSectionReportSheet`, `:433`) and one per topic
     (`_showTopicReportSheet`, `:798`). The section one is a 24pt target;
     make it ≥44pt.
   - Keep «Вернуться к теории» (`back_to_theory`, `:765`), the fallback and
     error states, and `_trackContentViewed`.
   - Images inside the text use `AdaptiveQuestionImage`. Its sizing for
     theory diagrams was tuned on purpose (2026-09-20). Do not change it.
   - This is a reading page: body text 16/24 at 400, generous line length,
     section titles 600. No card-in-card.
4. **Topics list** — `lib/screens/traffic_rules_topics_screen.dart`, the
   `/theory` route (`main.dart:693`, `:803`).
   - Check first whether I can reach it in the app today. If it is only a
     fallback route, tell me before spending time on it.
   - Same issues: Material AppBar, blue CircleAvatars (`:177`), grey empty
     state (`:124-141`), and hard-coded Ukrainian sample data (`:23`).
     Leave the data alone.

## Also pending (ask me before each — none is started)

- **Trial card is edge-to-edge on Теория and Профиль**, but inset on Тесты.
  Make the layout consistent; the card's content stays as it is. Теория is
  the natural place to decide this.
- **Tab bar should float over content**: `HomeScreen` passes it as
  `bottomNavigationBar`. Use `extendBody: true` plus bottom padding on the
  three tab screens. This touches the frozen Тесты screen, so ask me.
- **Android edge-to-edge** (risk register #73).
- **Практика number pills are display-only.** Topic quiz and Экзамен jump
  on tap. Should Практика jump too?
- **Reduce Motion pass** over everything migrated so far. It has never been
  checked end to end.
- The **passed** state of the three result pages has never been seen on
  screen.

## My rules (apply to every screen)

- No page titles on tab screens. Pushed screens: a round white back button,
  plus the heading beside it if one is needed.
- Title first, then description, inside every card. No empty rows: an icon
  never sits alone in a row.
- The primary card has the largest card title on the screen.
- Pills: short text, scaled down, never wrapped. Lowercase counts
  («15 вопросов»).
- Nothing scrolls into a rounded edge.
- No decorative arrows. Chevrons appear only in list rows; a tappable card is
  the whole target.
- Check tab screens with the trial card and without it (a paid user sees
  none). Avoid a big empty band in either.
- **Colour means something**: green = correct/done, red = wrong / destructive
  / saved heart, amber = time or access running low, blue = current / action.
  No index-cycled pastels.
- **Weights**:
  - hero 700
  - card titles, section headers, hero pills 600
  - count pills, chips, buttons 500
  - body and answer options 400
  - a question in a list 500
  - Экзамен question text and option keys stay 600
- Hit targets ≥ 44pt; contrast ≥ 4.5:1; tabular figures for numbers.
- Motion only via `AppMotion`, one-shot, and it respects Reduce Motion.
- No new packages without asking. New icons: add Solar names to
  `scripts/icons/solar_icons.txt` and run
  `scripts/icons/build_solar_icons.py` with `picosvg` + `fonttools` from a
  venv **outside the repo** (`.venv` is not git-ignored).
- Avoid new translation keys. A new key goes into all five
  `lib/localization/l10n/*.json` files **and** the inline `_translate` map,
  or `test/localization_coverage_test.dart` fails.

## Per screen

1. **Inventory first**: every control, state, callback and translation key.
   Show me the list. Nothing may disappear; anything moved stays one tap away.
2. Extract inline handlers into private methods **verbatim**, then restyle.
   Don't let `dart format` rewrap code you didn't touch.
3. Take before/after screenshots on the simulator into
   `design/screenshots/rollout/<screen>/`, in Russian. Glance at English.
   Look at every screenshot yourself before sending it.

## Verification (after each screen)

```
flutter analyze lib/ 2>&1 | awk '/^ *error •/{e++} /^ *warning •/{w++} END{print "errors",e+0,"warnings",w+0}'
flutter test
```

- 0 errors, and **no new warnings**. The baseline is **166**; diff the set,
  not only the count.
- **179 tests** pass.

## Local environment (emulators only — never write to live `licenseprepapp`)

```
xcrun simctl boot 'iPhone 16 Pro' || true; open -a Simulator
(cd functions && npm run build)
firebase emulators:start --only auth,firestore,functions,storage,pubsub   # background
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-emulator.js
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 STORAGE_EMULATOR_HOST=http://127.0.0.1:9199 FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-emulator-images.js
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp node scripts/local/grant-local-trial.js design.tester@local.test
flutter run -d 'iPhone 16 Pro' --dart-define=USE_EMULATOR=true --pid-file /private/tmp/claude-501/dv/flutter.pid   # background
```

- Emulator data is in memory. After the emulators restart, recreate the
  account (see `design/prompts/next-session-variants-refactor.md`, Step 4,
  item 5), then grant the trial.
- Test account: `design.tester@local.test` / `DesignTest2026!` (Illinois, ru).
  Emulator only.
- Hot reload: `kill -USR1 $(cat /private/tmp/claude-501/dv/flutter.pid)`.
  Hot restart: `-USR2`.
- A font or `pubspec.yaml` change needs a full `flutter run`. Wait for
  "Flutter run key commands" from the *new* process before screenshotting.
- Type into the simulator in **3-character chunks**; bulk typing gets
  swallowed.
- To see the paid-user layout (no trial card), temporarily swap
  `TrialStatusWidget()` for `const SizedBox.shrink()` for one screenshot,
  then restore the file.
- Check the Simulator's Reduce Motion setting before judging any animation.

## Hand-off

For each screen, report:

- what changed
- the inventory tick-off
- analyzer and test numbers
- anything not done, and why

Update the vault in the same session: `design-implementation-status.md`, and
`design-patterns.md` for any new pattern or rule I give. Don't commit unless
I ask. Never commit `.agents/` or `skills-lock.json`.
