# Next session — roll the Bento design out to the rest of the app

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`.

---

## Goal

Restyle the remaining screens of DriveUSA in the **Bento** direction built and
approved on 2026-09-26 for Тесты, Экзамен and the tab bar. Change **only
design, layout, animation and motion**. Keep every feature, callback,
translation key, route, and class/method/file name. Business logic (providers,
services, the subscription state machine, Firebase calls) is off-limits.

Branch: `security-plus-design` (already checked out). **Nothing is committed
yet** — do not commit or push unless I ask.

Work **one screen at a time**: restyle it, show me before/after screenshots,
wait for my feedback, apply it, then move to the next. I review on the
simulator and usually send screenshots with arrows; expect several small
rounds per screen.

## Read first (in this order)

1. `~/.claude/CLAUDE.md` — state a 1–3 step plan and name the guidelines that
   apply before writing code.
2. Load the `driveusa` skill (vault conventions: update docs in the same
   session, `file:line` citations, honest Open Questions).
3. Vault: `/Users/demianvyrozub/Desktop/Obsidian/The vault/wiki/driveusa/Development/design system/`
   - **`design-patterns.md` — the Bento vocabulary, my review rules, and the
     refactor recipe. Build from this.**
   - `design-tokens.md` — colours and measured contrast, Rubik, Solar (incl.
     how to add an icon to the icon font), radii, motion.
   - `design-implementation-status.md` — what is migrated, what is not, known
     issues, dead code, local environment.
4. Reference implementations — copy the pattern from here:
   - `lib/widgets/enhanced_test_card.dart` — `_buildBentoHero` (`:759`),
     `_buildBentoTile` (`:899`), `_buildBentoSaved` (`:970`)
   - `lib/screens/exam_question_screen.dart` — every `DesignVariant.bento`
     case: round app-bar buttons (`_buildAppBar` `:364`), pill tray, question
     card, option cards with ✓/✕ (`:1197`), pill buttons, exit dialog
   - `lib/widgets/trial_status_widget.dart` — Bento status row (`:193`)
   - `lib/widgets/super_enhanced_footer.dart` — the meniscus tab bar
   - Screenshots: `design/screenshots/variants/bento/` (01–04 and 10 are
     current; 05–09, 11–12 predate the last tweaks), `design/screenshots/rubik/`

## Step 0 — ask me these before anything else

1. **Make Bento the default?** `lib/theme/design_variant.dart:38` initialises
   `designVariant` to `DesignVariant.refined`, so a release build currently
   shows Refined. Propose `DesignVariant.bento`.
2. **Delete the Refined, Signal and Ledger variants?** Kept on purpose while
   choosing. Do not delete without a yes.
3. **Rubik weights** — keep, or one step lighter (800 → 700, 600 → 500)?
4. **Retired files** — delete `assets/fonts/Manrope.ttf`, `Roboto-*.ttf`,
   `assets/icons/bookmark-simple*.svg`?

New screens are built **in Bento only** (no four-variant switcher), reading
tokens directly.

## My rules (apply to every screen)

- **No page titles on tab screens.** Pushed screens keep an app bar with a
  back button — round white icon buttons, Bento style.
- **Title first, then description** inside every card.
- **No empty rows.** An icon must not sit alone leaving blank space; put it in
  the count pill or beside the title.
- **The primary card has the largest card title** on the screen.
- **Short pill text** («100+ вопросов», not «100+ вопросов по темах»); a long
  translation scales down, never wraps.
- **Nothing scrolls into a rounded edge** — inset and fade.
- **No decorative arrows**: none inside buttons, and no chevron or arrow disc
  on tappable cards — the whole card is the target. Chevrons only in list rows.
- **Check tab screens in both subscription states** — with the trial card and
  without it (a paid user sees none). Avoid a big empty band in either.
- **Keep the trial card as it is.** Do not remove or restyle its content.
- **Colour is never decoration**: green = correct, red = wrong / destructive /
  saved heart, amber = time or access running low, blue = current / action.
  Remove every index-cycled pastel wash and decorative green.
- Hit targets ≥ 44pt; text contrast ≥ 4.5:1 (`inkTertiary` is not a text
  colour); tabular figures for numbers; motion via `AppMotion`, one-shot,
  respects Reduce Motion.
- **No new packages** without asking me. Icons: add Solar names to
  `scripts/icons/solar_icons.txt` and run `scripts/icons/build_solar_icons.py`
  (needs `picosvg` + `fonttools` in a local venv).
- **Translation keys**: add none if you can avoid it; a new key goes into all
  five `lib/localization/l10n/*.json` files **and** the inline `_translate`
  map, or `test/localization_coverage_test.dart` fails.

## Order of work

1. **Обучение по темам** — `lib/screens/topic_quiz_screen.dart` (topic list and
   quiz). Highest priority: raster topic clipart, a hairline-flanked
   «Вопросы сгруппированы по темам» divider, and answer options still tinted
   by index (the decorative/semantic colour collision). Reuse the Экзамен
   option and verdict pattern, including ✓/✕.
2. `practice_question_screen.dart`, `quiz_question_screen.dart` — same
   collision.
3. **Теория** — `theory_screen.dart` cards, `theory_module_screen.dart`,
   `traffic_rules_topics_screen.dart`, `traffic_rule_content_screen.dart`.
4. **Профиль** — `profile_screen.dart`, `widgets/enhanced_profile_card.dart`:
   replace raster clipart with Solar in `signal50` discs; the green
   «Русский» / «Активна» subtitles come from a per-index colour cycle
   (`enhanced_profile_card.dart:87`) and must become neutral.
5. Result screens — `exam_result_screen.dart`, `quiz_result_screen.dart`,
   `practice_result_screen.dart`. A score of 0 shows a gold trophy: raise it
   as a product question, do not change behaviour silently.
6. Paywall — `subscription_screen.dart`: the Upgrade CTA is still a cream
   button; make it the primary blue pill.
7. `saved_items_screen.dart`, `support_screen.dart`, `widgets/report_sheet.dart`,
   `widgets/premium_block_dialog.dart`, `personal_info_screen.dart`.
8. Auth funnel: login, signup, forgot/reset password, verification code,
   email verification.

Also pending:

- **Trial card** is edge-to-edge on Теория and Профиль but inset on Тесты —
  make the layout consistent (the card's content stays as it is).
- **Tab bar should float over content**: `HomeScreen` passes it as
  `bottomNavigationBar`, so content is cut by a flat band; use
  `extendBody: true` and bottom padding on the tab screens.
- **Android edge-to-edge** (risk register #73): no `SystemChrome` anywhere;
  the register says to do it during the design phase.
- `_bentoShadow` is duplicated in `enhanced_test_card.dart` and
  `exam_question_screen.dart:345` — promote it to `AppColors` once a third
  screen needs it.

## Per screen

1. **Inventory first** — every control, state, callback and translation key.
   Show me the list. Nothing may disappear; anything moved stays one tap away.
   (Functionality was nearly dropped twice before: the ⚠ report button and the
   save heart.)
2. Extract inline handlers into private methods **verbatim**, then restyle.
3. Screenshot before and after on the simulator into
   `design/screenshots/rollout/<screen>/`, in Russian (the longest strings);
   glance at English. Look at every screenshot yourself before sending.

## Verification (after each screen and at the end)

```
flutter analyze lib/ 2>&1 | awk '/^ *error •/{e++} /^ *warning •/{w++} END{print "errors",e+0,"warnings",w+0}'
flutter test
```

- 0 errors; **no new warnings** (baseline 177 — diff the set, not only the
  count); all 176 tests pass.
- Simulator: every state of the screen; Reduce Motion once at the end.
  **The Simulator was left with Reduce Motion ON** — turn it off first
  (Settings → Accessibility → Motion) unless testing it.

## Local environment (emulators only — never write to live `licenseprepapp`)

```
xcrun simctl boot 'iPhone 16 Pro' || true; open -a Simulator
(cd functions && npm run build)
firebase emulators:start --only auth,firestore,functions,storage,pubsub   # background
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-emulator.js
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 STORAGE_EMULATOR_HOST=http://127.0.0.1:9199 FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-emulator-images.js
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp node scripts/local/grant-local-trial.js design.tester@local.test
flutter run -d 'iPhone 16 Pro' --dart-define=USE_EMULATOR=true   # background
```

- Emulator data is in-memory: if the emulators were stopped, recreate the
  account (see `design/prompts/next-session-variants-refactor.md`, Step 4,
  item 5).
- Test account: `design.tester@local.test` / `DesignTest2026!` — emulator only.
- Type into the simulator in **3-character chunks**; bulk typing is swallowed.
- A font or `pubspec.yaml` change needs a **full** `flutter run`, not a hot
  restart. After restarting `flutter run`, wait for "Flutter run key
  commands" from the *new* process before screenshotting.
- The debug switcher tab (right edge, mid-screen) cycles variants; long-press
  it for the 4:59 / 0:59 timer preview. Keep it on **Bento**.
- To see the paid-user layout (trial card hidden), temporarily swap
  `TrialStatusWidget()` for `const SizedBox.shrink()` for one screenshot, then
  restore the file.

## Hand-off

Per screen: what changed, the inventory tick-off, analyzer/test numbers, and
anything not done and why. Update the vault in the same session
(`design-implementation-status.md`, and `design-patterns.md` for any new
pattern or rule I give). Don't commit.
