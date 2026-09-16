module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src/__tests__'],
  testMatch: ['**/*.test.ts'],
  setupFiles: ['<rootDir>/src/__tests__/helpers/env.ts'],
  testTimeout: 20000,
  // src/ is compiled by tsc for deploy; tests must not leak into lib/
  globals: { 'ts-jest': { diagnostics: false } },
};
