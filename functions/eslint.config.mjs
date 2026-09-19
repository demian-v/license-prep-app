// Lint for the Cloud Functions codebase.
//
// This project had NO linting at all before 2026-09-19 — no config, no
// dependency, no script. That was measured rather than assumed before setting
// it up, and the measurement is why this file is so short.
//
// With `strict: true`, `noImplicitReturns` and `noUnusedLocals` already on in
// tsconfig, TypeScript catches most of what a TS lint preset adds. Running the
// full type-checked preset found **zero real defects** across src/: one
// deliberate async-for-interface, two switches that already have `default:`
// cases, and 28 `no-explicit-any` style hits of which 10 already carried
// deliberate disable comments.
//
// So this enables only the rules that (a) TypeScript does not already cover
// and (b) report zero findings today. A linter nobody can keep green is a
// linter everybody turns off.
//
// Rules deliberately NOT enabled, with reasons:
//   no-explicit-any             style only; 28 hits, none of them defects
//   require-await               1 hit, and it is correct: LoggingEmailSender.send
//                               is async to satisfy the EmailSender interface
import tseslint from 'typescript-eslint';

export default [
  {
    ignores: ['lib/**', 'node_modules/**', 'src/__tests__/**'],
  },
  {
    // The `// eslint-disable-next-line @typescript-eslint/no-explicit-any`
    // comments in index.ts, play-notifications.ts and webhook-fanout.ts look
    // unused because that rule is off here. They are NOT vestigial — checked
    // 2026-09-18 by enabling the rule: every one of them suppresses a real
    // violation. Deleting them would silently break the day anyone turns
    // no-explicit-any on; warning about them every run is how a linter gets
    // ignored. So: keep them, say nothing.
    linterOptions: { reportUnusedDisableDirectives: 'off' },
  },
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        project: './tsconfig.json',
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: { '@typescript-eslint': tseslint.plugin },
    rules: {
      // The one that can find a real money bug here. An unawaited Firestore
      // write in a Cloud Function can be killed when the invocation returns —
      // silent data loss on the money path, and invisible to `tsc`.
      '@typescript-eslint/no-floating-promises': 'error',

      // An async callback passed where void is expected, or a Promise used in
      // a condition (always truthy). Same class of mistake, different shape.
      '@typescript-eslint/no-misused-promises': 'error',

      // A switch over Apple's NotificationTypeV2 or Play's notification types
      // that silently ignores a new member is exactly risk #8, which shipped.
      // `considerDefaultExhaustiveForUnions` is on because both switches here
      // already have a `default:` that handles the rest — without it the rule
      // objects to `undefined` not having its own case, which is noise.
      '@typescript-eslint/switch-exhaustiveness-check': [
        'error',
        { considerDefaultExhaustiveForUnions: true },
      ],
    },
  },
];
