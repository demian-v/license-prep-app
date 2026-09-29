# Next session: add Инструкторы to the onboarding

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`, once the Инструкторы tab has
real content.

---

## Goal

The first-run onboarding tours the app through **screenshot steps**: real
screenshots, dimmed, with one element and its tab lifted out and a white ring
around it. Инструкторы was left out on 2026-09-29 because the tab was an empty
placeholder and will get **its own onboarding** inside the tab. Now that the
screen exists, add **one** Инструкторы step to the first-run onboarding: its
tab plus the single most useful element. It's a pointer to the tab, not a
second tour. The tab's own onboarding stays separate.

Branch: `security-plus-design`. Don't commit or push unless I ask. Never touch
`main`. Never commit `.agents/` or `skills-lock.json`.

## Read first

1. `~/.claude/CLAUDE.md`. State a short plan and name the guidelines that
   apply before writing anything.
2. Load the `driveusa` skill and follow its vault conventions. Design rules
   are in the vault: `wiki/driveusa/Development/design system/design-patterns.md`.
3. The Flutter onboarding:
   - `lib/screens/onboarding_screen.dart`: `_steps()` (the step list),
     `OnboardingGate` (the per-device "seen" flag), the stage, the Next bar.
   - `lib/widgets/onboarding_shots.dart`: **generated** rects per locale. Don't
     edit it by hand.
   - `lib/widgets/onboarding_greeting_art.dart`: the greeting drawing.
   - `lib/screens/home_screen.dart`: shows the onboarding over Home on first open.
   - `test/onboarding_flow_test.dart`: flow, per-locale and asset guards.
   - `assets/images/onboarding/<locale>/<screen>.webp`, declared per folder in `pubspec.yaml`.
4. The tools and the prototype:
   - `design/onboarding/_src/export_onboarding_assets.py`: stitches the raw
     captures without the trial card, finds cards and the tab bead from the
     pixels, and writes the WebPs plus `onboarding_shots.dart`.
   - `design/onboarding/_src/compose_shots.py`: the stitching it uses.
   - `design/onboarding/driveusa-onboarding.html`: the prototype (open it via
     the `design-pages` preview server at
     `http://localhost:8765/onboarding/driveusa-onboarding.html`). Its source is
     `_src/onboarding.template.html`, rebuilt with `_src/build.py`.

## Decisions already made (don't re-open)

- Flow: one Line-style greeting card (a line car saying «Привет!» from a blue
  bubble, a «Начнём» pill), then screenshot steps. No live app until
  «Начать», so the cache loads meanwhile. It shows the first time Home opens
  and warms Theory in the background.
- **No trial card** on any onboarding screenshot.
- Steps follow tab order: Тесты (tab, exam, topics+tickets, mistakes) →
  Теория (first module) → **Инструкторы (new, here)** → Профиль (language + state).
- Navigation: a round Next button that springs dot to dot. Back is the app's
  round white disc (`bentoRoundIconStyle`) top-left from step 2, and
  «Пропустить» is top-right. A new screen swaps the screenshot card sideways.
- Screenshots are real iPhone 16 Pro simulator captures, one set per locale
  (en, es, pl, ru, uk).

## Steps

1. **Run the app** on the iPhone 16 Pro simulator against the local emulators
   (`--dart-define=USE_EMULATOR=true`, see the vault's simulator recipes).
   Override the status bar first:
   `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode notSupported`
2. **Capture, per locale**, into a scratch folder `RAW/<locale>/`: the
   existing six (`tests`, `tests_s`, `theory`, `theory_s`, `profile`,
   `profile_s`; `_s` = scrolled down) plus `instructors.png` and
   `instructors_s.png`. Use `xcrun simctl io booted screenshot`. Switch the
   language in Профиль → «Выбрать язык» between sets. Switch back to the
   account's language and clear the status-bar override afterwards.
3. **Ask me** which element to highlight (for example the first instructor
   card, or the search/filter). Suggest one, with a screenshot.
4. **Teach the exporter the new screen**, in `export_onboarding_assets.py`:
   - add `'instructors'` to the screen loop;
   - add a `pick()` branch that returns the chosen card by kind and order,
     under a key such as `'card'`.
   The tab rect comes from the bead automatically.
   Run `python3 design/onboarding/_src/export_onboarding_assets.py RAW`, then
   look at every `RAW/<locale>/check_instructors.png`: the red boxes must sit
   exactly on the card and the tab.
5. **Add the step** in `lib/screens/onboarding_screen.dart`:
   - a `_Step(... screen: 'instructors', element: '<key>')` in `_steps()`,
     between Теория and Профиль. The dots follow the list length;
   - `'instructors'` in the `precacheImage` list in `didChangeDependencies`.
   Add `'instructors.tab'` and `'instructors.<key>'` to the `keys` list in
   `test/onboarding_flow_test.dart`, add `instructors` to its image check, and
   add the new body text to the walk in the flow test.
6. **Copy** for the new step in all five `lib/localization/l10n/*.json`
   (`onboarding_instructors_title` / `_body`). Keep it short, in the same tone
   as the other steps, and pass the keys to `translate('…')` as literals, or
   `localization_coverage_test` won't check them.
7. **Verify**:
   - the analyzer shows no new warnings against a baseline taken first;
   - the full `flutter test` passes;
   - play it on the simulator: clear the seen flag through the preferences
     daemon (editing the plist file directly gets overwritten by its cache):
     `xcrun simctl spawn booted defaults delete "$(xcrun simctl get_app_container booted com.driveusa.app data)/Library/Preferences/com.driveusa.app" flutter.onboarding_seen_v1`,
     then hot-restart;
   - step through forward and «Назад», and show me screenshots.
8. **Prototype and vault**: add the step to the prototype too
   (`onboarding.template.html`: `STEPS`, `TAB_R[2]`, `EL_R`, `EL_RU`, remove
   the grey placeholder row, which is the `i===5` branch in the `#rows`
   builder). Update the vault design docs if I ask.
