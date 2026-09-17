# Firebase Configuration Guide — Cloud Functions secrets and params

> **Rewritten 2026-09-17 (risk register #10).** Every step in the previous
> version of this file was wrong in a way that leaves the payment path dead,
> and one of them deletes production Firestore indexes. What it got wrong, and
> why it mattered, is recorded at the bottom under
> [What the old guide said](#what-the-old-guide-said-and-why-it-failed-silently) —
> read that if you followed it before today.

This is the configuration an operator has to do **outside the repo** before
`firebase deploy --only functions` produces a working backend.

Project: `licenseprepapp` (there is only one — debug builds, TestFlight and
store releases all share it).

---

## The one rule that matters most

```
NEVER run firebase deploy --force on this project.
```

`--force` skips the confirmation prompt that asks whether to **delete**
Firestore indexes present in the project but absent from
`firestore.indexes.json`. On 2026-09-17 that prompt would have offered to
delete **8 of production's 11 indexes**. Answering it is the only thing that
stops a deploy from silently breaking every query behind those indexes.

Re-run the diff whenever a query's filters change:

```bash
firebase firestore:indexes --project licenseprepapp
```

This rule is about **`deploy`** specifically. `functions:secrets:set -f` is a
different command with a different meaning — it updates the functions that use
a secret to pick up the new version — and is fine.

---

## Step 1 — the three secrets

Secrets live in **Google Secret Manager**, declared in code with
`defineSecret()`. There are three, and each is attached to specific functions
with `.runWith({ secrets: [...] })`:

| Secret | Read by | Format |
|---|---|---|
| `APPLE_SHARED_SECRET` | `validatePurchaseReceipt` (`receipt-validation.ts`) | the App-Specific Shared Secret, verbatim |
| `GOOGLE_CREDENTIALS` | `validatePurchaseReceipt`, `handleGooglePlayNotifications` | **base64** of the service-account JSON |
| `RESEND_API_KEY` | the email-verification callables (`email/verification-callables.ts`) | the Resend key, verbatim |

```bash
firebase functions:secrets:set APPLE_SHARED_SECRET --project licenseprepapp
firebase functions:secrets:set RESEND_API_KEY --project licenseprepapp
```

Each prompts and reads the value from stdin. **Type or paste it at that
prompt and nowhere else** — not into a file, not into a commit, not into a
chat. The Apple shared secret leaked into git exactly once (risk #1) and had to
be rotated.

`GOOGLE_CREDENTIALS` is base64-encoded, because the code does
`Buffer.from(value, 'base64')` and then `JSON.parse`. Pipe it in rather than
letting it touch the shell history:

```bash
base64 -i functions/service-account.json | \
  firebase functions:secrets:set GOOGLE_CREDENTIALS --project licenseprepapp --data-file -
```

Verify the versions exist — this prints metadata, never the value:

```bash
firebase functions:secrets:describe APPLE_SHARED_SECRET --project licenseprepapp
```

**A newly set secret does not reach a running function.** Secret versions are
bound at deploy time, so after setting or rotating one you must redeploy the
functions that declare it, or they keep reading the old version.

---

## Step 2 — the two params, or the deploy hangs forever

These are **not** secrets. They are `defineInt` params, and if either is
unset the Firebase CLI stops and asks for it interactively:

```
? Enter an integer value for APPLE_APP_ID
```

`firebase deploy` and `firebase emulators:start` both hang there, with no
timeout. **A declared `default: 0` does not suppress the prompt** — both of
these declare one and both still prompt.

| Param | What it is | Value |
|---|---|---|
| `APPLE_APP_ID` | Apple's numeric app id, used to verify App Store Server Notifications | the numeric id from App Store Connect |
| `SUBSCRIPTION_LOG_RETENTION_DAYS` | pruning window for the `subscriptionLogs` audit trail | **`0`** — deliberately disabled; see below |

They are supplied by `functions/.env.licenseprepapp` (deploy) and
`functions/.env.local` (emulator):

```
APPLE_APP_ID=<numeric id>
SUBSCRIPTION_LOG_RETENTION_DAYS=0
```

**Both files are untracked**, so a fresh clone hits the hang again. That is
deliberate — `functions/.env.licenseprepapp` used to be committed (risk #32) —
but it means recreating them is part of setting up a new machine. If a future
param is added, add it to both files in the same commit.

> **`APPLE_APP_ID` unset in production is not harmless.** The default is `0`,
> so Apple notification verification would run against app id `0` and fail to
> verify anything, silently. This is why it is a checklist item and not a
> nice-to-have.

> **Leave `SUBSCRIPTION_LOG_RETENTION_DAYS` at `0`.** `subscriptionLogs` is the
> money-state audit trail, deletion is irreversible, and a scheduled job that
> deleted rows out of it by accident is what risk #4 was. The privacy policy
> does not require pruning it: deleted users' rows are anonymised rather than
> deleted (risk #14), so they are no longer personal data, and subscription
> data is retained "as required for billing and tax purposes". Cost is about
> ten cents a month at 10,000 subscribers.

---

## Step 3 — deploy

```bash
firebase deploy --only functions --project licenseprepapp
```

`firebase.json` has a `predeploy` hook that runs
`npm --prefix functions run build`, so the TypeScript is compiled first. Before
that hook existed (risk #16), `functions/lib/index.js` was **five months
stale** and a deploy shipped the previous payment logic. Do not remove it, and
do not deploy with `--only functions` from a tree that will not compile.

**Node 22.** `functions/package.json` pins it and this machine's default is
Node 20, so every functions command needs:

```bash
export PATH="/opt/homebrew/opt/node@22/bin:$PATH"
```

30 functions are exported from `functions/src/index.ts`.

---

## Step 4 — the platform wiring the old guide omitted entirely

Secrets alone do not make subscriptions work. Three things live in consoles, not
in this repo, and nothing in the code can check them for you.

### 4a. Google Play — Pub/Sub topic `play-rtdn`

`handleGooglePlayNotifications` is a Pub/Sub trigger on the topic **`play-rtdn`**
(the name is exact — it was renamed from `google-play-rtdn` to satisfy GCP
naming rules, and the function will simply never fire on the wrong name).

1. GCP Console → Pub/Sub → **Create topic**: `play-rtdn`
2. Grant `roles/pubsub.publisher` on that topic to
   `google-play-developer-notifications@system.gserviceaccount.com`
3. Play Console → Monetisation setup → **Real-time developer notifications** →
   topic `projects/licenseprepapp/topics/play-rtdn`
4. Use Play Console's **Send test notification** and confirm the function logs a run

### 4b. App Store Connect — Server Notifications URL

The endpoint is `appStoreWebhook`:

```
https://us-central1-licenseprepapp.cloudfunctions.net/appStoreWebhook
```

Register it in App Store Connect → your app → **App Information → App Store
Server Notifications** (Version 2). Without it, Apple renewals, cancellations
and refunds never reach the backend: the subscription document goes stale and
the renewal scheduler is the only thing left holding entitlement together.

### 4c. Check both after the first deploy

```bash
firebase functions:log --only validatePurchaseReceipt --project licenseprepapp
firebase functions:log --only handleGooglePlayNotifications --project licenseprepapp
firebase functions:log --only appStoreWebhook --project licenseprepapp
```

Also check `renewActiveSubscriptions` for `FAILED_PRECONDITION` or
missing-index errors after its next scheduled run — production held the
pre-`isActive` index shape until 2026-09-17, so it was very likely failing.

---

## Where things go wrong

| Symptom | Cause |
|---|---|
| Deploy or emulator hangs on `? Enter an integer value for ...` | A `defineInt` param has no value. Step 2. `default: 0` does not help |
| Apple validation fails with status **21004** | `APPLE_SHARED_SECRET` missing or wrong. 21004 means "shared secret does not match" |
| Apple validation fails with status **21002** | The receipt is a StoreKit 2 JWS, not a base64 app receipt. This is register #56, not a config problem — the client must keep `enableStoreKit1()` until the backend can read SK2 |
| `GOOGLE_CREDENTIALS secret not set in Secret Manager!` in the logs | Step 1, and remember it must be **base64** |
| Android validation and Play billing-date recovery both fail | Same secret; both paths use it |
| Email verification throws instead of sending | `RESEND_API_KEY` unset. It throws **on purpose** in production rather than pretending to send (risk #35). Locally it uses a log transport and prints the code |
| Play notifications never arrive | Topic name is not exactly `play-rtdn`, or the publisher IAM binding is missing. Step 4a |
| Config "isn't applying" after a deploy | A secret version is bound at deploy time. **Redeploy** — do not reach for `--force`, which is how indexes get deleted |

---

## What the old guide said, and why it failed silently

Kept because the failure mode is worth recognising, and because anyone who
followed the old version has values set that nothing reads.

- **It used `firebase functions:config:set apple.shared_secret=...`.** That is
  the v1 runtime-config API. This project is on `firebase-functions ^7`, where
  `functions.config()` no longer exists — and there is not a single call to it
  anywhere in `functions/src`. So the command *succeeded*, printed
  `✔ Functions config updated`, and stored values in a system the code never
  consults. Apple validation then failed with 21004 and Android validation
  failed outright, while the verification step in the guide reported success.
  That combination — a confirming command, a passing check, and a dead payment
  path — is why this row was ranked High for a documentation file.
  Clean up any leftovers with `firebase functions:config:unset apple google`.
- **It recommended `firebase deploy --only functions --force`** to make config
  apply. `--force` suppresses the index-deletion prompt.
- **It said Node 18.** It is Node 22.
- **It omitted `APPLE_APP_ID` and `SUBSCRIPTION_LOG_RETENTION_DAYS`**, the two
  things that make a deploy hang with no output.
- **It omitted `RESEND_API_KEY`**, the `play-rtdn` topic, and the App Store
  Connect webhook registration — so even a correct secret setup left Play and
  Apple notifications unwired.
- **It contained the pre-rotation Apple shared secret** in four places, and
  hardcoded one developer's absolute home directory into every command.
- **It claimed "Production Ready: ✅ YES!"** The register lists 59 risks against
  this system, two of them Critical and live in production at the time that
  line was written.
