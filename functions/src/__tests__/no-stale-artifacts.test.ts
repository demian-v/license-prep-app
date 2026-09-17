/**
 * Risk #52 — no stale rules copies, and no user PII, in the working tree.
 *
 * Two separate problems the register groups together:
 *
 * 1. `firestore.rules.backup` was a 2025-09 copy sitting beside the live rules.
 *    Nothing referenced it, so its only effect was to be read or deployed by
 *    mistake — an out-of-date rules file is a security regression waiting for
 *    someone in a hurry. Git history still has it if it is ever wanted.
 *
 * 2. `scripts/deletion-manifest.json` is the plan from a real destructive run
 *    against production (452 users, 208 subscriptions) and lists real Firebase
 *    Auth UIDs. `scripts/.gitignore` already stops it being committed, so this
 *    asserts that guard still holds rather than asserting the file is gone —
 *    whether to keep the record on disk is the owner's call, but it must never
 *    become committable.
 *
 * Asserting absence rather than correctness is deliberate: a file that is not
 * there cannot be deployed by accident.
 */
import * as fs from 'fs';
import * as path from 'path';
import { execFileSync } from 'child_process';

const REPO = path.join(__dirname, '../../..');

const FORBIDDEN_FILES = [
  'firestore.rules.backup',
  'firestore.rules.bak',
  'firestore.rules.old',
  'storage.rules.backup',
];

describe('Risk #52 — stale rules copies', () => {
  it.each(FORBIDDEN_FILES)('%s does not exist', (name) => {
    expect(fs.existsSync(path.join(REPO, name))).toBe(false);
  });

  it('the live rules files are still there (positive control)', () => {
    // Without this, deleting firestore.rules entirely would pass the suite.
    expect(fs.existsSync(path.join(REPO, 'firestore.rules'))).toBe(true);
    expect(fs.existsSync(path.join(REPO, 'storage.rules'))).toBe(true);
  });
});

describe('Risk #52 — deletion-run artefacts are not committable', () => {
  // These hold real user UIDs. They may legitimately sit on an operator's disk
  // as a record; they may never enter git.
  const ARTEFACTS = [
    'scripts/deletion-manifest.json',
    'scripts/deletion-log-20260418-122749.txt',
  ];

  const isIgnored = (relPath: string): boolean => {
    try {
      execFileSync('git', ['check-ignore', '-q', '--', relPath], { cwd: REPO });
      return true; // exit 0 = ignored
    } catch {
      return false;
    }
  };

  it.each(ARTEFACTS)('%s is gitignored', (relPath) => {
    expect(isIgnored(relPath)).toBe(true);
  });

  it('a normal source file is NOT ignored (positive control)', () => {
    // Guards against check-ignore silently succeeding for the wrong reason,
    // e.g. a blanket rule that ignores everything.
    expect(isIgnored('firestore.rules')).toBe(false);
  });

  it.each(ARTEFACTS)('%s is not tracked in git', (relPath) => {
    let tracked: boolean;
    try {
      execFileSync('git', ['ls-files', '--error-unmatch', '--', relPath], { cwd: REPO });
      tracked = true;
    } catch {
      tracked = false;
    }
    expect(tracked).toBe(false);
  });
});
