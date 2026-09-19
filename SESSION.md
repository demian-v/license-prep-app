# Local Hardening Session — security & money path

## STATUS AT A GLANCE — read this first

| | |
|---|---|
| **Branch** | `local/security-money-hardening` (base `84300d0`) — **pushed to `origin` 2026-09-16 at the owner's request.** `main` untouched, nothing deployed |
| **Commits** | 94 |
| **Tests** | 255 Cloud Functions (Jest, 27 suites, **serial** — see Gotchas) + **115 Dart, all green** (Jest is now 294 across 29 suites). The 6 long-standing `counter_service_test.dart` failures are **fixed** (#17, 2026-09-17) — the tree has no red tests for the first time |
| **Analyzer** | 0 errors |
| **Register rows addressed** | 48 of 59 (#10 #17 #28 #42 closed 2026-09-17; #39 re-opened and properly closed) |
| **Deployed?** | **NO, and deliberately held.** Owner's decision 2026-09-18: more Android testing and fixes first. See *The deploy gate* below — it is pre-flighted and ready, waiting only on the owner |

**Risks fixed on this branch:** #2 #3 #4 #5 #6 #7 #8 #10 #11 #12 #13 #14 #15 #16 #17 #18 #19 #20 #22 #23 #24 #25 #27 #29 #30 #32 #34 #28 #38 #39 #40 #41 #42 #43 #45 #46 #47 #48 #50 #51 #52 #54 #58 #59
**Partial, with reasons below:** #9 (no reconciliation job) · #21 (no sync built) · #26 (needs attestation) · #35 (no mail transport exists) · #49 (Artifact Registry migration is an owner action)

**Biggest open question:** none of this protects anyone until it ships. Everything below is verified locally and nothing has ever run in production.

### THE DEPLOY GATE — read before releasing anything

**Held by the owner on 2026-09-18**, to allow Android testing and further
fixes first. Nothing is blocking it technically; this is a timing decision, and
the pre-flight below was run and passed on 2026-09-17.

**The order is forced, and this is the part not to get wrong.** The new client
calls `sendEmailVerificationCode`, `verifyEmailCode` and
`getEmailVerificationStatus`, none of which exist in production. **Ship the app
before the functions and signup breaks for every new user.** So:

```
functions deploy  ->  app store submission  ->  hosting deploy
     (+ firestore:rules — a FOURTH deploy, no ordering constraint)
```

Never the other way round — and note where **hosting** sits, which is the
opposite end from functions.

**Do NOT deploy hosting early, even though it looks like the safe half.**
Verified against the published build `84300d0` on 2026-09-18:

- the live 1.0.5 app **already registers** `driveusa://resetPassword` (and the
  `email-verified` hosts) in both `AndroidManifest.xml` and `Info.plist`
- it already extracts `oobCode` in `onGenerateRoute` and calls
  `ActionCodeRouter.determineRoute(oobCode)` — but the **one-argument** form,
  without this branch's URL fallback
- and `firebase_auth` was observed returning
  `ActionCodeInfoOperation.unknown` for a *valid* reset code, which in the
  published router's `default:` branch returns `route: '/profile'`
  (`action_code_router.dart:80`)

So today the old page's `licenseprep://` links open nothing, every user falls
through to entering the code by hand, and that works. Deploy the fixed page
ahead of the app and the link *would* open the installed app — and land it on
the **profile screen**. A working manual path replaced by a silent dead end is
a regression, caused by deploying a fix. The URL fallback that saves it
(`typeFromUrl`) only exists in the new client.

Hosting is therefore gated on the app release, not on the functions deploy.
This also means Android checklist **§4d cannot be unblocked early** by a
hosting-only deploy.

#### Pre-flight, verified 2026-09-17

| Check | State |
|---|---|
| `APPLE_APP_ID` in `functions/.env.licenseprepapp` | ✅ real 10-digit id, **not** the dangerous `0` |
| `APPLE_SHARED_SECRET`, `GOOGLE_CREDENTIALS`, `RESEND_API_KEY` | ✅ all three present and ENABLED in Secret Manager |
| `predeploy` compiles TypeScript | ✅ (risk #16 — without it the deploy ships months-old JS) |
| Tests | ✅ **351 Jest / 157 Dart**, all green — and enforced by CI since 2026-09-19 |
| Deploy surface unchanged by the #56 backend work | ✅ zero new `export const` in `index.ts`, so the 6 deletions / 6 creations below still hold |

#### The fourth deploy: security rules

`firebase deploy --only functions` does **not** ship security rules, and
`firestore.rules` changed on 2026-09-19 (E2): the per-user report counter can
no longer be rewound by its owner, which is how a user could silently overwrite
their own past reports. Without this command it never reaches production:

```
firebase deploy --only firestore:rules
```

**No ordering constraint, unlike hosting.** Verified against `main`: the live
1.0.5 client writes the identical `{value, lastUpdated, userId}` with
`merge: true` and always increments by one, so the tightened rule accepts
everything the shipped app already does. Before, during or after the rest is
all fine.

#### What the deploy will do

**Deletes 6 functions**, which is the point:

| Function | Why |
|---|---|
| `handleMockPaymentWebhook` | unauthenticated payment endpoint — **Critical #4** |
| `generateSubscriptionTestData`, `createQuickSubscriptionTest`, `verifySubscriptionTestData`, `cleanupSubscriptionTestData` | test-data tooling live in production — **Critical #4** |
| `upgradeSubscription` | granted a free 365 days with no audit row — **High #2** |

**Creates 6:** `sendEmailVerificationCode`, `verifyEmailCode`,
`getEmailVerificationStatus`, `provisionUserDocument`, `getContentVersion`,
`cleanupExpiredRecords`.

Run it as `firebase deploy --only functions --project licenseprepapp`.
**Never `--force`** — the deletion prompt must be answered deliberately.

#### Two things WILL change for the app already in the store

The store build is the old client and will run against the new server until the
next release clears review. Both are traced, both are non-destructive, and both
resolve when the app ships. **Two, still — the #56 receipt work adds nothing
here.** The shipped iOS build sends base64 app receipts, `usesStoreKit2` returns
false for them, and they take the identical code path they take today: the
`receipt-data` body, `verifyReceipt`, the same production-then-21007 dance. The
new branch is unreachable for every client currently installed. That is the
whole point of the conservative default.

1. **The "Upgrade" button will error.** `enhanced_subscription_card.dart:1495`
   on `main` calls `upgradeSubscription`, which is being deleted. Today that
   button hands out a free year, so this closes a revenue hole and the cost is
   an error message.
2. **Unentitled users lose content and see a confusing message.** #3 makes
   content callables require entitlement — correct — but the friendly
   "Subscription required" screen is client-side and unshipped, so the old app
   shows *"No theory modules found for state ILLINOIS with your current
   language settings"*, blaming state and language for a paywall.

#### Not included in a functions deploy

`--only functions` does **not** deploy security rules. #3's rules half and #29
stay un-deployed, so direct Firestore content reads remain open under the old
rules. Rules are a separate, riskier step — a bad rule locks users out — so do
functions first, confirm production is healthy, then rules on their own.

`firestore:indexes` was already deployed on 2026-09-17.

### 2026-09-17, second session — what happened

The four-item plan below was worked through. Outcome, then what is left.

#### 0. Safety check — PASSED

`flutter test test/no_crash_test_scaffolding_test.dart` was green at the start,
and is green now. The temporary crash override **was** re-applied during this
session to test Crashlytics on the simulator, and **has been reverted**:
`git diff lib/main.dart` against its commit is empty, the guard is 5/5, and the
crash-test build was uninstalled from the simulator so it cannot fire again.

#### 1. Crashlytics — DONE, and verified end to end

Custom keys, breadcrumbs, non-fatal `recordError`, and `setUserIdentifier`
(owner-approved 2026-09-17). Commit `2f3a6e8`.

**A real crash was fired and the report inspected.** Not "it should work" — the
report was read off disk in the simulator's Crashlytics store before it was
consumed:

| On the report | Value |
|---|---|
| `state` | `IL` |
| `language` | `en` |
| `subscription_status` | `trial/inactive` |
| `entitled` | `false` |
| `com.crashlytics.user-id` | the test account's real uid |
| breadcrumbs | `auth: signed in`, `nav: push /`, plus Analytics' own |
| exception | `FirebaseCrashlyticsTestCrash` |

`subscription_status: trial/inactive` next to `entitled: false` is the
status-vs-entitlement split doing its job. The report then left `active/` with
nothing in `prepared/` or `processing/`, which is the queue draining.

**Automatic dSYM upload — VERIFIED 2026-09-18, and it was already built.** The
`[Crashlytics] Upload dSYMs` build phase exists (`project.pbxproj:365`) with
`alwaysOutOfDate = 1`, so it runs on every build; it had simply never been
*exercised*, because its guard exits early on simulator builds and that is all
we had done. A device-targeted release build — `flutter build ios --release
--no-codesign`, no certificate needed — took it through the real path:

```
Running upload-symbols in Build Phase mode
Validating build environment for Crashlytics...
Validation succeeded. Symbol uploading will proceed in the background.
```

The guard let a device build through, and `-gsp` resolved (otherwise this is
where "Could not get GOOGLE_APP_ID" appears). Build-phase mode then uploads
asynchronously and leaves no log, so the same uploader was run in foreground
against the same dSYM: **`Successfully uploaded Crashlytics symbols`**, arm64,
UUID `c1af676af61a3d3fa385b09c6dd8bc4a`. Symbolication therefore needs no
manual step on a real release.

Two honest limits: the *background* upload's completion is inferred from the
foreground run of the identical binary with identical credentials, not observed
directly; and these symbols are inert — they belong to an unsigned local build
whose UUIDs no shipped binary will ever carry.

**What was NOT verified: the report appearing in the Firebase console.** That
needs the owner's Google login. Everything up to the upload is confirmed;
seeing it land is one click the owner has to make. Firebase → Crashlytics →
iOS app; look for `FirebaseCrashlyticsTestCrash` around 14:42 on 2026-09-17.

#### 2. Content cache — tested by hand, and it found a dead code path

All five scenarios driven on the simulator against the emulator, with the
functions emulator counting the actual requests rather than trusting the app's
own logs. Four behaved exactly as designed. The fifth did not.

| Scenario | Result |
|---|---|
| signup → language → state → Theory | `prefetch complete (state selected)`; 1 `getTheoryModules` + 1 `getTrafficRuleTopics`; Theory opened on `Cache VALID (age: 0h)` with **zero** further requests |
| change state, then immediately open Theory | 3 fetch intentions → **2 joins** → 1 request pair. New-state content (NY 7/7/7 vs IL 6/10/5), no flash of the old |
| language + state in quick succession | second change wins; 5 intentions → 2 real pairs (the superseded `NY|ru` had already started and cannot be retracted; the dedupe correctly did **not** join a different cache key) |
| kill mid-prefetch | recovers clean, no errors, the change persisted |
| **expired trial, change state** | `skipping prefetch, no entitlement` and **zero** content callables |

**The defect (`09a5723`): the prefetch never ran on a language change at all.**
`_prefetchEntitled` reads `State.context`, but `setLanguage` changes the app
locale, which rebuilds the tree and unmounts the profile screen before the
await returns. The throw happened while evaluating an *argument*, so
`prefetchInBackground` was never called — and nor was the `language_changed`
analytics event, so **every language change from settings was recorded as
`language_change_failed` while actually succeeding**. Two more throws sat
behind it (`Navigator.pop` on a deactivated element, then `!_debugLocked`), one
of them unhandled.

Measured before and after on the same cache-cold change: 0 → 1
`getTheoryModules`, and no exception of any kind.

The state handler has the same shape and was fine, because changing the state
does not change the locale. That asymmetry is exactly why "the state half
works" was not evidence for the language half — and why this was only ever
going to be found by driving it.

#### 3. Register rows

- **#10 DONE** (`c1f97e1`) — the config guide. See below; it was worse than
  "out of date".
- **#17 DONE** (`3d5ae62`) — the suite is green. Also rewrote the six tests to
  call the real service instead of asserting on strings they built themselves.
- **#39 was marked DONE and was still broken** (`2e63c37`). `7fa9a6c` replaced
  a hardcoded `'IL'` inside `ExamProvider`/`PracticeProvider` with their
  `state` parameter — but `test_screen.dart` kept passing the literal `'IL'`
  **into** that parameter. The constant moved one layer up. A New York user has
  been getting Illinois exam and practice questions this whole time. What hid
  it: the analytics helper resolved the real state from `7fa9a6c` onwards, so
  `exam_started` reported New York while the request asked for Illinois.

#### #28 — DONE, and the recommendation in the previous version of this file was WRONG

It said nginx's behaviour was probably correct and Firebase's was the bug.
**It was the other way round**, and the reason is worth keeping:

`ActionCodeRouter` routes an `oobCode` by its real operation via
`checkActionCode`, which is better than guessing from a query string. But
**this URL never reaches it.** Nothing in `lib/` calls `usePathUrlStrategy`, so
Flutter web uses **hash** routing — `/__/auth/action` is not part of Flutter's
route, `onGenerateRoute` never fires, and the code is dropped. A user clicking
a reset link on the nginx host landed on the login screen. Good code the URL
cannot get to.

So nginx now serves `password-reset.html` for that path too, via `location =`
(exact match, which outranks `location /` and every regex block below it).

**Three more dead things surfaced while confirming what the page does:**

| What | Reality |
|---|---|
| Six deep links using `licenseprep://` / `licenseprepapp://` | Neither scheme is registered on either platform. The registered one is **`driveusa`** |
| The Android intent's `package=com.license.prep.app` | `applicationId` is `com.driveusa.app` |
| A web fallback to `licenseprepapp.web.app/resetPassword?oobCode=` | Not a route, and it **dropped `mode`** on the way — observed landing on a page reporting *"Mode: Not provided"* |

So the automatic hand-off to the app has **never** worked. Only the "copy this
code" fallback did, which nobody knew they were relying on.

Plus the mode-blindness #28 names: one `MODES` table now drives heading,
message and target per mode. `recoverEmail` — Firebase's "undo this email
change" link, and the live one since the app does let people change their
email — has no screen in the app, so the page says so and hands over the code
instead of showing a password-reset screen.

**Verified by running it.** `crossplane` (nginx's own parser) parses
`nginx.conf` clean with `= /__/auth/action` as an exact-match location; no
nginx or Docker on this Mac, so it is **parsed, not served**. The page was then
driven in a browser for five cases, reading the DOM it built:

```
resetPassword -> "Password Reset"      driveusa://resetPassword?oobCode=
verifyEmail   -> "Email Verification"  driveusa://email-verified?oobCode=
recoverEmail  -> "Email Change"        button hidden, code shown
unknown mode  -> "Account Action"      button hidden, code shown
no oobCode    -> opens driveusa:// root
```

All five stayed local instead of escaping to production.
`host-parity.test.ts`: **10 red before, 19 green after.**

**Still open:** whether `driveusa://` actually opens the installed app cannot be
tested from a desktop browser. Pointing at a registered target is necessary,
not sufficient — it needs a device with the app installed, on both platforms.
On the Windows/device checklist as §4d, with `adb`/`simctl` one-liners that
isolate scheme registration from the page.

### THE ANDROID DEVICE RUN — 2026-09-19, Galaxy S10 Lite

A real Samsung SM-G770F, Android 12 / API 31, running the **release** build off
this branch against **production** (a release build cannot reach the emulators —
`connectToEmulatorsIfEnabled` throws in release by design). Test account
`gefeb69217@blobapps.com`, fresh signup, trial active.

**The owner found a bug no automated check could see.** The app skipped a
screen, and that was the only signal. Tests green, analyzer clean, CI green,
no crash, nothing logged — it did the wrong thing silently and successfully.
Fixed in `71102d2`, with a structural test proven to fail beforehand.

| # | Result |
|---|---|
| W3 | ✅ **No R8 damage found.** Zero `ClassNotFoundException` / `NoSuchMethodError` / `NoSuchFieldException` / fatals / unhandled exceptions from our process across signup, home, profile, subscription screen and two state changes. The 5 matches in 496k captured lines are Samsung's own `scloud.galleryproxy`, a different pid. **Not exhaustive** — theory and quiz were not driven |
| W4 | ⚠️ **Dart half verified clean, native half is NOT.** See below |
| W5 | ✅ **Success case confirmed with hard evidence.** ⚠️ offline case inconclusive, ⛔ expired-trial case impossible |
| W6 | ✅ **Crashlytics initialises on device.** Delivery of a real report still unverified |

**W5 — the prefetch event, captured.** `adb shell setprop debug.firebase.analytics.app com.driveusa.app` plus `setprop log.tag.FA VERBOSE` puts Analytics events into logcat, which is how to do this **without Firebase console access** — the checklist assumed DebugView was the only route. Changing state in Profile produced:

```
name=state_changed, params=[previous_state=NY, new_state=IL,
                            selection_context=profile, platform=android]
name=content_prefetch, params=[outcome=success,
                               reason=state changed in settings]
```

The other two bullets did not close. **Offline:** with wifi and data off, tapping a state in the dialog did nothing at all — dialog stayed open, no error, no dismissal, no `content_prefetch` event of either outcome. Taps were confirmed to land (a tap outside dismissed the dialog). **Not reported as a defect**, because the same tap was never demonstrated to work online either; it needs a clean repeat. **Expired trial:** not reachable — the account has 3 days left, and there is no way to age it from the client.

**W4 — #34's goal is not met on Android, and cannot be met by #34.** The Dart
half is verified: **zero** of the app's `debugPrint` lines reached logcat across
496,469 captured lines, and `lib/` has no `developer.log`, `stdout.write` or
`stderr.write` to escape the Zone. But the Firebase Auth SDK logs the address
itself, in Java, at INFO, in a release build:

```
I/FirebaseAuth(12875): Creating user with gefeb69217@blobapps.com
                       with empty reCAPTCHA token
```

Reassigning `debugPrint` and wrapping Dart in a `Zone` cannot reach a native
Google library. This is exactly #34's stated threat model — *"anyone with the
phone plugged into a laptop"*. The fix is sound and the row should **not** be
reopened against it; this is a separate, newly evidenced leak. No in-app
suppression is obvious, since it is the SDK's own logging.

**#63 cannot be verified on a sideloaded build — at all.** The paywall showed
`$9.99`, which is also the hardcoded fallback at `subscription_screen.dart:99`,
so the screen is uninformative in the US either way. The billing layer settles
it:

```
I Finsky : Billing preferred account via installer for com.driveusa.app
E AuthPII: [RequestTokenManager] getToken() -> BAD_AUTHENTICATION.
           App: com.android.vending, Service: oauth2:.../auth/googleplay   x4
```

And structurally it must fail: this APK is signed with a **throwaway** key while
the product ids belong to the real Play listing, and Play validates the package
signature against that listing. So `queryProductDetails` cannot succeed here.
**The Android price check, and W8's purchase items, need a build signed with the
real upload key on a Play internal-testing track** — not a sideload. That is a
firmer conclusion than the checklist's "use a non-US storefront".

**THE DEPLOY GATE, confirmed empirically for the first time.** It has only ever
been reasoned about. A real signup on the device: the Auth user is created
(that is plain Firebase and works), the app moves to the code screen, and
`sendEmailVerificationCode` — absent from production — fails. On screen:

> **"We sent a 6-digit code to gefeb69217@blobapps.com"**
> **"Something went wrong. Please try again."**

**Both at once.** The headline is asserted as fact before the send is confirmed,
so a user goes hunting for a code that was never sent, and *"Send a new code"*
invites them to do it again. That contradiction is independent of the deploy
ordering — **any** send failure produces it, so it will outlive the gate.

**The blast radius is narrower than the gate document implies, though.**
`SignupResumeGate` **fails open** by design: when the status call cannot be
made, the user continues rather than being held. Verified on the device — kill
and relaunch, and the app proceeds. New users are therefore **not** locked out;
they get their trial and reach the app. The only broken thing is verification
itself, which is not a gate on entitlement. A correction to what this file said
earlier: a failed signup does **not** leave a permanently wedged account.

**Diagnosis in release is blind, and that is the cost of #34.** Not one Dart
error reached logcat for any of the above. The screenshot was the only evidence
of the signup failure. Android release-build diagnosis now depends entirely on
Crashlytics and Analytics — exactly what the checklist predicted for the
prefetch, now true of everything.

### THE WINDOWS RUN — 2026-09-19, first Android build this branch has had

A Windows 11 machine with the Android SDK. **Phase 1, W1–W7.** Four closed by
running them, one was a real bug, two are blocked on hardware this machine does
not have. Nothing deployed.

**Toolchain, verified before touching the app:** Flutter 3.41.7 ✅ · Java 21.0.6
Temurin ✅ · Gradle 8.13 ✅. **The JDK trap (#57) did not fire** — Flutter was
already configured with `--jdk-dir` pointing at JDK 21, and `flutter doctor -v`
confirms it reads that rather than Android Studio's bundled JDK. One deviation
from the checklist's expectation: the Android toolchain row is `[!]`, not a
green tick, because *"Android license status unknown"*. It did not block any
build performed here.

| # | Result |
|---|---|
| **W1** | ✅ **`004d043` stands — do not revert.** Release build succeeds with the block removed, and the bundle stamps `androidGradlePluginVersion=8.13.0`. Also proved the block is inert *without* removing it: a build with the 8.4.0 `buildscript` classpath still present stamps 8.13.0, so `settings.gradle:21` is the real authority exactly as the commit argued |
| **W2** | ✅ **Reproduced and fixed** — see below, the reproduction contradicts the register |
| **W3** | ⛔ **Not done — needs a device and a decision.** The R8/ProGuard crash hunt is a *runtime* question and this machine has no physical Android device |
| **W4** | ⚠️ **Static half only.** Verified `lib/` has **zero** `developer.log`, `stdout.write` or `stderr.write` calls, so the Zone + `debugPrint` reassignment covers every Dart logging path there. The runtime half (app starts, logcat is clean) needs a device |
| **W5** | ⛔ **Not done — needs a device.** The `content_prefetch` event with `outcome` success/failure is wired at `content_loading_manager.dart:103-111` |
| **W6** | ❌ **Real bug, found and fixed.** The Android Crashlytics half did not compile |
| **W7** | ✅ **Answered: it ships 24, not 23.** Measured, not inferred |

**W6 — Crashlytics did not build, and the checklist guessed the wrong line.**
The first release build ever attempted on this branch failed in 27 seconds:

```
Could not create task ':app:uploadCrashlyticsMappingFileRelease'.
> The Crashlytics Gradle plugin 3 requires Google-Services 4.4.1 and above.
```

The checklist expected the `com.google.firebase.crashlytics` `3.0.2` pin to be
wrong for AGP 8.13.0. It is not; that pin is fine. The stale line is
`com.google.gms.google-services`, still at **4.4.0**. Bumped to 4.4.1 in
`settings.gradle` only. The release task graph now carries
`minifyReleaseWithR8`, `injectCrashlyticsMappingFileIdRelease` and
`uploadCrashlyticsMappingFileRelease`. **Still unverified: that a real crash
report arrives in the console** — that needs a device.

**W2 / #31 — the reproduction contradicts the register, in a useful direction.**
`key.properties` is gitignored, so its normal state on a fresh clone is absent,
and no rename was needed to reproduce. The register's worst case — a release
build carrying on and producing an unsigned bundle — **does not happen**.
`build/app/outputs/bundle/release/` stays empty; only an unsigned
*intermediary* under `intermediates/` exists, which is not a deliverable. What
happens instead is a full **135-second** build ending in:

```
Execution failed for task ':app:signReleaseBundle'.
> java.lang.NullPointerException (no error message)
```

Nothing in that names the keystore. So the fix was not to make release builds
fail — they already fail — but to make them fail in **~6 seconds saying why**.
The guard hangs off `gradle.taskGraph.whenReady`, deliberately not
configuration time: this file is configured on *every* Gradle invocation, so
throwing eagerly would break debug builds, `flutter run` and CI on every machine
without the keystore. Verified both directions: release without `key.properties`
fails in 6s with an actionable message; `flutter build apk --debug` still
succeeds and produces an APK. `android/key.properties.example` added.

**W7 — the file was lying, and here is the mechanism.** `build.gradle:49` said
`minSdkVersion 23`. The **Flutter tool rewrites that literal** to
`flutter.minSdkVersion` on every build — it logs `Upgrading build.gradle` while
doing it — and that constant is **24** in Flutter 3.41.7
(`FlutterExtension.kt:26`). Confirmed in the merged release manifest:
`minSdkVersion="24"`. Left as the symbol and documented, because a literal there
can only ever be overwritten and go stale again. **API 23 devices cannot install
this app and never could.**

**Two checklist errors that cost time — corrected in the vault.**

1. The checklist says `004d043` "is an ancestor of this branch, so the branch
   build covers it." **It is not.** It is the *single* commit on `main` that
   this branch lacks, and the dead `buildscript` block is still here. Building
   the branch verifies the un-removed state — the opposite of W1's intent. W1
   was done by applying the patch locally, building, then reverting it; the
   commit itself is left to arrive by merge rather than be duplicated.
2. The prefetch service is `lib/services/content_loading_manager.dart`. There is
   no `lib/services/content_prefetch_service.dart` on this branch either.

**What blocks W3, W4-runtime and W5 — and it is not just the missing device.**
A release build **cannot be pointed at the local emulators**:
`connectToEmulatorsIfEnabled` throws `StateError` in release mode by design
(`emulator_config.dart:33-38`). So driving a release build means driving it
against **production**, with a real account — and W5's expired-trial case needs
a production account in that state. That is an owner decision, not a mechanical
next step. This machine has no physical Android device attached; four AVDs
exist, but an emulator cannot answer the Play Billing half at all.

**Cross-platform watch items from the iPhone run (#60-#65):**

- **#61 logout hang — the live path is correctly fixed**, double-guarded (5s on
  the session write at `firebase_auth_api.dart:666`, 10s on the API call at
  `auth_provider.dart:704`). But `direct_auth_service.dart:532` carries the
  **same unguarded `invalidateSession` call**. It is **dead code** —
  `DirectAuthService` has zero references anywhere in `lib/` — so this is a
  latent trap, not a live bug. Wire that class up and the hang returns.
- **#62** confirmed fixed at `auth_provider.dart:561`; no longer rethrows.
- **#63** confirmed fixed; renders `ProductDetails.price`. **Note the trap:**
  `subscription_screen.dart:99` still falls back to the literal `$9.99` before
  `queryProductDetails` resolves. On a US storefront a *failed* Play query is
  therefore indistinguishable from a working one. Test this on a non-US
  storefront, or the check proves nothing.

### AFTER THE DEVICE RUN — 2026-09-19, the unblocked backlog

Four rows from the either-machine list, done the same day. All are **client or
infra** changes; none affects the functions deploy's create/delete list.

| Row | Result |
|---|---|
| **E1** production advisories | `npm audit --omit=dev`: **25 → 8**, and **0 critical, 0 high**. Plain `npm audit fix`, never `--force`; `package.json` untouched, lockfile only. The 8 left are all behind a **major** `firebase-admin` bump, still deliberately untaken — it is the SDK every function depends on and belongs on its own branch |
| **E2** counter rewind | A user could replay `counters/user_{uid}_reports` to a lower value; since reports are written with `.set()` not `.create()`, the next one silently overwrote an earlier report. Rule now mirrors the global counter. **Needs `--only firestore:rules`** — see the gate |
| **E3** sandbox in statistics | Operator counts included sandbox rows. Now excludes only a **known** sandbox row and returns `sandboxExcluded`, so nothing vanishes unreported. Filtered in code, because a `.where()` would change the query shape and need new indexes (#15/#19) |
| **E7** CI — risk **#36** | `.github/workflows/ci.yml`, green: Flutter (analyze + 157 tests), Functions (tsc + 351 tests against live emulators), Lint |

**CI's first run failed, and that is the argument for it.** Every step passed
locally; the runner still rejected it with *"firebase-tools no longer supports
Java version before 21"* because I had pinned 17 and this Mac happens to have
JDK 22. **Java 21 is now fixed in the workflow and is the only value that
works project-wide** — `firebase-tools` refuses below 21, Gradle 8.13 (#57)
aborts on 25. The two constraints pull in opposite directions; do not bump it
casually.

Risk numbers from the device run are **#60–#65** in the register.

### THE DEVICE RUN — 2026-09-19, first time this app has run on real hardware

A physical iPhone 12 Pro, pointed at the local emulators, with a real Apple
sandbox purchase. **Everything below was invisible from the simulator**, which
is the point: a simulator has a healthy localhost, no App Store sheet, and no
backend that can genuinely fail to answer.

#### The objective: #56's JWS path, verified against a real Apple signature

```
🔐 Detected a StoreKit 2 JWS — verifying the signature locally
🍎 Starting Apple JWS (StoreKit 2) validation
🌍 Environment: SANDBOX
🎉 JWS validation successful
🔗 Receipt binding OK: originalTransactionId=2000001238838670
```

Real online certificate checks too — `ocsp.apple.com` was contacted. This is
the one thing the 39 unit tests could not prove, because a genuine JWS needs
Apple's signing key and the verifier is mocked.

The database afterwards, which is the money-path scorecard:

| Check | Result |
|---|---|
| #22 | **one** `subscriptions` document, never two |
| #27 | `environment: sandbox` — not counted as revenue |
| #42 | `packageId: 1`, stored as a **number** |
| #5 | `originalTransactionId` bound to the purchasing account |
| #25 | `provisionUserDocument` fired on signup, wrote `users/{uid}` in 186ms |
| #48 | refused entitlement under a real outage rather than trusting a stale cache |
| Trial | granted at signup with **no** verification gate — the owner's decision, working |

#### Five bugs found, all five fixed (`34a8195`)

| Bug | Why the simulator could never show it |
|---|---|
| **Purchase timeout reported a paid purchase as failed**, and said "try again" | needs Apple's payment sheet to be open longer than 60s |
| **Logout hung forever** — a Firestore write with no server ack; try/catch is useless against a hang | needs a backend that accepts connections but cannot authorise |
| **Opening Profile could throw an unhandled exception** → FATAL in release | needs an auth call to fail in flight |
| **The paywall quoted a price the store does not charge** | needs two storefronts to compare |
| **Concurrent renewal receipts were dropped** | needs ~45 min of accelerated sandbox renewals |

#### Deep links, verified end to end on the device (M5)

`host-parity.test.ts` could only ever say "pointing at a registered target is
necessary, not sufficient". It is now sufficient, and proven:

```
🔗 Route requested: /resetPassword?oobCode=…
📧 Action code operation: ActionCodeInfoOperation.unknown   ← live, not inferred
↩️ Firebase said unknown; the URL says passwordReset — using that
✅ Reset code verified for email: test1@test.com
✅ Password reset confirmed successfully
```

The `unknown`-for-a-valid-code behaviour that the whole URL-fallback exists for
**actually happened**, on real hardware, with a real code minted by the Auth
emulator. The two-slash control confirmed Flutter drops the host
(`Route requested: /?oobCode=…`) — and that surfaced **#65**: the page's second
deep link sent password resets to the email-verification screen, advising a
verification email for a problem the user does not have. Fixed; only the path
form is offered now.

**Universal links are a different matter and must not be rushed.** They need
three things and have one: the entitlement is signed in ✅, the AASA is
Firebase's empty default ❌, and **the client cannot consume a universal link
at all** ❌ — no `app_links`/`uni_links`, no `continueUserActivity`, no
`FlutterDeepLinkingEnabled`. Publishing an AASA before the client half exists
would make iOS open the app, the app ignore the URL, and the working web page
be bypassed. Worse than today.

#### Environment findings, not product bugs

- **ATS blocks emulator use from a physical device.** No `NSAppTransportSecurity`
  key — correct for shipping — but Auth (9099) and Functions (5001) go through
  NSURLSession and are blocked on a LAN address. **Firestore appears to work**
  because its gRPC transport bypasses ATS entirely, which disguises the failure
  as an Auth-specific bug. Invisible on the simulator, where 127.0.0.1 is exempt.
- **A debug Flutter build cannot be launched from the home screen** (iOS 14+).
  Only `flutter run` or Xcode can start it, so when the debugger attach fails
  the app becomes unlaunchable. Cost two wasted rounds here.
- **Emulator email goes nowhere with a dummy `RESEND_API_KEY`.** The factory
  picks Resend whenever the key is *non-empty*, so a placeholder selects the
  real API with a bad key. Blank the key to get `LoggingEmailSender`, which
  prints the code. Verification codes are stored **hashed**, so they cannot be
  read back — rewrite the hash to a known code instead.
- **A stale production session survives the switch to emulators** and makes
  every callable fail for reasons that look like bugs. Log out, or reinstall.

Full write-up, including two findings I got wrong and corrected:
`device-findings.md` (session scratchpad), folded into the register below.

#### #56 — the backend half is DONE (2026-09-18), the sandbox half is not

**My earlier framing of this row was too coarse.** "#56 needs a Mac and an
Apple sandbox tester" is true of its *second* step only. The register's first
step is pure backend — make `validateAppleReceipt` format-aware — and needs no
Mac, no device and no Apple account.

Done now, and now rather than later for three reasons: it rides the functions
deploy that is already held, so it costs no second deploy; there are **zero
active subscriptions** (register reading 2026-08-29: 10 paid rows, all
inactive sandbox), which makes this the cheapest moment in the app's life to
touch receipt validation; and iOS is currently held together by
`enableStoreKit1()`, which is deprecated.

| File | What |
|---|---|
| `apple-receipt-format.ts` | The decision, pure and dependency-free. Three dot-separated segments with an `eyJ` header → `jws`; no dots and base64-only → `app-receipt`; **everything else → the legacy path** |
| `apple-jws-validation.ts` | `SignedDataVerifier`, production first, sandbox only on `INVALID_ENVIRONMENT` — mirroring `appStoreWebhook`. Same return shape as the legacy path |
| `receipt-validation.ts` | 13 lines: detect, and route before the `receipt-data` body is built |

**The asymmetry is the design.** Reading an app receipt as a JWS breaks a
purchase the customer has already paid for. Reading a JWS as an app receipt
reproduces the 21002 we have today. Only a confident JWS match takes the new
path, so the expensive mistake is unreachable — there is a test class for
exactly that property.

**`APPLE_BUNDLE_ID` now has exactly one definition** — in
`apple-jws-validation.ts`, which `index.ts` imports. I first left the webhook's
own copy in place and guarded it with a parity test, reasoning that editing live
money-path code with no test net was the worse trade. The owner pushed back on
2026-09-18 and was right: the deploy is **held**, so nothing was at risk now,
and a constant's correctness does not need a unit test on the webhook to
establish. Verified three ways instead — `tsc` clean; the **compiled**
`lib/index.js:1616` passes `apple_jws_validation_1.APPLE_BUNDLE_ID` into
`SignedDataVerifier`, which is runtime evidence no source check can give; and
the guard test now asserts the stronger property (no *other* module assigns it,
`index.ts` imports it, it still reaches the verifier). A control run that
reintroduces the duplicate makes that test fail, so it is load-bearing.

One value that cannot disagree with itself beats a test that notices when two
do.

**What these 37 tests do NOT cover:** signature verification itself. A real
JWS needs Apple's signing key, so the verifier is mocked. Everything decided
*after* the signature is covered — environment, product matching, revocation,
expiry, failure reporting. The sandbox matrix in the register (fresh purchase,
restore, auto-renewal, trial→paid) remains the only thing that can verify the
real path, and it still needs an Apple sandbox tester and a Mac.

**Sandbox verification: DONE 2026-09-19** — against the **emulator**, not
production. A real sandbox purchase produced a real Apple-signed JWS and this
code verified it, including online certificate checks. Matrix status: fresh
purchase ✅ (it was the trial→paid conversion, so both at once), auto-renewal ✅
(five accelerated sandbox renewals observed), restore ⚠️ exercised only through
StoreKit's redelivery of unfinished transactions — the explicit auto-restore
path never fired.

**Still do not drop `enableStoreKit1()`.** One thing has changed and one has
not: the JWS path is proven, but it was proven against code running in the
emulator. Production still runs the old `validateAppleReceipt`, so a client
emitting JWS today would meet a backend that cannot read it. The order stands:
**deploy the functions, re-verify against production, then** let the client
move.

#### Still open, in the order they are worth doing

**#56's sandbox matrix** (needs an **Apple** sandbox tester and a Mac; it is
*not* an Android job, despite arriving with the Billing 8 upgrade) and **#57**
(the JDK/Gradle trap — the Windows machine, and the first thing that will stop
you there). #### #33 and #37 — the owner has decided; both stay as they are

Asked and answered 2026-09-17. Neither is a defect to fix, and the register's
framing of both was slightly off.

**#33 — DEFERRED, and it is 14 states, not 51.** The register says the flag
"hides 49 of 51 states". The plan is **not** to open all 51: content for 12
more states is being prepared on another machine, so the target is **14**. The
flag gets flipped when that content is ready, which is a future release, not
now. Do not "fix" this by moving the flag to Firestore in the meantime — that
is only worth doing if states start being switched on one at a time, and the
decision is to ship them as a batch.

**#37 — STAYS OFF, deliberately, and stays recorded as not done.** Single-device
enforcement is written and disabled behind
`ENABLE_SESSION_CONFLICT_DETECTION = false`, whose own comment says it was
turned off to work around bugs in the conflict logic. The owner's decision is
to leave it off and revisit later. So one account still works on unlimited
devices, and the app still writes a session document on every login — the cost
without the benefit. **That is knowingly accepted, not overlooked.** Anyone
tempted to flip the flag should fix the conflict logic first; flipping it alone
reinstates the bugs it was disabled for. Resend (#35) is still blocked on the owner; see
`wiki/driveusa/Development/infra/owner-console-actions.md`, which also covers
the store privacy questionnaires that Crashlytics now makes mandatory.

**Store privacy forms — DONE 2026-09-18, one submission pending.** Apple's App
Privacy was already correct. Play's Data safety now declares Crash logs under
*App info and performance* (not App activity), purpose **Analytics** — Play's
own definition of Analytics covers "diagnose and fix bugs or crashes", where
Apple's covers user behaviour, so the same data gets the opposite answer in the
two stores and that is correct. Play's "Data deletion not supported" is the
*optional* data-only-deletion question and is correctly **No**; account
deletion is declared through the URL. That URL's page was the real gap — it
gave no deletion steps and never said what is kept — and privacy policy §5.1
now does, verified live. Play shows the Data safety change un-submitted with
**managed publishing off**; submitting publishes listing metadata only, ships
no code, and does not touch the deploy gate.

**Known and deliberately not fixed:**
- **`functions/` has no linting at all, and never has** — no `eslint`
  devDependency, no config file, no `lint` script. `npx eslint` only appears to
  "fail" because it downloads v10 on the fly and finds nothing to read.
  **Not a deploy risk:** `predeploy` runs `npm run build` (`tsc`), not lint.

  **Measured 2026-09-18 before deciding** (ESLint 9 + typescript-eslint 8
  installed with `npm install --no-save`, so nothing in the repo changed, then
  `npm prune`d away). `typescript-eslint@8` needs only `typescript >=4.8.4`, so
  there is **no** forced TypeScript bump — a risk I had asserted and was wrong
  about. Findings across `src` excluding tests:

  | Rule | Findings | Verdict |
  |---|---|---|
  | `no-floating-promises` | **0** | the one that could find real money bugs — an unawaited Firestore write in a function that then returns |
  | `no-misused-promises` | **0** | |
  | `require-await` | 1 | `email/sender.ts:56` — `LoggingEmailSender.send` is async to satisfy the interface. Correct as written |
  | `switch-exhaustiveness-check` | 2 | `index.ts:2219`, `receipt-validation.ts:561`. **Both already have `default:`** — the rule objects to `undefined` not having its own case. Option noise, not defects |
  | `no-explicit-any` | 28 | style; 10 already carry deliberate `eslint-disable` comments |

  **Zero real defects.** `strict: true` plus `noImplicitReturns` and
  `noUnusedLocals` already cover most of what a TS lint setup adds, and the
  async code is clean.

  I also had the `eslint-disable` comments wrong: I called them "template
  leftovers suppressing a rule that has never run". With `no-explicit-any`
  actually enabled, **every one of them is load-bearing** — `--report-unused-
  disable-directives` found none unused. They are accurate, not vestigial.

  **Decision: do it as part of #36 (CI), not before.** A linter's value is as a
  gate that runs without being remembered; there is no CI, so it would be a
  command nobody types. Revisit when #36 lands or a second developer joins.
- `traffic_rules_topics_screen.dart:60` hardcodes `'IL'` the same way #39 did,
  but nothing pushes `/theory` and the screen is reachable only through an
  `onGenerateRoute` fallback for a dead deep link. Near-dead code.
- `ContentLoadingManager`'s language listener logs *"Language changed during
  initialization, skipping content update"* when the manager has not finished
  initialising, so that path is racy on its own. It stopped mattering once the
  explicit call started working — which is why the explicit call exists.
- The signup terms checkbox uses `MaterialTapTargetSize.shrinkWrap`, giving it
  a tap target of roughly 18pt. It took four attempts to hit deliberately.
- The six-box verification input drops characters when they arrive faster than
  it can move focus. Genuine clipboard paste was not tested; worth checking,
  because the screen advertises paste support.
- Profile briefly shows *"State: Loading…"* on first open before resolving.

#### Standing cautions

- **Never `firebase deploy --force`.** It deletes indexes absent from the file. See the 2026-09-17 index diff.
- **Check `git diff pubspec.lock` after adding any Firebase package.** `flutter pub add firebase_crashlytics` silently bumped 20+ packages including `cloud_firestore` and `firebase_auth`, and broke the iOS build.
- **The branch holds the two Criticals (#3, #4) that are live in production today.** Every row added widens the gap between fixed and shipped.

### What 2026-09-17 closed

| Row | What | Verified by |
|---|---|---|
| #30 | iOS had **no entitlements file at all** and `com.apple.developer.associated-domains` sat in `Info.plist`, where iOS ignores it. Universal links have therefore never worked — the other half of the dead email-verification deep link | `plutil -lint`, `xcodebuild -showBuildSettings` for all three Runner configs, simulator build + launch |
| #15 | `firebase.json` had no `firestore.indexes` key, so indexes have **never been deployed**; the file listed 3 of them. Now enumerates all 18 composite queries in `functions/src` | `firestore-indexes.test.ts` — 19 tests, 15 red before |
| #11 | The counter rule contradicted its own writer: `create: if false` blocked the first-ever increment, and `hasOnly` ran against the **merged** document, so one run of an admin helper bricked every later increment | `counter-rules.test.ts` — 10 tests, 2 red before |
| #27 | Apple's sandbox flag and Google's `testPurchase` were logged and discarded, so test subscriptions were stored as real revenue | `store-environment.test.ts` — 5 tests, all red before |
| #34 | ~1,839 `print`/`debugPrint` calls reach release logs, ~122 carrying a user id, email or report id. Fixed structurally in ~10 lines rather than at 122 call sites | `release_logging_test.dart` — 8 tests |
| #35 | **PARTIAL.** The three notification helpers returned a hardcoded `true`, which callers wrote into `subscriptionLogs.emailSent` — an audit trail claiming mail nobody received. They now return `false`. Actually *sending* mail is still blocked on a provider | `email-honesty.test.ts` — 3 tests, 2 red before |
| #49 | **PARTIAL.** Base images pinned (`flutter:3.41.7`, `nginx:1.27-alpine`); both tags confirmed to resolve before pinning. The gcr.io → Artifact Registry half is an owner action | registry manifest checks |

**Also fixed, not a register row:** the emulator would not start. The #40 work
added `defineInt('SUBSCRIPTION_LOG_RETENTION_DAYS')`, which no env file
supplied, so `firebase emulators:start` hung forever on an interactive prompt —
and so would a real `firebase deploy`. A `default: 0` does **not** suppress the
prompt, the same trap `APPLE_APP_ID` already had. Added to both
`functions/.env.local` and `functions/.env.licenseprepapp` (both untracked).

**Before touching anything, run the bring-up in *How to resume*.** The emulator
starts empty every time: re-seed content AND images, then grant a local trial,
or every screen will look broken and you will debug a phantom.

**Branch:** `local/security-money-hardening` (base `84300d0`, off `chore/play-billing-8-migration`)
**Started:** 2026-09-16
**Last updated:** 2026-09-17 (second session) — closed #10 #17, re-closed #39 (was marked done and still broken), finished and verified Crashlytics, and found a dead prefetch path by hand-testing the cache
**Goal:** Fix the Critical + High security and revenue risks from `driveusa-risk-register`, verified locally. **Never deploy. Never touch the live Firebase project.**

> If this session is interrupted, read **How to resume** below. Everything needed to pick up is in this file.

---

## Ground rules

1. All work stays on `local/security-money-hardening`. The owner asked for it to be pushed on 2026-09-16, so `origin/local/security-money-hardening` now exists and pushing further commits there is fine. **`main` and `chore/play-billing-8-migration` stay untouched, and nothing here is deployed** — pushing a branch is not shipping. No PR has been opened; that is the owner's call.
2. Emulators run under the real project id **`licenseprepapp`**. The `demo-driveusa` idea was abandoned: `FirebaseOptions` is a matched set, so a fake project id breaks the API key. The safety net instead is that **ADC was revoked** — this machine holds no credential that can reach production Firestore. Do not re-run `gcloud auth application-default login` without a reason.
3. Production is **read-only**, and only for the one-time content export. No writes, no deploys, no rule pushes.
4. Every fix needs a verification that fails before the fix and passes after. No fix is marked DONE on inspection alone.
5. Emulator wiring in the Flutter app is behind `--dart-define=USE_EMULATOR=true`, default off, so a release build can never point at localhost.

---

## How to resume

```bash
cd /Users/demianvyrozub/projects/license-prep-app
git checkout local/security-money-hardening
git log --oneline -10           # what landed last
```

Bring the environment up. **Every functions command needs the Node 22 prefix** —
the machine's default is Node 20 and `functions/package.json` pins 22:

```bash
export PATH="/opt/homebrew/opt/node@22/bin:$PATH"
firebase emulators:start --project licenseprepapp --only firestore,auth,functions,storage,pubsub
```

Seed content into a fresh emulator (data is in-memory and lost on restart):

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-emulator.js
```

Then seed placeholder images, or every theory section and quiz question with a
picture shows "Image unavailable". The content export copies Firestore documents
only; the real picture files are in production Cloud Storage and this machine has
no credential to read them:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-emulator-images.js
```

Run the tests. **After ANY TypeScript change, build first** — the emulator runs
`functions/lib/`, not `functions/src/`, so tests and the emulator will otherwise
disagree silently:

```bash
npm --prefix functions run build && (cd functions && npx jest)
```

Two things about the functions suite that will otherwise waste your time:

- **`npm test` cannot run while the dev emulator is up.** It starts its own
  emulators via `firebase emulators:exec` and dies with *"Could not start
  Authentication Emulator, port taken."* Stop the long-running emulator, run
  `npm test`, then start it again and re-seed. `npx jest <file>` on its own does
  NOT do this — it reuses whatever emulator is already running, which is why it
  is the right choice for iterating on one suite.
- **The emulator only serves the functions it loaded at startup.** Adding a new
  Cloud Function and rebuilding is not enough; it will not appear until the
  emulator restarts. Tests see it immediately because they build and load fresh,
  so a new function can pass its suite while being absent from the running app.

```bash
flutter test
```

Build and run the app (about 6 minutes; `LANG` is required or CocoaPods fails):

```bash
LANG=en_US.UTF-8 flutter build ios --simulator --debug --dart-define=USE_EMULATOR=true
```

```bash
xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch booted com.driveusa.app
```

The simulator can never obtain a trial through signup (`isPhysicalDevice` is
false there, by design). Grant one the way a real device would:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp node scripts/local/grant-local-trial.js <email>
```

It looks the account up in the `users` collection, so sign up in the app first —
after an emulator restart every account is gone and it will report *"No user
with email ..."* until you do.

---

## Environment setup

| # | Step | Status | Notes |
|---|---|---|---|
| E1 | Local branch created | ✅ DONE | `local/security-money-hardening` @ `84300d0` |
| E2 | Session file | ✅ DONE | this file |
| E3 | Node 22 installed | ✅ DONE | `brew install node@22` (keg-only). Prepend `/opt/homebrew/opt/node@22/bin` to PATH for any functions work |
| E4 | `emulators` block in `firebase.json` | ✅ DONE | auth 9099, functions 5001, firestore 8080, storage 9199, pubsub 8085, ui 4000 |
| E5 | Local secrets for emulator | ✅ DONE | `functions/.secret.local`, dummy values, gitignored |
| E6 | Content exported from production | ✅ DONE | 6,627 docs (~8.7 MB) via ADC, read-only, into `.local-export/` (gitignored). Seeded into emulator with `scripts/local/seed-emulator.js`. **No user data copied** |
| E7 | Flutter emulator wiring | ✅ DONE | `lib/config/emulator_config.dart`, one call in `main.dart`. Throws in release mode |
| E8 | iOS pods reinstalled | ✅ DONE | 43 pods, Sep 16. **Needs `LANG=en_US.UTF-8`** or CocoaPods dies on a Ruby 3.4 encoding bug |
| E9 | App runs on simulator against emulators | ✅ DONE | iPhone 16 Pro, login screen, Firestore probe OK (`host=127.0.0.1:8080 ssl=false`) |

## Test harness (risk #17 — prerequisite, not optional)

| # | Step | Status | Notes |
|---|---|---|---|
| T1 | Jest + ts-jest in `functions/` | ✅ DONE | `npm test` wraps `firebase emulators:exec --project demo-driveusa`. Emulators spin up, tests run, teardown is automatic |
| T2 | `@firebase/rules-unit-testing` suite | ✅ DONE | `firestore-rules.test.ts` — risks #3, #29. Own project id `demo-rules-test`, never touches seeded data |
| T3 | StoreKit configuration file | ⬜ TODO | local fake store for simulator purchase / restore / renewal / trial→paid |
| T4 | One red test per in-scope risk | 🔄 IN PROGRESS | #3 and #29 complete. **16 tests, all green**, incl. paid + trial positive controls |

---

## Fix queue — security & money

Status: ⬜ not started · 🔄 in progress · ✅ done & verified · ⏸️ blocked · ⏭️ deferred

### Critical

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #3 | Paid content corpus served with no auth — 7 callables have no `context.auth`; rules gate only on `auth != null` while `main.dart` signs everyone in anonymously | ✅ **DONE** | `content-auth.test.ts` + `firestore-rules.test.ts`, 16 green | `851a8a1` + rules |
| #4 | `handleMockPaymentWebhook` (unauthenticated POST) and test-data callables deployed to production | ✅ **DONE** | `no-test-endpoints.test.ts` — asserts absence, 5 red → green | all five deleted + orphaned `test-data-generator.ts` |

### High — money path

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #2 | `upgradeSubscription` grants 365 days yearly, free, no audit row | ✅ **DONE** | `no-free-upgrade.test.ts` | Deleted server-side **and** the whole client path: UI button, confirmation dialog, provider + service methods, model helpers, and the orphaned `UpgradeCalculator` (138 lines). ~480 lines removed in total |
| #5 | No receipt→account binding — one receipt entitles unlimited accounts | ✅ **DONE** | `receipt-binding.test.ts` — 8 tests incl. wiring + renewal positive controls | Guard refuses a receipt bound to another `userId`, before any write |
| #6 | `yearly` receipts dropped client-side (`_activeProductIds` = monthly only) | ✅ **DONE** | `test/in_app_purchase_products_test.dart` — 3 tests (first real Dart coverage) | Yearly removed from what the app **offers**; receipts for it are now **forwarded, not dropped**. Server allow-list keeps yearly on purpose |
| #7 | Home-grown 18h grace period vs Apple 16d / Google 30d | ✅ **DONE** | `grace-period.test.ts` — 6 tests | Grace measured in elapsed time (30 days, `billing-grace.ts`), shared by the scheduler **and** the entitlement gate |
| #8 | Play `PAUSED` / `PAUSE_SCHEDULE_CHANGED` (types 10, 11) not modelled | ✅ **DONE** | `play-notifications.test.ts` — 8 tests | Mapping extracted to a pure, tested function; types named in code, not in a comment |
| #9 | Webhooks always return 200, no dead-letter, no reconciliation | ⚠️ **PARTIAL** | `webhook-dead-letter.test.ts` — 5 tests | Dead-letter queue + bounded failure signalling done. **The daily reconciliation job is NOT done** — see below |
| #19 | Rate limit counts failures — paying user locked out for an hour | ✅ **DONE** | `rate-limit.test.ts` — 6 tests, 5 red → green, incl. fail-open | Separate success (10/h) and failure (30/h) budgets; fails open on infrastructure errors |
| #20 | `subscriptionsType` is a single point of failure for every purchase | ✅ **DONE** | `metadata-resilience.test.ts` — 6 tests, 4 red → green | Built-in defaults for monthly/yearly/trial; Firestore still wins when a row exists. Also stopped the outer catch flattening every `HttpsError` into `internal` |
| #22 | Duplicate `subscriptions` docs after re-subscribe; webhooks update the corpse | ✅ **DONE** | `duplicate-subscriptions.test.ts` — 5 tests incl. the RV-C1 regression guard | Re-subscribe reuses the document matching the receipt identity; both webhooks now fan updates out to every match via `webhook-fanout.ts` |

### High — security / abuse

| Risk | What | Status | Verified by | Commit |
|---|---|---|---|---|
| #18 | 8 admin-grade functions callable by any authenticated user | ✅ **DONE** | `admin-auth.test.ts` — 12 tests, 4 red → green, with admin positive controls | Four gated by `requireAdmin()`; the other four were the test-data callables already deleted under #4 |
| #12 | `sendEmailVerification()` never called; `emailVerified` gates nothing | ⚠️ **PARTIAL** | `trial-gate.test.ts` — 2 tests + verified live (Auth emulator issued `VERIFY_EMAIL`) | Verification email is sent at signup. **The trial is deliberately NOT gated on it** — owner product decision, see below. So `emailVerified` still gates nothing; the farming exposure remains and needs attestation, not a door gate |
| #26 | Trial gate forgeable (client-supplied `deviceIdHash`), dedupe non-transactional | ⚠️ **PARTIAL** | `trial-gate.test.ts` — 6 tests incl. a real concurrency race | Dedupe is now transactional; `trialDevices` anonymised on account deletion. **The forgeable client input is NOT fixable in code** — see below |
| #29 | `users/{uid}` accepts arbitrary client writes including `isActive` | ✅ **DONE** | `firestore-rules.test.ts` | rules blocklist |

### Resolved by product decision

| Risk | What | Status | Notes |
|---|---|---|---|
| #43 | Year length disagrees: catalogue `duration: 360` vs `upgradeSubscription` `duration: 365` | ⏭️ MOOT | Only the 30-day plan is sold. The mismatch lives entirely in yearly code being removed under #2 and #6 |

### Taken in, out of the original scope

| Risk | What | Status | Why it was pulled in |
|---|---|---|---|
| #58 | New user with no trial saw a silent dead end (`SizedBox.shrink()`) | ✅ **DONE** | Unavoidable once #12 gates the trial: refusing a trial without explaining it would send every unverified signup to a blank screen. The branch now renders a real card, and says *"verify your email"* specifically when that is the reason |
| #32 | `functions/.env.licenseprepapp` tracked in git, no `.env` rule at all | ✅ **DONE** | `git ls-files` | Untracked + blanket `.env` rules. File contains only `APPLE_APP_ID`, not a secret — the risk was the *next* one |
| #39 | Hardcoded `state: 'IL'` when starting exams and practice | ✅ **DONE** | code + app | Topics already honoured the user's state; **questions did not**, so a New York user got Illinois questions |
| #48 | Local subscription cache trusted whenever the Firestore read fails | ✅ **DONE** | code | Server is authoritative when it answers; an **expired** cache is discarded when it does not |
| #54 | Web and mobile point at different Storage buckets | ✅ **DONE** | config | Web was the odd one out — both authoritative Firebase config files say `firebasestorage.app` |
| #59 | App version hardcoded `1.0.0`, tagging every analytics event | ✅ **DONE** | app | Real version from `PackageInfo` in analytics **and** the profile screen |
| #21 | Cross-device progress sync does not exist; failure is invisible; local key unscoped | ⚠️ **PARTIAL** | `progress_storage_test.dart` — 3 tests | Local storage **scoped per user** (was one shared key) + the silence documented. **Sync itself is NOT built** — see below |
| #13 | Privacy policy promises deletion the code cannot deliver (2 of at least 8 locations) | ✅ **DONE** | `account-deletion.test.ts` — 11 tests | All personal locations deleted incl. the `sessions` subcollection; billing records **anonymised**, per the policy's own tax carve-out |
| #14 | Deletion needs no reauth, is not atomic, silently leaves store subscriptions billing | ✅ **DONE** | `account-deletion.test.ts` | Recent-login required (10 min), chunked writes past Firestore's 500 limit, and the user is warned **before** deleting |
| #23 | Orphan-auth trap — a failed signup left an Auth user with no document, unrecoverable in-app | ✅ **DONE** | `user-provisioning.test.ts` — 5 tests | `provisionUserDocument` auth trigger + `set/merge` in both updaters so already-orphaned accounts heal |
| #24 | Interrupted signup meant no entitlement, forever | ✅ **DONE** | server dedupe tests + in-app | `SubscriptionProvider.initialize` retries the trial once when no subscription exists at all |
| #25 | Schedulers capped at 100 documents per run, no cursor, no queue-depth signal | ✅ **DONE** | `sweep.test.ts` (4) + `scheduler-uncapped.test.ts` — 150 expired trials all swept | Cursor pagination + a wall-clock budget; scheduler timeouts raised 60s → 540s |
| #16 | No `predeploy` hook — `firebase deploy --only functions` ships stale compiled JS | ✅ **DONE** | Not optional after all: `functions/lib/index.js` was compiled **Apr 27**, five months stale. The emulator runs `lib/`, so every local verification was against April code until this was found. Added `predeploy` to `firebase.json` and deleted the dead root `index.js` shim |

### Taken in on 2026-09-17

| Risk | What | Status | Verified by | Notes |
|---|---|---|---|---|
| #30 | iOS has no entitlements file and `associated-domains` is misplaced in `Info.plist` | ✅ **DONE** | `plutil -lint`, `xcodebuild -showBuildSettings` × 3 configs, simulator build + launch | The key was inert where it sat, so universal links have **never** worked. Making it real means the App ID must now carry the Associated Domains capability — **owner action, see below**, or a device/archive build will fail to provision where it previously succeeded doing nothing |
| #15 | `firestore.indexes.json` never deployed, and incomplete | ✅ **DONE** | `firestore-indexes.test.ts` — 19 tests, 15 red → green | Enumerated all 18 composite queries in `functions/src`. The three pre-existing entries were **kept, not rewritten**: `firebase deploy` offers to DELETE indexes absent from the file, so removing an entry is how a deploy drops a working production index |
| #11 | The counter rule contradicts its own writer | ✅ **DONE** | `counter-rules.test.ts` — 10 tests, 2 red → green | Two defects: `create: if false` blocked the first-ever increment (a merge-set on a missing document is a create), and `hasOnly` ran against the **merged** document, so one run of `initializeGlobalCounterFromExistingReports` bricked every later increment. Now `diff(resource.data).affectedKeys()` |
| #27 | Sandbox vs production detected but never persisted | ✅ **DONE** | `store-environment.test.ts` — 5 tests, 5 red → green | Unknown stores as `null`, never `production` — a default would recreate the defect. A renewal that does not know omits the key rather than promoting a sandbox subscription into a real one |
| #34 | ~1,839 `print`/`debugPrint` calls reach release logs, ~122 carrying PII | ✅ **DONE** | `release_logging_test.dart` — 8 tests | Fixed structurally in ~10 lines, not at 122 call sites: `debugPrint` is reassigned and the app runs inside a Zone that drops `print`. Wraps all of startup, not just `runApp` |
| #35 | Email mocks return `true`; `emailSent` records mail nobody received | ⚠️ **PARTIAL** | `email-honesty.test.ts` — 3 tests, 2 red → green | The three helpers now return `false`. **Sending mail is still not possible** — same provider blocker as the email-verification work. These tests will fail when a transport is wired in; that is the right moment to revisit them |
| #49 | Unpinned Docker base images; deprecated `gcr.io` | ⚠️ **PARTIAL** | registry manifest checks (both tags return 200) | Pinned `flutter:3.41.7` and `nginx:1.27-alpine`. **Artifact Registry migration deliberately not done** — it needs a repository, IAM for the Cloud Build service account and a trigger update (#36), and repointing the paths without those breaks the web deploy rather than fixing it |

**Out of scope this round** (tracked, not started): #13 #14 privacy/deletion · #21 cross-device sync · #36 CI · #49 Docker · #53 content authoring · #55 #56 store platform (already handled/mitigated) · all remaining Medium rows.

---

## To do next

Agreed but not started. Nothing here is in the current branch.

### 1. Email verification by 6-digit code — SERVER HALF BUILT 2026-09-17

**Provider chosen: Resend** (owner, 2026-09-17), sending from
`driveusaservice@driveusallc.com` on the `driveusallc.com` domain.

**Done** (`52452b6`): the whole server side, with 51 tests.

| Piece | Where |
|---|---|
| Policy — code generation, hashing, expiry, attempt cap, send throttling | `functions/src/email/verification-code.ts` (pure, no Firestore or network) |
| Transport, behind a swappable interface | `functions/src/email/sender.ts` |
| Callables — send, verify, status | `functions/src/email/verification-callables.ts` |
| Templates, five languages | `email-templates.ts` (`VERIFICATION_CODE_TEMPLATES`) |
| Rules | `emailVerificationCodes/{uid}` client-deny both ways |

Limits: 10-minute expiry · 5 wrong guesses then the code is burned · 60s
resend cooldown · 5 sends per hour.

**It works locally without a key.** `createEmailSender` returns a log transport
under the emulator, which prints the code, so the flow is exercisable end to
end today. In production with no key it **throws** rather than pretending — that
is #35's lesson encoded, not merely documented.

**The Flutter half is also done** (`fd6ab4e`), with 14 widget tests.

| Piece | Where |
|---|---|
| Callable wrapper, typed outcomes instead of string matching | `lib/services/email_verification_service.dart` |
| Code screen — six boxes, paste, countdown, per-reason errors | `lib/screens/verification_code_screen.dart` |
| Resume-on-relaunch | `lib/screens/signup_resume_gate.dart` |
| Strings, five locales, added to the coverage guard | `lib/localization/l10n/*.json` |

Flow is now **email+password → code → language → state**.

Two properties not to break:
- `SignupResumeGate` is scoped to `user.state == null`. Gating on
  `emailVerified` alone would send **every existing account** to a verification
  screen, since all of them predate this and have the flag false.
- The gate **fails open**: if the status call cannot be answered the user
  continues to state selection. Verification is a step in signup, not a door in
  front of entitlement.

**Verified end to end on the simulator** on 2026-09-17: signed up, read the code
from the log transport, submitted a wrong code (the server's own attempt counter
came back as "4 attempts left"), then the right one, landing on language
selection. Auth shows `emailVerified=true` for the completed account and `false`
for an abandoned one.

**The content prefetch is done too** (`f6106fa`), with 6 tests.

Fires on state-confirm at the end of signup, and on state or language change in
the profile screen. Almost all of it already existed: `ContentLoadingManager`
had `initializeContent()` and `reloadContentIfNeeded()` from the start, and its
listeners are gated on a flag only `initializeContent()` sets — which nothing
ever called. **That is the #41 follow-up closed**: the manager had been inert
for the life of the app.

Three properties:
- **It skips users who cannot be served.** Every content callable requires
  entitlement, so prefetching without one is two guaranteed refusals. The skip is
  asymmetric on purpose: it suppresses only on a *known* lack of entitlement,
  because an unread subscription at the end of signup is the new-trial case this
  exists for.
- **The outcome is reported to analytics** (`content_prefetch`, success/failure),
  which is the only channel that reports from a release build. Skips are not
  counted — they are the normal path for unsubscribed users and would drown the
  signal.
- **Fire-and-forget and silent.** Nobody asked for this work, so a failure must
  never surface to the user; the content screens still fetch on demand.
- **`ContentProvider.fetchContent` now dedupes in-flight identical fetches.**
  Without it this feature would cost duplicate requests rather than save
  anything — the cache check inside only helps once a fetch has finished.

Verified on the simulator: a state change produced three would-be identical
fetches (listener, explicit prefetch, in-flight original) and the functions
emulator recorded exactly **one** `getTheoryModules` and **one**
`getTrafficRuleTopics`.

**Owner steps outstanding:**
1. Add the four DNS records Resend listed (DKIM TXT, two SPF CNAMEs, DMARC TXT) in Google Cloud DNS, then click *I've already added the records* and wait for Verified.
2. Create a Resend API key with sending access, then `firebase functions:secrets:set RESEND_API_KEY --project licenseprepapp`. **Never paste it into a file** (cf. #1, #32).
3. Free tier is 3,000/month and 100/day — the daily cap is the tighter one, worth checking against expected signup volume.

### 1b. The original plan, for context

Replaces the link flow. A code typed in the app avoids both broken paths: the
hosting rewrite that sends every `/__/auth/action` to `password-reset.html`
(which has no `verifyEmail` handling at all — confirmed), and the misplaced
Associated Domains entitlement that breaks deep links (#30).

**Flow:** email + password → code screen → verified → account finalised **with**
the 3-day trial. The trial still feels instant because verification sits inside
signup rather than gating afterwards. Someone who abandons at the code screen
resumes there on next login, so nobody is stranded with an account and no trial.

**Blocker: there is no way to send email at all.** `nodemailer` is commented out
in `subscription-manager.ts`, and `email-templates.ts` (1,382 lines, five
languages) is imported by nothing — risk #35. The forgot-password mail cannot be
reused: `FirebaseAuth.sendPasswordResetEmail()` asks Google to send it, so none
of that sending is our code, and Firebase's three built-in emails cannot carry
our own code.

| Step | Who |
|---|---|
| Pick a provider (Resend ~3k/mo, Brevo ~300/day, SendGrid ~100/day) | owner |
| Verify the sending domain — SPF/DKIM DNS records. **This decides inbox vs spam** | owner |
| `firebase functions:secrets:set MAIL_API_KEY` — never in a tracked file (cf. #1, #32) | owner |
| Code generation: 6 digits, stored **hashed**, ~10 min expiry, max 5 attempts, resend throttled | me |
| Verify callable; on success set Firebase's real `emailVerified` via the Admin SDK | me |
| Sender behind a small interface so the vendor is swappable | me |
| Code-entry screen: six boxes, paste support, resend countdown, resume-on-relaunch | me |
| Verification-code template added to `email-templates.ts`, reusing its existing structure | me |

**~2–3 days once mail sending exists.** Can start before the provider is chosen:
the sender writes codes to the emulator log locally, so the whole flow is
testable end to end, and production becomes a config change.

**Honest limit:** this raises the cost of multiple accounts from *typing any
string* to *controlling a real inbox*. Throwaway inbox services still work, so it
is strong friction, not a wall. It does cleanly deliver the other two goals — a
confirmed-real address, and a genuine marketing list.

### 2. App Check / device attestation — deferred

Written up in the vault: `wiki/driveusa/Development/infra/app-check-attestation-plan.md`.

### 3. The rest of the risk register

**16 of the 59 rows are still open, and they are all Medium or lower** — the
Criticals and Highs in the agreed scope are done. Remaining: #1 (history
cleanup only; the leaked secret is already rotated and dead), #10, #17, #28,
**#31 (next)**, #33, #35 (the sending half), #36, #37, #42, #44, #49 (the
Artifact Registry half), #53, #55, #56, #57.

Of those, the ones that are **not** blocked on an owner decision, store
sandbox access or the Windows machine are #10 (a wrong config guide — docs
only), #17 (the 6 `counter_service_test.dart` failures, a harness gap),
#28 (`nginx.conf` and Firebase Hosting implement different rules for the same
paths) and #42 (`packageId` written as three different types). Those four are
the natural next batch after #31.

Worth knowing before picking one:
- **#33 and #37 are product decisions, not bugs** — whether to widen past IL/NY,
  and whether to switch single-device enforcement on. Ask the owner first.
- **#50** overlaps something already seen on screen this session: a missing
  translation key renders as the raw key string, because `translate()` returns
  the key rather than null when it misses.
- **#55/#56 are store-deadline work** and need sandbox access, like #9.

**#21 is deliberately partial.** Two of its three problems are closed: progress is no longer stored under one unscoped key (two accounts on one device shared quiz scores, exam results and study progress), and the failure is no longer dressed up as offline tolerance. Legacy unscoped data migrates once to whoever signs in first — a guess, but the same data they can already see, and each account is separate from then on.

**Cross-device sync itself is not built**, and it is a feature, not a fix: five Cloud Functions written from scratch, a Firestore schema and rules for `progress/{uid}` (currently rule-denied), serialisation for `Exam` (which has none), a migration for existing local progress, and a **conflict-resolution decision** — when two devices disagree, which wins? That last one is the owner's call, not a technical one. **Sixteen** mapped callables have no server implementation (the register said ten); they are now listed in a comment at the mapping in `firebase_functions_client.dart` so nobody assumes a name means an endpoint.

**Known gap left by #13/#14:** the client's partial-delete fallback still exists for the case where Cloud Functions is unavailable. It deletes the Auth account and `users/{uid}` but not the other personal data, so a deletion completed that way is incomplete until the callable next succeeds. Closing it properly needs a server-side deletion queue — worth doing alongside the #9 reconciliation job.

## Corrections found in the register

Rows whose stated premise did not survive checking. Recorded so the next reader
does not act on the wrong cause.

- **#50 — the strings were only a third of it.** Six auth screens really did
  have zero `translate()` calls, but translating them alone would have changed
  nothing on screen: `main.dart` passed `forceEnglish: user == null`, and
  `AuthProvider` called `setLanguage('en')` on every logout. Either one alone
  reproduces "a returning Russian user meets an English login screen". Also, the
  "33 keys referenced in code exist in no JSON file" count is stale — measured
  109 distinct keys, of which 2 were missing.

- **#51 — the dead code was not shipping.** The row says debug and example code
  "ships inside release builds" and costs "dead weight in the shipped binary".
  Dart compiles from `main.dart`'s import graph and none of the five files was
  imported, so none reached the binary. Verified against the compiled kernel:
  `FirebaseDebugTestWidget`, `ApiSwitcherExample` and `QuizCacheIntegrationExample`
  appeared 0 times each, against 6 for a reachable widget as a control. The real
  cost was 890 lines in the repo that read as live code. The other half of the
  row — the analytics helper pointing at `com.example.license_prep_app` — was
  entirely real.
- **#40 — the rate-limit query did not degrade with collection size.** It is
  indexed on (userId, timestamp, action). What it lacked was a limit, so cost
  scaled with one user's attempts in the window.
- **#46 — not one orphan per cold start.** Firebase persists the anonymous
  session across launches, so it is one per install, plus one per logout, plus
  one per signup. Still unbounded, by a different route.
- **#21 undercounts.** Sixteen mapped callables have no server implementation,
  not ten.
- **#18 listed eight unguarded callables**; four had already been removed by the
  time the rest were gated.

## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-09-16 | Skip Agent Orchestrator; Claude Code subagents + worktrees instead | ~20 of the fixes touch `functions/src/index.ts`; parallel agents on one file means merge conflicts, and with no tests nobody notices a bad merge |
| 2026-09-16 | Build the test harness before fixing | ~35 of the risks are server-side and invisible in the iOS UI. Without tests they'd ship on trust. Also closes #17 |
| 2026-09-16 | Export production content read-only rather than hand-seeding | Emulator starts blank; app is unusable without content. Seed script deferred to the #53 fix |
| 2026-09-16 | Keep striped placeholder images locally; do NOT pull the real ones | Owner's call. The real files are only in production Cloud Storage and ADC is revoked, so fetching them means briefly restoring production access. None of the remaining register rows are about artwork, and layout/sizing are already testable with placeholders. Pointing Storage at production instead does not work: the rules need `request.auth != null` and the local user's token comes from the Auth emulator, which production rejects. **Do not re-open this without asking** — review artwork on a real device instead |
| 2026-09-16 | Emulators run as `demo-driveusa`, not `licenseprepapp` | `.firebaserc` points at production; a `demo-` project id makes reaching production physically impossible |
| 2026-09-16 | **Only the 30-day monthly plan is sold. Yearly is removed, not fixed** | Owner decision. Production has **zero** yearly subscriptions ever (register, verified 2026-08-20), so nobody is stranded. Turns #2 from a redesign into a deletion, #6 from an implementation into a removal, and makes #43 moot |
| 2026-09-16 | Emulators run under the REAL project id, not `demo-driveusa` | `FirebaseOptions` is a matched set; overriding only `projectId` leaves the real API key, so Firebase Installations calls `projects/demo-*/installations` with a key that does not belong to it. Owner chose to **revoke ADC first** (`gcloud auth application-default revoke`), so the machine now holds no production credentials at all — a stronger position than the `demo-` prefix gave |
| 2026-09-16 | Gate content rules on `users/{uid}.isActive`, and make trials write it | It is the server-maintained entitlement mirror the purchase path, renewal manager and schedulers already use. `createTrialSubscription` was the one path that never wrote it, so gating on it without that fix would have locked out every trial user |
| 2026-09-16 | Blocklist rather than allowlist for `users/{uid}` writes | Several services write profile fields dynamically (`email_sync_service` passes a computed map); an allowlist would break them. The blocklist covers the nine fields that decide entitlement, which is what #29 is actually about |
| 2026-09-16 | #13 anonymises billing records instead of deleting them | `privacy_policy.md` promises "all personal data deleted within 30 days" **and** "Subscription Data: Retained as required for billing and tax purposes" — two promises in tension. Stripping the personal link from `subscriptions` and `subscriptionLogs` honours both: the financial facts survive an audit, the person does not appear in them |
| 2026-09-16 | #14's reauth gate forced a change to the client fallback | The client fell back to a direct partial delete on **any** function failure — removing only `users/{uid}` while reporting success, and bypassing the new recent-login requirement entirely. A deliberate refusal is now rethrown instead of falling through; the fallback survives only for genuine unavailability, and is labelled PARTIAL in the log so it is not mistaken for a complete deletion |
| 2026-09-16 | #23 is fixed in two places on purpose | The auth trigger stops *new* accounts being orphaned, but does nothing for accounts already orphaned in production. `set/merge` in the two updaters heals those the moment the user touches a setting. Neither alone covers both populations |
| 2026-09-16 | #24 recovers the trial in `SubscriptionProvider.initialize`, not at login | It is the one place that already knows whether a subscription exists, and it runs on every session. Safe to retry because the server dedupes — `already-exists` for the user, `failed-precondition` for the device — so it either repairs a genuinely missed trial or is harmlessly refused. Guarded to one attempt per provider instance so a standing refusal is not a callable on every rebuild |
| 2026-09-16 | **REVERSED same day:** the trial is granted instantly, with no email-verification gate | I first built the gate (the owner picked it from options I wrote), then the owner corrected the product intent: **a registered user gets the 3-day trial immediately and is blocked only when it expires; verification is a step in the signup flow, not a gate on the trial.** The gate is removed and there are now tests asserting an unverified user still gets a trial, so a future hardening pass cannot quietly reverse it. Cost accepted: the trial is only as scarce as email addresses, which is #12's farming exposure. The durable answer is device attestation, not blocking new users at the door |
| 2026-09-16 | #58 was still worth doing, and stays | It was pulled in to soften the gate, but it is independently correct: it is the "trial expired — subscribe" state the owner wants, and before it that branch rendered nothing at all |
| 2026-09-16 | #26 anonymises `trialDevices` on account deletion rather than deleting it | The register frames the never-cleaned-up record as unfair to legitimate reinstallers, and deletion is also what risk #13 promises. But **deleting it would make account deletion the easiest possible trial-farming tool** — delete, re-register, collect another trial, repeat. Stripping `firstUserId` / `firstSubscriptionId` and keeping the hash satisfies the deletion promise while the gate keeps working |
| 2026-09-16 | #6 removes yearly from what is OFFERED, but keeps honouring its receipts | The register's wording ("drop from the server allow-list") would have recreated the defect one layer down: a legacy or in-flight yearly purchase would be charged and receive nothing, which is precisely #6's residual risk. Offering and honouring are separate decisions — the app stops selling yearly, the backend keeps accepting it. The locking invariant is a test: never offer a product whose receipt we would discard |
| 2026-09-16 | #9 bounds webhook retries rather than refusing them | The old comments ("Always return 200 — non-200 causes Apple to retry for our own bugs", "Do NOT rethrow") were guarding against retry storms, which is a real concern. Bounding retries by a persisted attempt count on the dead letter gets redelivery for transient failures without letting a permanent bug loop forever. After the budget, the platform is acked and the record is parked for manual replay |
| 2026-09-16 | #7 measures grace in elapsed time, not scheduler passes | Counting passes was the wrong unit: the renewal queries are capped at 100 documents per run (#25), so "3 attempts" meant three pickups, not 18 hours, for anyone behind a backlog. Elapsed time from `nextBillingDate` cannot be distorted by scheduler delay |
| 2026-09-16 | The #3 entitlement gate now shares the same grace window | The gate required `nextBillingDate > now`, which reproduced #7 one layer up: it would lock out a paying customer the moment a renewal ran late, while the store was still retrying. Both now read `isWithinStoreGrace`, so the scheduler and the gate cannot disagree about who is entitled. **Tradeoff:** a stale-active document the scheduler never reaches is now honoured for up to 30 days past expiry instead of 0 |
| 2026-09-16 | #22 keys document reuse on receipt identity, not on relaxing the `isActive` filter | The obvious fix — dropping `isActive == true` from `findExistingSubscription` — would reintroduce **BUG RV-C1**, where a dead trial gets resurrected into a paid plan with stale fields. Matching on `originalTransactionId` / `androidPurchaseToken` instead reuses only documents that genuinely represent the same store subscription. A dead trial carries no receipt identity, so it still falls through and a clean document is created. There is a named regression test for exactly this |
| 2026-09-16 | #20 falls back to built-in defaults rather than failing the purchase | The customer has already been charged by the time `getSubscriptionMetadata` runs. Failing shut costs them a purchase they paid for; falling back costs an operational alarm. Firestore still wins whenever a row exists, and an unknown product id with no default is still refused |
| 2026-09-16 | #19 keeps the Firestore query shape byte-identical | The existing production composite index on `subscriptionLogs (userId, timestamp, action)` serves the current triple-action query. Splitting it in two, or dropping the action filter, would need a *different* index — and `firebase.json` does not deploy indexes (#15), so a query-shape change could break **every** purchase in production. Success/failure partitioning is done in code instead |
| 2026-09-16 | The rate limiter now fails OPEN | It exists to deter abuse, not to be the reason a paid purchase fails. Its call site sits outside `validatePurchaseReceipt`'s try block, so a Firestore error there surfaced as a bare `internal` **after the customer was charged**. Abuse stays bounded by store-side receipt verification and the #5 receipt→account binding. Tradeoff accepted knowingly: during a Firestore outage, validation rate limiting is off |
| 2026-09-16 | #5 fixes the binding; the webhook `.limit(1)` fan-out is deferred to #22 | The register lists `.limit(1)` as a *compounding* factor of #5, not part of its fix. Fanning a webhook update across N documents means restructuring two large handlers that build one update block for one ref — that is exactly what #22 is about. Interim: the limit is removed and duplicates are logged, so the condition is visible instead of silent |
| 2026-09-16 | Superseded the 2026-04-21 "accept receipt sharing as known-issue" decision | Owner asked for #5 directly on 2026-09-16. The earlier reasoning (time-limited, self-healing, zero revenue impact) was about shipping under deadline, not about the defect being acceptable long-term |
| 2026-09-17 | Email verification is a **code**, not a link | A link has to travel through `/__/auth/action`, which `firebase.json` rewrites to `password-reset.html` for every mode — a page with no `verifyEmail` handling at all — and it needs the Associated Domains entitlement that only became real in #30 and is still unverified on a device. A 6-digit code avoids both and was testable the day it was written. It also closes register owner-action 3 by design rather than by fixing the rewrite |
| 2026-09-17 | The mail transport **throws** in production rather than falling back | #35 was not "we picked the wrong mail library", it was "the code claimed to send mail it never sent". A silent fallback to a logging transport would reproduce that exactly, one layer down. Locally the log transport is used and says so (`transport: 'log'`); in production a missing key is a misconfiguration and must be loud |
| 2026-09-17 | nodemailer **removed**, not kept at the upgraded version | Resend is an HTTP API, so no SMTP client has any future role here. Removal clears the same 8 Dependabot alerts as the upgrade did, and also deletes a dependency that shipped in the deployed bundle while being imported by nothing |
| 2026-09-17 | The verification code screen sits **after email+password, before state selection** | Owner-confirmed. It also fixes the original cache-prefetch plan: prefetching "while the user types the code" is impossible, because state and language are not known until the state screen. The prefetch moves to state-confirm instead |
| 2026-09-17 | The functions suite runs serially | Two suites both call `processExpiredSubscriptions`, which is global by nature. Scoping fixtures is not enough when the function under test ignores scope. See Gotchas |
| 2026-09-17 | #15 **adds** index entries and keeps every existing one | `firebase deploy` offers to delete indexes that are in the project but not in the file. Rewriting the file from scratch — even to something more "correct" — is therefore a way to drop working production indexes. Keeping the three original entries means the first deploy can only add. The remaining exposure is indexes production has that nobody here can see, which is why the pre-deploy diff is an owner action rather than something claimed done |
| 2026-09-17 | #27 stores an unknown environment as `null`, never `production` | Defaulting to production would recreate the exact defect the row describes: something we are not certain about still counted as a real sale. For the same reason a renewal that does not know the environment omits the key instead of writing one, so it cannot quietly promote a known sandbox subscription into real revenue |
| 2026-09-17 | #34 is fixed structurally, not at the call sites | The register frames it as ~1,839 `print` calls, which reads as a 1,839-edit change. Rewriting that many call sites is a large diff with real regression risk, and `avoid_print` would then report 1,839 findings that bury real ones. Suppressing both paths in release — `debugPrint` reassigned, `print` dropped by the Zone — is ~10 lines, covers every call site including ones added later, and leaves debug diagnosis untouched. `avoid_print` stays off deliberately |
| 2026-09-17 | #35 makes the mocks return `false` rather than building a mail sender | The row has two halves: an audit trail that lies, and no way to send mail. The first is closed now and is the one that matters for the money-state log — `emailSent: true` for mail nobody received is worse than no record. The second needs a provider, a verified domain and `MAIL_API_KEY`, which are owner steps already specced. Building a half-real sender in between would produce the same false confidence in a new place |
| 2026-09-17 | #30 is done even though it can make a device build start failing | The entitlement was inert where it sat, so universal links have never worked and the email-verification deep link cannot be fixed without this. Making it real surfaces a latent provisioning gap rather than creating one — the App ID either has the capability or it never did. Recorded as an owner action so the failure is expected rather than mysterious |
| 2026-09-16 | Leave the `Pods-Runner.profile.xcconfig` warning alone | Runner's Profile config points at `Flutter/Release.xcconfig`. Debug and Release are correctly wired; only Profile builds (performance profiling, never shipped) are affected. Not a register risk, and editing Xcode build config on a security branch invites unrelated breakage |

## Gotchas

- **Images are missing locally until you seed them.** "Image unavailable" on a theory section or quiz question means the Storage emulator is empty, not that the app is broken — the log line is `Firebase Storage: Unknown error - No object exists at the desired reference`. Run `scripts/local/seed-emulator-images.js` (144 flat-colour placeholders, colour derived from the path so different images stay visibly different). They are obvious placeholders; the real pictures only exist in production.
- **The emulator restarts empty.** No import/export is configured, so stopping the emulators wipes Firestore and Auth. After every restart, re-run `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/local/seed-emulator.js` (6,627 content docs) and sign up again.
- **The simulator can never get a trial through the app.** `createTrialSubscription` refuses with `failed-precondition: Trial unavailable on this device` unless `isPhysicalDevice === true`. That gate is pre-existing (commit `eab687b`) and correct — a real iPhone gets the 3-day trial instantly on signup. Locally, use `scripts/local/grant-local-trial.js <email>`, which writes exactly what a real device would have received. Verified end to end 2026-09-16: trial banner shows "Free Trial Active — Days left: 3" and the Theory tab lists all modules.
- **firebase-tools stubs `firebase-admin` and breaks `admin.firestore.*` statics.** Fixed in commit `6028011` by importing `FieldValue`/`Timestamp` from `firebase-admin/firestore`. If this ever regresses, the symptom is every timestamp-writing callable failing with `internal: INTERNAL` and the emulator logging "Cannot read properties of undefined (reading 'serverTimestamp')" — production is unaffected, so it only ever shows up locally.

- `.firebaserc` pins `licenseprepapp` (production). Always pass `--project demo-driveusa` to emulator commands.
- `functions/service-account.json` exists locally and is untracked. It has production write access — only ever use it for the read-only export.
- `functions/.env.licenseprepapp` is still **tracked in git** (risk #32). `.gitignore` lists it but gitignore does not untrack. Needs `git rm --cached` — separate cleanup, not part of this branch.
- Do not run `initializeGlobalCounterFromExistingReports` or `resetGlobalCounter` against anything (register Top-7 item 5).

## Root causes found while building the environment

**The app could not reach the emulator, and it was not a networking problem.**
`analytics_service.dart:42` called `Firebase.initializeApp()` a **second time, with
no options**, right after `main()` had initialised the default app with explicit
ones. On iOS that re-reads `GoogleService-Info.plist` and discards the emulator
settings applied moments earlier. Guarded with `if (Firebase.apps.isEmpty)`.
This is a real latent bug in the app, not a local-setup quirk — the redundant
call is in the shipped build too.

Diagnostic left in place (`🧪 Firestore settings -> host=… ssl=…` plus a probe
read) because it makes a silent misconfiguration loud. It only runs under
`USE_EMULATOR`.

## Reproduced evidence

### Risk #58, live on the simulator

Signing up in the app creates the `users/{uid}` document but **no subscription
and no entitlement**, and the screen says nothing about it. Cause:
`createTrialSubscription` throws `failed-precondition` unless
`isPhysicalDevice === true`, and a simulator is not a physical device. The gate
is working as designed; the defect is that the app renders `SizedBox.shrink()`
for that state instead of an explanation (#58).

Consequence for local work: **the simulator can never obtain a trial through the
app.** Use `scripts/local/grant-local-trial.js <email>` (with
`FIRESTORE_EMULATOR_HOST` set), which writes exactly what
`createTrialSubscription` would, including the `users/{uid}` entitlement mirror.

## Observed once, not reproduced

`Error in createOrUpdateUserDocument: TypeError: Cannot read properties of
undefined (reading 'serverTimestamp')` appeared in the emulator during one
signup. A focused test calling that callable passes, and
`admin.firestore.FieldValue.serverTimestamp` is defined in the test runtime.
Most likely the emulator hot-reloaded `functions/lib/` mid-rebuild. **Not
fixed, not claimed fixed** — re-check if it recurs on a stable build.

### Risk #3 evidence

**Risk #3, 2026-09-16.** An unauthenticated call to `getQuizQuestions` (no `context.auth` whatsoever) returned:

```
{"id":"q1","correctAnswer":0,"explanation":"A red octagon is always a stop sign.", ...}
```

The answer key and explanation are served to an anonymous stranger. Reproduce with `cd functions && npm test`.

## Follow-ups created by this work

- **The auth translations want a native-speaker review (#50).** The Spanish, Polish, Russian and Ukrainian strings for the 48 new auth keys are mine. They are standard UI phrasing and read naturally, and the Russian login screen was checked on device, but nobody who speaks these languages has read them. Worth one pass before release.
- **~441 inline `_translate` literals remain in 9 screens (#50, deliberately not touched).** `profile_screen`, `state_selection_screen`, `personal_info_screen`, `exam_screen`, `test_screen`, `quiz_question_screen` and three widgets keep per-file translation maps instead of using the JSON files. Nothing renders in the wrong language today — those maps do carry real translations — so this is consistency, not a bug. Moving them is a large refactor whose main risk is introducing the raw-key rendering that `localization_coverage_test.dart` now guards against. Do it only with that test in place.

- **There is still no "my reports" screen (#45 follow-up).** The rules and the query are correct now — a user may read reports carrying their own `userId`, and `getUserReports` is a cheap equality query instead of a denied whole-collection read. But `getCurrentUserReports` has **no callers in `lib/`**, so nothing surfaces reports to the person who filed them. Building that is a feature, deliberately out of scope here. Until it exists, reporting is still one-way from the user's point of view, even though the data layer no longer prevents it.
- **The 6 failing `counter_service_test.dart` tests are a harness gap, not a bug** (diagnosed 2026-09-16). Every one fails with `[core/no-app] No Firebase App '[DEFAULT]' has been created` — `CounterService` builds `FirebaseFirestore.instance` in a field initialiser, and the test never calls `Firebase.initializeApp`. Pre-existing on base `84300d0`. Fixing it means either a mock Firebase in `setUpAll` or injecting the Firestore instance; neither is in any register row.

- **The `anonymous_user_configured` analytics event is now misnamed** (#46 follow-up, `main.dart:491`). It fires on the branch where no local user is loaded — which used to coincide with an anonymous Auth session and now just means "not signed in". Left alone deliberately: renaming an analytics event breaks continuity in whatever dashboards already chart it, which is the owner's call, not a code cleanup.

- **`ContentLoadingManager` still never reloads content, even now that its listener fires (#41 follow-up).** Both callbacks are guarded by `_hasInitializedContent`, which is only set inside `initializeContent()` — and nothing calls that. So a state or language change reaches the manager and it logs "skipping content update". Fixing #41 was the prerequisite (before it, the state listener could not fire at all); making the manager actually do its job needs someone to decide where `initializeContent()` belongs in the startup sequence, or to conclude the manager is redundant now that each screen fetches its own content and remove it. Not decided here.

- **`preloadRelatedContent` would crash on first use — left alone deliberately.** `content_provider.dart:499` does `orElse: () => null as TrafficRuleTopic`, which throws whenever the topic is not already in `_topics`; the `if (topic == null)` below it is unreachable. `flutter analyze` reports both. It is currently harmless because the method has **zero callers** (`grep -rn "preloadRelatedContent" lib test` finds only its own declaration), so it is dead code rather than a live crash. Not fixed during #38 to keep that change surgical. Either fix it with `firstWhereOrNull` and wire up a caller, or delete it — dead code that crashes on first use is worse than no code.

- **#3 follow-up, done 2026-09-16 (commit `15a662f`).** The gate worked but the app never said so: the Theory tab showed *"No theory modules found ... for state 'ILLINOIS' with your current language settings"*, blaming state and language for a paywall, and logged `theory_module_list_empty(reason: state)`. Three layers were swallowing the refusal, and fixing only the inner one did nothing — `firebase_content_api.dart` has an inner catch around the Functions call **and** an outer catch that returns `[]`, so the inner rethrow was caught again one line later. Both now rethrow when `isEntitlementDenial(e)`, across all four content fetchers. `ContentProvider` exposes `contentRequiresSubscription` (cleared on every fetch, so a refusal cannot outlive a purchase) and no longer calls `loadHardcodedTopics()` on a denial — that outage fallback had been serving bundled content to exactly the users the server had just refused, a partial paywall bypass. Theory, traffic-rules and topic-quiz screens render `SubscriptionRequiredView`. Verified on the simulator with an unentitled account.

- **App Check / attestation is planned but deferred** — written up in the vault at `wiki/driveusa/Development/infra/app-check-attestation-plan.md` (linked from the infra index). Covers what it fixes, what it does not, the console/Apple/Play prerequisites, and why enforcement must be staged against a single production project.
- **#26 is partial, and the remaining part is not a code fix.** `deviceIdHash` and `isPhysicalDevice` arrive from the client, so a modified build sends any 64-hex string with `isPhysicalDevice: true` and collects an endless supply of trials. No server-side check can close that: the server cannot tell a real device from a claim about one. It needs **device attestation** — Firebase App Check with DeviceCheck (iOS) and Play Integrity (Android). The register already calls for App Check under risk #3. Until then the device gate is a speed bump, not a control, and `isPhysicalDevice` in particular blocks only honest simulator users — which is why local testing needs `scripts/local/grant-local-trial.js`.
- **The iOS device hash is weaker than it looks.** Memory from an earlier session: the Keychain UUID it derives from is wiped on uninstall, so delete-and-reinstall already yields a fresh hash and therefore a fresh trial — without any client modification at all. Attestation would not fix this either; it needs a server-side identifier that survives reinstall, or accepting that trials are per-install.

- **#9 is only half done, deliberately.** The register's action for it is two things: a failure path (done) and *"a daily reconciliation job that re-reads store state for any subscription whose nextBillingDate has passed"* (not done). Reconciliation genuinely needs live Apple/Google API calls — it cannot be written or verified against the emulator, and a half-built version that silently reconciles nothing would be worse than none. It also needs the `admins`/credentials story settled. **Recommend doing it as its own piece of work with store sandbox access.** What exists now means a failed webhook is retried and, if it still fails, recorded rather than lost — which is the part that stops silent data loss.

- **Play type 9 (DEFERRED) and 20 (PENDING_PURCHASE_CANCELED) are still unmodelled.** Both are now *named* in `play-notifications.ts` and fall through to the `handled: false` branch, which logs a warning instead of passing silently. Out of #8's scope (the register names only 10 and 11). DEFERRED matters slightly: it pushes the billing date out, so `nextBillingDate` goes stale and the renewal scheduler reads the subscriber as `past_due` — harmless now that grace is 30 days (#7), but worth modelling if deferrals are ever used.

- **Gap in the #5 work, found during #20 and fixed there.** `validatePurchaseReceipt`'s outer catch flattened every error into `internal`, including the `permission-denied` the receipt-binding guard raises. The #5 tests passed because they call `createOrUpdateSubscription` directly. The catch now rethrows `HttpsError` unchanged. **End-to-end verification of that specific path is still missing** — reaching it needs a live Apple/Google response, so it is verified by the direct-call test plus inspection, not by an end-to-end test.

- `lib/models/user_subscription.dart:isUpgradeEligible` is dead code — and was already dead at the base commit `84300d0` (zero callers), so it is **not** an orphan this work created. Natural cleanup during #6, when yearly leaves the codebase.
- `lib/docs/server_side_subscription_management_implementation.md:672` documents the now-deleted test-data generation system. Stale; left alone deliberately (documentation drift, not a security fix).
- `docs/webhook.md` asks twice for `handleMockPaymentWebhook` to be removed before production. Now done — that document can drop the warning.
- Register Top-7 #2 suggests counting `subscriptionLogs` where `processedBy == 'scheduled_function'` to see how much audit trail `cleanupSubscriptionTestData` already destroyed. **Not done** — it needs a production read, and this machine deliberately has no production credentials now. Owner call.

### More gotchas

- `pod install` needs `export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`, otherwise CocoaPods 1.16.2 on Ruby 3.4 dies with `Encoding::CompatibilityError`. It exits non-zero but a piped `tail` will mask it — always check `Podfile.lock`'s date.
- Xcode warns that `Runner` has a custom base configuration so CocoaPods did not set `Pods-Runner.profile.xcconfig`. Pre-existing, affects Profile builds only. Not touched.
- `functions/package.json` pins Node 22; the machine's default is Node 20. Every functions command needs the PATH prefix.
- **The functions suite runs SERIALLY (`maxWorkers: 1`), on purpose.** All 27 suites share one Firestore and Auth emulator, and several call functions that are global by nature — `processExpiredSubscriptions` sweeps every expired trial in the collection, whoever created it. Two suites calling that at once cannot be scoped apart: one deactivates the other's fixtures. That failed roughly one run in three before it was pinned. Do not "speed the suite up" by restoring parallel workers without solving that first; it costs ~100s against ~60s, which is the right trade for a suite that is emulator-IO bound anyway.
- **Tests must scope their queries to their own data.** `scheduler-uncapped` used to assert on the whole `subscriptions` collection and delete every trial in it during setup. Global assertions against a shared emulator are fragile by construction — prefer asserting on documents the suite created itself.
- **A `defineInt` with `default: 0` still prompts.** Both `APPLE_APP_ID` and `SUBSCRIPTION_LOG_RETENTION_DAYS` declare a default of `0`, and the Firebase CLI asks for them anyway — `firebase emulators:start` hangs forever on `? Enter an integer value for ...`, and a real `firebase deploy` would do the same. Both are now supplied in `functions/.env.local` (emulator) and `functions/.env.licenseprepapp` (deploy); **both files are untracked**, so a fresh clone hits this again. If a future param is added with a falsy default, add it to both files in the same commit.
- The functions emulator prompts for `APPLE_APP_ID` and hangs forever if unanswered. `functions/.env.local` supplies it. **Note:** the code declares `defineInt('APPLE_APP_ID', { default: 0 })` — so if it is unset in *production*, Apple notification verification runs against app id `0`. That is the unverified item in the register's Top-7 #5, and the default confirms the failure mode is real.
- Since ADC now exists, the functions emulator warns that **non-emulated** Google APIs will hit production with those credentials. Emulated services (Firestore/Auth/Storage/Functions) are unaffected. Run `gcloud auth application-default revoke` once the content export is no longer needed.
- Test fixtures use the synthetic `state: 'ZZ' / language: 'zz'` so they cannot collide with the 6,627 seeded production documents.
- **The functions emulator runs `functions/lib/`, not `functions/src/`.** After any TypeScript change run `npm --prefix functions run build`, or the emulator keeps serving stale compiled JS. `npx jest` uses ts-jest on the source, so tests can pass while the emulator still runs old code — they disagreed for most of this session's first hours.
- When the long-running emulator is already up, run `npx jest` directly. `npm test` wraps `emulators:exec`, which will fail on the already-bound ports.

## TODO — work that needs another machine, or a decision

> **The full list now lives in the vault:**
> `wiki/driveusa/Development/driveusa-remaining-work.md` — every open item split
> Mac / Windows / either machine / owner. **40 items, 12 of which block a
> release.** Built 2026-09-18 from the union of the risk register, this file,
> the Android checklist and `owner-console-actions`, so it is the one place to
> look for "what is left". The sections below stay because they carry the
> *reasoning* the list only summarises.

> **The Android half of this list now lives in the vault**, at
> `wiki/driveusa/Development/infra/android-verification-checklist.md`, because
> the vault is what syncs to the Windows PC — a checklist buried on a branch
> would not be readable from the machine that has to run it. It covers the
> missing Gradle verification, #31 signing and ProGuard, the #34 release-logging
> change, `minSdkVersion`, and the post-deploy purchase checks. Keep it there,
> not here.



Deferred deliberately (owner's call, 2026-09-17): these cannot be verified on
this Mac, and are not worth chasing before a real device is in hand. Each row
gives the symptom to watch for and the fix, so nobody has to re-derive it.

### 1. iOS Associated Domains entitlement (#30)

**When:** the first build onto a real iPhone, or the first archive for
TestFlight. Simulator builds are unaffected and will keep working.

**Likely outcome: nothing happens.** The Runner target uses automatic signing,
and Xcode usually adds a missing capability to the App ID by itself.

**Symptom if it does go wrong:** the build fails at the signing step, with
wording like *"Provisioning profile ... doesn't support the Associated Domains
capability"* or *"doesn't include the com.apple.developer.associated-domains
entitlement"*.

**Fix, about two minutes:**
1. [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) → Identifiers → `com.driveusa.app`
2. Tick **Associated Domains**, Save
3. Xcode → Settings → Accounts → **Download Manual Profiles**
4. Build again

**Escape hatch:** if it blocks a release and there is no time, delete the
`CODE_SIGN_ENTITLEMENTS` line from the three Runner configurations in
`ios/Runner.xcodeproj/project.pbxproj`. That restores the previous behaviour —
the app builds, and universal links stay broken, which is where they were
before this branch anyway.

**While the device is out:** universal links also need an
`apple-app-site-association` file served from `licenseprepapp.web.app` and
`licenseprepapp.firebaseapp.com`. Without it the entitlement is necessary but
not sufficient. Test by tapping a verification link in Mail: it should open the
app, not Safari. This and the `/__/auth/action` rewrite (owner action below) are
the two halves of the dead email-verification link — check them together.

### 3. Dependency advisories — nodemailer done, the Firebase tree is not

**nodemailer: REMOVED 2026-09-17** (`c857083`, superseding the earlier upgrade in
`61e8f22`). Resend is an HTTP API, so no SMTP client is needed at all. This
clears 8 of the 9 Dependabot alerts including both highs. Zero behavioural
risk — nothing imports it. Upgraded rather than removed so the #35 decision
stays open; removal is probably right once a provider is picked, since Resend,
Brevo and SendGrid are all HTTP APIs needing no SMTP client.

**The alerts will not drop on GitHub until this branch merges**, because
Dependabot raises them against the default branch.

**What remains, and it is bigger than the Dependabot count suggested.**
`npm audit --omit=dev` — production dependencies only, which is what actually
deploys — reports **25 advisories (4 critical, 8 high)**. Dependabot showed 9;
the two tools measure different things, so do not read the smaller number as the
whole picture.

All four criticals trace to one chain:

```
firebase-admin@12.7.0 → @firebase/database-compat → @firebase/database
  → faye-websocket@0.11.4 → websocket-driver@0.7.4   (critical)
```

That is the Realtime Database client, which this project does not use — it
arrives with `firebase-admin` regardless. Current versions:

| Package | Current | Latest |
|---|---|---|
| `firebase-admin` | 12.7.0 | **14.4.0** (two majors behind) |
| `firebase-functions` | 7.0.6 | 7.4.0 (minor) |
| `googleapis` | 169.0.0 | 181.0.0 |
| `axios` | 1.13.2 | 1.20.0 |

**Do not run `npm audit fix --force`.** It would move `firebase-admin` across
two majors on the functions that handle every payment, unattended. The sane
order is `firebase-functions` 7.0.6 → 7.4.0 first (a minor, and the emulator
already warns about it), then `axios`, then `firebase-admin` as its own piece of
work with the full suite run after. Treat it as a tracked task, not a quick fix.

### 3b. The original finding, for context

Checked 2026-09-17. All nine open alerts are in `functions/`, and **eight of
them — including both "high" ones — are `nodemailer`**, pinned at `^7.0.6`
against a fix in `9.1.1`.

The useful part: **nothing imports nodemailer.** The import at
`subscription-manager.ts:5` is commented out, the `createEmailTransporter`
helper that would have used it is inside a comment block, and the remaining
matches are prose. It is a direct dependency shipped in the functions bundle
that no code path can reach — the same dead weight risk #35 describes, now also
carrying the repo's only high-severity alerts.

Two ways to close it, and the choice belongs with #35:

- **Upgrade** `nodemailer` and `@types/nodemailer` to `^9.1.1`. One line, zero
  behavioural risk because nothing imports it. Clears 8 alerts.
- **Remove both packages.** Also clears 8 alerts and deletes the dead weight.
  Worth preferring *if* #35 lands on Resend, Brevo or SendGrid, because those
  are HTTP APIs and need no SMTP client at all. Nodemailer is only worth keeping
  if the decision is to send over raw SMTP.

The ninth alert is `qs` (medium, `>= 2.2.5 < 6.16.0`), which is **transitive**,
not declared in `functions/package.json`. It most likely arrives via
`firebase-functions` — which the emulator already warns is outdated — so
updating that dependency is the thing to try before reaching for an `overrides`
entry.

None of this is a register row and none of it is urgent: the vulnerable code is
unreachable. But it is cheap, and it is the whole of the repo's alert list.

### 4. Gradle build to verify the dead-buildscript removal

> **✅ DONE 2026-09-19 on the Windows machine. See THE WINDOWS RUN above.**
> `004d043` **stands — do not revert.** The release build succeeds with the
> block removed and the bundle stamps `androidGradlePluginVersion=8.13.0`.
> Stronger than asked for: a build with the block *still present* also stamps
> 8.13.0, so the classpath was provably inert rather than merely argued to be.
> Correction to the note below and to the checklist: `004d043` is **not** an
> ancestor of `local/security-money-hardening` — it is the one commit on `main`
> the branch lacks, so a plain branch build does not cover it. It was verified
> by applying the patch locally, building, and reverting.


`chore/remove-dead-buildscript` was merged into `main` on 2026-09-17 at the
owner's request (`004d043`). Its own commit message asks for a Gradle build
before merging, and **that has still not happened** — neither the authoring
machine nor this Mac has an Android SDK.

The static reasoning is sound and the evidence is good: the Windows release
build of `84300d0` stamped `androidGradlePluginVersion=8.13.0`, the version from
`settings.gradle:21`, proving the removed block's `8.4.0` classpath was ignored.
The failure mode is also contained — if that block were load-bearing, Gradle
fails loudly at build time rather than shipping anything broken.

**Fold this into the same Windows session as #31**, which needs that machine
anyway: run a release build, confirm it succeeds, and confirm the bundle still
reports AGP 8.13.0. If it fails, `git revert 004d043` restores the block.

Note that `main` is no longer byte-identical to the commit that produced the
live 1.0.5 build — `84300d0` is, and `004d043` adds this one unverified change
on top.

### 2. Practice tests, and the renewal scheduler (found 2026-09-17 via #15)

The index diff showed production was missing two indexes its own code needs.
Both were deployed on 2026-09-17, so both should now work — but neither has
been exercised against production, so confirm rather than assume:

- **Practice tests.** Production held **no** `practiceTests` index at all, while
  `getPracticeTests` filters on three fields and orders by a fourth. That query
  cannot have been served. On device, open the practice-test list and confirm it
  populates.
- **Renewals.** Production held `subscriptions (trialUsed, status, nextBillingDate)`
  — the query shape from *before* the SM-MOD-2 fix added the `isActive` filter.
  The index never followed the code, so `renewActiveSubscriptions` was likely
  failing. Check the Cloud Functions logs for that scheduler after the next run
  and confirm it no longer reports a FAILED_PRECONDITION / missing-index error.

## Crash reporting — added 2026-09-17 (`8ae1f8a`)

The app previously had **none** — no Crashlytics, no Sentry, nothing anywhere.
Combined with #34 silencing logs in release, a crash in the field was invisible.

**Pinned to `firebase_crashlytics: 5.0.0`, exactly, and that matters.**
`flutter pub add` resolved 22 dependencies: it bumped `cloud_firestore`
6.0.0 → 6.10.0, `firebase_auth`, `firebase_storage` and 17 others, and the newer
Firebase iOS SDK then demanded a deployment target above 15.0 — **the iOS build
failed outright**. Hiding in that were two things nobody asked for: a Firebase
SDK upgrade underneath the payment code, and a rise in the minimum iOS version.
5.0.0 matches the `firebase_core` 4.0.0 already in the lock, reducing it to a
two-package addition with `in_app_purchase_android` 0.5.0 untouched.

**If you ever add another Firebase package here, check `git diff pubspec.lock`
before trusting it.**

**Collection is OFF in debug.** There is no Crashlytics emulator — anything
collected goes to the real project. Verified on the simulator:
`firebase_crashlytics_enabled = 0`, so nothing was sent to production.

**dSYM upload is now wired** (`487992b`) — and its first version **broke the
build**: the upload script exits non-zero on simulator builds with "Could not get
GOOGLE_APP_ID", failing everything. Fixed by skipping simulator builds outright
(they produce no dSYM) and passing `GoogleService-Info.plist` explicitly with
`-gsp`, because it is not in Copy Bundle Resources and the script cannot find it
alone. A clean simulator build was verified afterwards.

**The privacy policy was audited, not borrowed.** The owner asked to copy another
app's; that would describe someone else's practices. Three real findings: it
claimed to collect *billing information* (it does not — Apple and Google are
merchant of record), the hashed trial-deduplication device ID was undisclosed,
and the "do not collect" list omitted payment credentials and advertising IDs.

**Still open:**
- **The store privacy questionnaires must be updated to match**, or the release is rejected: App Store Connect → App Privacy → declare **Diagnostics / Crash Data**, and Play Console → Data safety → **Crash logs**. This is the step people forget and it blocks shipping.
- **Android is wired but unverified** — no Android SDK here. On the Windows checklist with #31.
- **The privacy policy wording is a draft** and wants the owner's read. It adds a Crash Diagnostics category and states explicitly that quiz answers, progress and screen contents are not collected.
- **No test crash has been fired.** That is the only real end-to-end verification and it writes to production Crashlytics, so it needs the owner's say-so.

## Owner action required outside the repo

- **Enable the Associated Domains capability for `com.driveusa.app`** — **deferred to the real-device test run at the owner's request (2026-09-17); see the TODO section above for the symptom and the fix.** (from #30). The entitlement was previously in `Info.plist`, where iOS ignores it, so it has never been exercised. Now that it is in a real `Runner.entitlements`, a device or archive build **will fail to provision** unless the App ID carries the capability in the Apple Developer portal. Simulator builds are unaffected, which is why this is not visible from this machine. Universal links also need `apple-app-site-association` served from `licenseprepapp.web.app` and `licenseprepapp.firebaseapp.com` — worth checking at the same time as the `/__/auth/action` rewrite problem below, since the two together are why the email-verification deep link is dead.

- ~~Diff the deployed indexes before the first deploy after #15~~ — **done 2026-09-17, and it mattered.** The owner ran `firebase firestore:indexes --project licenseprepapp`: **8 of production's 11 indexes were absent** from the file derived from the query code, so a `--force` deploy would have offered to delete all eight. Worst of them, this file's own claim was wrong — the receipt rate-limit index is `subscriptionLogs (action, userId, timestamp)`, not `(userId, timestamp, action)`. The two entries that predated this branch were stale too: production holds neither of them. `firestore.indexes.json` is now production's 11 verbatim plus three genuine gaps, and **`firestore:indexes` was deployed to production on 2026-09-17** — 0 deletions, 3 additions, verified by re-reading the index list afterwards. Rules were **not** deployed; the CLI only compile-checks them under `--only firestore:indexes`.

  **Standing rule from here on:** never run `firebase deploy --force` on this project. Re-run the diff whenever a query's filters change, and add the production index to both `firestore.indexes.json` and the `IN_PRODUCTION` list in `firestore-indexes.test.ts` in the same commit.

- **Migrate the web image from `gcr.io` to Artifact Registry** (the open half of #49, 2026-09-17). Google has deprecated Container Registry. This needs an Artifact Registry repository, `roles/artifactregistry.writer` for the Cloud Build service account, and an update to the Cloud Build trigger — whose definition is not in version control (#36). `cloudbuild.yaml` was deliberately left pointing at `gcr.io`, because repointing it before the repository exists breaks the web deploy instead of fixing it.

- **Split sandbox out of the revenue figures** (follow-up to #27, 2026-09-17). Subscriptions and `subscriptionLogs` now carry an `environment` field, but `getSubscriptionStats` does not filter on it, and every document written before this change has no field at all — which reads as unknown, not as production. Deciding how to treat those historical rows is an owner call; the honest options are to leave them unknown, or to backfill from the store reports.


- **Delete the anonymous Auth users already in production** (from #46, 2026-09-16). The app no longer creates them, but every one made before this change is still there, inflating the Auth user count and its billing. They are identifiable in the Firebase console by having no provider and no email, and none of them has a `users/{uid}` document. Deleting them needs Admin SDK access against production, which this machine deliberately does not have. Safe to remove: an anonymous account that was never linked cannot be signed back into, and nothing in Firestore references it.

- **`subscriptionLogs` retention: no action needed — leave `SUBSCRIPTION_LOG_RETENTION_DAYS` at 0** (from #40, revisited 2026-09-16). The switch exists if it is ever wanted, but checking the actual constraints says not to use it:
  - `privacy_policy.md:107` promises subscription data is *"retained as required for billing and tax purposes"* — open-ended, so keeping it breaks no commitment.
  - `privacy_policy.md:108` promises personal data is gone within 30 days of account deletion, and #14 satisfies that by **anonymising** these rows (userId replaced), not deleting them. So a deleted user's rows are no longer personal data and retention does not conflict with the promise.
  - Cost is negligible: roughly 3 rows per active subscriber per month at ~1.5 KB all-in including index entries. At 10,000 subscribers that is ~45 MB/month, about ten cents a month of Firestore storage after a full year.
  - The query-performance half of #40 is already fixed by the scan cap, and does not depend on collection size.

  If a number is ever needed for a policy document, **24 months** is the usual range for billing audit logs. Note that the 7-year figure people reach for applies to financial and tax records — Apple and Google are the merchant of record here, so the authoritative tax records are the store payout reports, not these rows. Worth confirming with whoever handles compliance before publishing a number. Setting it is one config value and the sweep already handles it.

- **Bump the content version after editing content** (from #47, 2026-09-16). `getContentVersion` reads `contentMeta/current.version`; changing it makes every device drop cached content on next launch instead of waiting out a 24 h TTL. Without a bump, a content correction still takes up to 24 h to reach people — the mechanism exists now, but somebody has to pull the lever. `scripts/local/bump-content-version.js` does it against the emulator and is the model for production; there is no admin UI (risk #53). In production the document can also be edited by hand in the Firebase console: set `version` to any different integer.

- **Decide what happens to `scripts/deletion-manifest.json`** (raised 2026-09-16 during #52). It is the plan from a real destructive run against production — 452 users and 208 subscriptions deleted on 2026-04-18 — and it lists real Firebase Auth UIDs for the 7 accounts that were kept. It is untracked and gitignored, so it cannot reach git; the only remaining question is whether that record should stay on a dev machine at all. **Not deleted, because it is not reversible and it may be the only record of who was preserved.** The companion `deletion-log-20260418-122749.txt` holds counts only, no UIDs, and is harmless.

- ~~Four translation keys rendered as raw keys on screen~~ — **done, and the sweep is done too (#50).** `AppLocalizations.translate()` returns the KEY when a string is missing, never null, so a `?? 'fallback'` in calling code is dead and the user sees `no_subscription_title`. The register's count of 33 such keys was stale: a measured sweep found 109 distinct `translate()` keys in `lib/`, of which 2 were missing everywhere. All five locale files now carry identical key sets, and `test/localization_coverage_test.dart` fails the build if that ever drifts again. **No owner action.**
- **Check the email-verification deep link works in production.** `firebase.json` rewrites *every* `/__/auth/action` to `password-reset.html`, but verification links arrive as `/__/auth/action?mode=verifyEmail`. The app routes an `oobCode` to `EmailVerificationScreen` (`main.dart`), and that flow was dead code until now, so it has never been exercised with a real link. Worth testing end to end before this reaches users, or verification emails will land on the password-reset page.
- **`webhookDeadLetter` is a new collection holding raw Apple/Google payloads.** It is client-deny by rule, but it is store data about real users and has **no retention policy**. Fold it into the deletion and TTL work of risks #13 and #40, and check it periodically for `status: 'exhausted'` records, which are failures nobody has replayed.

- **Check production for receipts already shared across accounts.** The binding guard stops new sharing, but says nothing about rows created before it. Query `subscriptions` grouped by `originalTransactionId` / `androidPurchaseToken` and look for any value held by more than one `userId`. The webhooks now log `🚨 ... subscriptions share ...` if it happens live. Needs a production read, which this machine no longer has credentials for.

- **Provision an `admins/{uid}` document** (register risk #45). The collection is empty, so `processSubscriptionsManualy`, `getSubscriptionStats`, `subscriptionSystemHealth` and `getRenewalStats` are now callable by nobody — deliberate, but it means those stats endpoints stay closed until an admin exists. It also unblocks **admin triage** of filed `reports`. Note #45 changed half of this: a user can now read back reports carrying their own `userId`, so reporting is no longer write-only at the data layer — but nothing reads other people's reports without an admin document, and no screen surfaces reports to users yet either. Create it in the console; the collection is client-deny by rule.

- **Deactivate the yearly SKU in App Store Connect and Google Play Console.** Removing it from the code stops the app offering it, but if the SKU stays purchasable in either store a user could still buy it through a store-side resubscribe flow and receive nothing. Code alone does not close this.
- `subscriptionsType/2` (the yearly catalogue row) is left in production untouched — harmless once nothing references yearly, and deleting it would be a production write.
