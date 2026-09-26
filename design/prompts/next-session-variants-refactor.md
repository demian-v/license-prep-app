# Next session — Тесты + Экзамен: design & motion refactor, 3 live variants

> **Done 2026-09-26.** Kept for its setup steps (emulator account creation).
> The current brief is [next-session-rollout.md](next-session-rollout.md).

Paste everything below the line into a fresh Claude Code session opened in
`/Users/demianvyrozub/projects/license-prep-app`.

---

## Goal

Refactor the **design and motion** of the two screens already migrated to the new
design system — **Тесты** (`lib/screens/test_screen.dart`) and **Экзамен**
(`lib/screens/exam_question_screen.dart`) — and build **three variants** of each that I
can flip between **live on the iOS Simulator** through a debug-only switcher. I will
pick a winner afterwards; do not pick for me and do not delete the losers.

**Change ONLY design, layout, animation and motion.** Keep every feature, every
callback, every translation key, every route, every class/method/file name. Business
logic (providers, services, subscription state machine, Firebase calls) is off-limits.

Branch: `security-plus-design` (already checked out). **Do not commit or push unless I
ask.**

## Read first (in this order)

1. `~/.claude/CLAUDE.md` — state a 1–3 step plan and name the guidelines that apply
   before writing code.
2. Vault design docs — `/Users/demianvyrozub/Desktop/Obsidian/The vault/wiki/driveusa/Development/design system/`
   - `_index.md`, `design-tokens.md`, `design-audit.md`, `design-implementation-status.md`
3. The token layer — `lib/theme/app_colors.dart`, `app_typography.dart`,
   `app_spacing.dart`, `app_motion.dart`, `app_icons.dart`, `app_theme.dart`
   (note: `app_icons.dart` is **not** re-exported by `app_theme.dart`; import it).
4. The two screens and the widgets they use:
   `lib/widgets/enhanced_test_card.dart`, `trial_status_widget.dart`,
   `animated_exam_timer.dart`, `adaptive_question_image.dart`,
   `super_enhanced_footer.dart` (the LIVE tab bar — `enhanced_bottom_navigation.dart`
   and `bottom_navigation.dart` are dead code; don't use them, don't delete them).
5. Screenshots: `design/screenshots/before/` (old UI) and `design/screenshots/after/`
   (current direction A). Look at them before designing anything.

## Skills and references (installed globally)

Load the ones you use via the Skill tool — don't just name them.

| Skill | Use it for |
|---|---|
| `redesign-existing-projects` | Primary skill — audit-then-upgrade of an existing UI without breaking it |
| `design-taste-frontend` | Anti-slop rules: spacing rhythm, hierarchy, no generic AI look |
| `high-end-visual-design` | Bolder variant — premium depth, typography, motion polish |
| `minimalist-ui` | Refine variant — restraint, editorial whitespace |
| `industrial-brutalist-ui` | Only if a bolder variant goes that way — use sparingly |
| `frontend-design` (Anthropic) | Distinctive, non-default aesthetic choices |
| `web-design-guidelines` (Vercel) | Accessibility / interaction checklist (translate web rules to Flutter: hit targets ≥44pt, focus, contrast, reduced motion) |
| `imagegen-frontend-mobile`, `image-to-code` | Optional: generate a mockup first, then translate it to Flutter |
| `brandkit`, `stitch-design-taste`, `gpt-taste` | Optional extra taste references |

Reference design systems (MIT, 74 DESIGN.md files):
`~/.claude/design-references/awesome-design-md/design-md/`. Mobile-relevant ones to
study for the bolder variants: `revolut`, `wise`, `linear.app`, `apple`, `airbnb`,
`uber`, `spotify`, `stripe`, `notion`, `raycast`, `figma`. Borrow **principles**
(density, type scale, motion character), never their brand colours or logos.

These skills are web-first (React/Tailwind). Translate their principles to Flutter;
don't add web dependencies.

## Non-negotiable constraints (all variants)

- Brand: signal blue **`#0048C3`** + white stay. Other hues only through the existing
  semantic tokens.
- **Semantic colour rule:** green (`guide`) = correct only; red (`stop`) = wrong /
  destructive / saved-heart; amber (`warn`) = time or access running low; blue
  (`signal`) = current / primary action. Decorative colour must never collide with
  those meanings.
- Material 3 `surfaceTint` stays transparent (no lavender tint).
- Font: Manrope (variable, Cyrillic). Test copy in **Russian** — it's the longest
  common string length; check nothing truncates or wraps badly. Also glance at
  English.
- Numbers (timer, question counter, pills) keep tabular figures.
- Radius by role: cards 16, buttons 12, chips 8, floating tab bar 24 — a variant may
  change the scale, but consistently through tokens, never ad-hoc numbers.
- Motion goes through `AppMotion` tokens and respects reduce-motion
  (`AppMotion.duration(context, …)` / `MediaQuery.maybeDisableAnimationsOf`). No
  perpetual looping animations (the old pulsing timer was removed on purpose).
- Hit targets ≥ 44pt. Contrast ≥ 4.5:1 for text.
- Don't introduce new packages without asking me first (`flutter_animate` or similar
  would be a reasonable ask — ask, don't assume).

## Step 1 — Inventory before touching anything

Write a checklist of **every** control and state on both screens and keep it at the top
of your work. Every variant must pass all of it. At minimum:

**Тесты:** screen title; `TrialStatusWidget` (all states: loading, active trial,
urgent ≤1 day, expired trial, expired paid, no subscription / unverified email — each
with its action button); exam card (blue, chips: questions / time / pass mark);
«По темам» and «Практика» two-up tiles with question counts; saved-questions row;
section headers; floating tab bar (4 tabs, outline/filled icons, labels); the
forward page transition into the exam.

**Экзамен:** AppBar back/exit (with the exit-confirmation dialog); **⚠ report**
button (opens the report sheet, tooltip `report_issue`); **♡ save** toggle (red when
saved); timer (ink → amber ≤ 5:00 → red ≤ 1:00); question-number pill strip —
fill states (current / correct / wrong / unseen), **tap-to-jump** (`_jumpToQuestion`)
and auto-scroll to the current pill; «Вопрос N из 40» chip; question text; question
image (180pt frame, tap → full-screen pinch-zoom, close button); answer options
(idle / selected / correct / wrong / disabled after check); explanation block after
checking; bottom actions (skip / choose / next — whatever the current labels are);
exam results navigation at the end.

If a variant would hide or move a control, it still has to be reachable in one tap.

## Step 2 — Build the debug-only variant switcher

- One small file, e.g. `lib/theme/design_variant.dart`: an enum
  `DesignVariant { refined, boldA, boldB }` and a global `ValueNotifier<DesignVariant>`.
- The switcher UI exists **only in debug builds** (`kDebugMode`). Suggested: a small
  floating chip in a corner of both screens (or long-press on the screen title) that
  cycles variants, showing the current one's name. It must not appear in release/profile
  builds — verify by reading the code path, and note it.
- Screens read the notifier (`ValueListenableBuilder`) and choose a variant builder.
  Keep all variants inside the existing files as private builder methods / private
  widgets, so names and public APIs don't change. Shared logic stays shared — variants
  differ in presentation only.
- Persisting the choice across hot restarts is nice-to-have (SharedPreferences is
  already a dependency — check before using), not required.

## Step 3 — The three variants

**Variant 1 — Refined A** (evolution, lowest risk). Keep direction A and polish:
spacing rhythm on a strict 4/8 grid, type hierarchy (fewer weights, clearer steps),
optical alignment, hairline/shadow consistency, better empty space above the fold,
and **motion**: staggered entrance of cards on Тесты (≤ 240ms total, subtle
translate + fade), press states that scale ~0.98 with `AppMotion.press`, pill strip
current-pill transition, answer-selection feedback (border/fill animates, not snaps),
correct/wrong reveal, explanation expanding in, question-to-question transition
(shared-axis horizontal), timer colour change animated.

**Variant 2 — Bolder (confident / premium).** Draw on `high-end-visual-design` +
revolut / wise / apple references. E.g. a large display-weight hero for the exam card,
stronger scale contrast, a more expressive progress treatment on Экзамен (progress
bar or segmented track in addition to — not instead of — the pill jump), springier
but still short motion, richer depth on the primary card. Brand blue stays the hero.

**Variant 3 — Bolder (dense / focused / editorial).** Draw on `linear.app` / raycast /
`minimalist-ui`. E.g. near-monochrome ink-on-paper with blue only for action and
current state, tighter information density, list-first Тесты, a distraction-free
exam mode (chrome recedes while reading, returns on interaction), crisp fast motion
(≤ 180ms, no bounce).

These are starting points — use your judgement and the skills, but each variant must
be **visibly different** from the others at a glance, not three tweaks of padding.
Before coding each variant, write 3–5 lines describing its idea, type scale and motion
character, and show them to me.

## Step 4 — Open the app on the iOS Simulator (all steps)

Emulator data is **in-memory**: after emulators stop, the account, trial and content
are gone and must be recreated. The app uses the single real Firebase project id
`licenseprepapp`, but with `USE_EMULATOR=true` it talks only to local emulators.
**Never write to the live `licenseprepapp` project.**

```bash
# 0. Tooling sanity
flutter --version && xcrun simctl list devices | grep -i "iPhone 16 Pro"

# 1. Boot the simulator and open the live panel (use the iOS Simulator MCP 'attach')
xcrun simctl boot 'iPhone 16 Pro' || true   # "already booted" is fine
open -a Simulator

# 2. Build functions once if functions/lib is missing or stale
(cd functions && npm run build)

# 3. Start emulators — run in the background (Bash run_in_background), not foreground
firebase emulators:start --only auth,firestore,functions,storage,pubsub
#    wait until "All emulators ready" (UI on http://127.0.0.1:4000)

# 4. Seed content + images
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp \
  node scripts/local/seed-emulator.js
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 STORAGE_EMULATOR_HOST=http://127.0.0.1:9199 \
  FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 GCLOUD_PROJECT=licenseprepapp \
  node scripts/local/seed-emulator-images.js

# 5. Create the local test account (emulator only)
curl -s -X POST "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake" \
  -H 'Content-Type: application/json' \
  -d '{"email":"design.tester@local.test","password":"DesignTest2026!","returnSecureToken":true}'
#    The provisionUserDocument auth trigger creates users/{uid}. Then, with firebase-admin
#    against the emulators (FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST set,
#    GCLOUD_PROJECT=licenseprepapp):
#      - merge into users/{uid}: { language: 'ru', state: 'IL', name: 'Design Tester' }
#      - admin.auth().updateUser(uid, { emailVerified: true })

# 6. Grant a local 3-day trial (creates a new subscription doc each run)
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp \
  node scripts/local/grant-local-trial.js design.tester@local.test

# 7. Build and install — ALWAYS clean-reinstall so you never screenshot a stale binary
flutter build ios --simulator --debug --dart-define=USE_EMULATOR=true
xcrun simctl uninstall booted com.driveusa.app
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.driveusa.app

# 8. Log in through the UI with the account from step 5
#    (402×874pt: email field ≈ (200,410), password ≈ (200,475), «Войти/Log In» ≈ (200,600)).
#    Type OTP / short fields digit by digit — bulk typing gets swallowed.
```

For fast iteration prefer `flutter run -d 'iPhone 16 Pro' --dart-define=USE_EMULATOR=true`
in a background shell and hot-reload (`r`) / hot-restart (`R`) — but when taking
screenshots for comparison, confirm the build timestamp is newer than your last edit.

Known gotchas: a cached session can show a stale "trial expired" → clean reinstall;
image questions are only ~9% of the bank — «Дорожные знаки и разметка» topic has them,
or use the pill jump in the exam to find one.

## Step 5 — Verify every variant

- `flutter analyze lib/` → **0 errors**, and **no more than 177 warnings**. Count with
  awk — `grep -E '^\s+(error|warning)'` silently matches nothing:
  ```bash
  flutter analyze lib/ 2>&1 | awk '/^ *error •/{e++} /^ *warning •/{w++} END{print "errors",e+0,"warnings",w+0}'
  ```
  (check the output format first and adapt the pattern if it differs).
- `flutter test` → all **176** tests pass (includes `test/localization_coverage_test.dart`
  — every new `translate('…')` key must exist in all five locale files; better: add no
  new keys).
- On the simulator, for **each variant**: screenshot Тесты, Экзамен with a text-only
  question, an image question, a selected answer, a checked-correct and a
  checked-wrong answer with explanation, the timer in amber, the report sheet, the
  saved heart, and the exit dialog. Save to
  `design/screenshots/variants/<variant>/`. Look at every screenshot yourself.
- Run through the Step 1 inventory per variant and tick it off in your report.
- Turn on Reduce Motion (Simulator → Settings → Accessibility → Motion) once and confirm
  animations collapse to instant.

## Step 6 — Hand-off

Report: what each variant is (one paragraph + key screenshots), the inventory result,
analyzer/test numbers, anything you couldn't do and why, and pre-existing dead code
you noticed (mention, don't delete). Then ask me which variant wins. Update the vault
docs only after I choose (and only when I ask). Don't commit.
