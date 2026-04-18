# scripts/

One-off admin scripts for `license-prep-app`.

## delete-test-users.ts

Wipes pre-release test data from Firestore + Firebase Auth. Keeps only users whose `users.createdAt` falls inside `[2026-04-15 00:00:00Z, 2026-04-16 23:59:59.999Z]`.

For each user in the delete set:
1. All `subscriptions` where `userId == uid` are deleted
2. `savedQuestions/{uid}` is deleted (no-op if missing)
3. `users/{uid}` is deleted
4. Firebase Auth account is deleted

Users with missing `createdAt` are **kept** by default (conservative fallback) and listed in the manifest for manual review.

### Prerequisites

- `functions/service-account.json` present (already there, gitignored).
- Node 18+ installed.

### Install

```bash
cd scripts
npm install
```

### Dry run (default, safe)

```bash
npx tsx delete-test-users.ts
```

Output:
- Counts per bucket (KEEP / DELETE / UNKNOWN-createdAt / subscriptions-to-delete / orphans)
- First 10 UIDs of each bucket
- Full manifest written to `scripts/deletion-manifest.json`

**No database modifications happen in dry-run.**

### Execute (destructive)

```bash
npx tsx delete-test-users.ts --execute
```

- Prints a warning banner and waits 5 seconds (Ctrl+C to abort).
- Writes `deletion-log-<timestamp>.txt` with every operation.
- Tolerates `auth/user-not-found` on individual uids.
- Uses Firestore batches (≤500 writes) and Auth `deleteUsers` batches (≤1000 uids).

### After execution

Verify:
1. Firestore Console → `users` count equals the dry-run KEEP count.
2. Spot-check a kept user (can still sign in, subscription intact).
3. Spot-check a deleted user (gone from users, subscriptions, savedQuestions, Auth).
4. Check `scripts/deletion-log-*.txt` for any reported failures.

### Changing the keep window

Edit `KEEP_WINDOW_START_ISO` / `KEEP_WINDOW_END_ISO` at the top of `delete-test-users.ts`.

### Ignored files

`deletion-manifest.json` and `deletion-log-*.txt` are gitignored (they contain UIDs).
