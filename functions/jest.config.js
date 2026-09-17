module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src/__tests__'],
  testMatch: ['**/*.test.ts'],
  setupFiles: ['<rootDir>/src/__tests__/helpers/env.ts'],
  testTimeout: 20000,
  // Serial, deliberately. All 27 suites share ONE Firestore/Auth emulator, and
  // several exercise functions that are global by nature — processExpiredSubscriptions
  // sweeps every expired trial in the collection, whoever created it. Two suites
  // calling that concurrently cannot be scoped apart: one deactivates the other's
  // fixtures and both assertions become order-dependent. That produced an
  // intermittent failure in scheduler-uncapped roughly one run in three.
  //
  // Parallel workers buy little here anyway — the suite is emulator-IO bound,
  // not CPU bound.
  maxWorkers: 1,
  // src/ is compiled by tsc for deploy; tests must not leak into lib/
  globals: { 'ts-jest': { diagnostics: false } },
};
