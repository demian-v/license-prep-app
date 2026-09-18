/**
 * Risk #56 — the StoreKit 2 validation path's own decisions.
 *
 * `apple-receipt-format.test.ts` proves the right receipts reach this code.
 * These tests prove what it then does, because every branch here is a money
 * decision: grant entitlement, or refuse a customer Apple has already charged.
 *
 * Apple's verifier is mocked. A real JWS cannot be produced without Apple's
 * signing key, so **signature verification itself is not covered here** — that
 * is what the sandbox matrix in the register is for. What is covered is
 * everything decided after the signature: environment, product matching,
 * revocation, expiry, and how a verification failure is reported.
 */

const mockVerifyAndDecodeTransaction = jest.fn();
const mockVerifierCtor = jest.fn();

jest.mock('@apple/app-store-server-library', () => {
  const Environment = { PRODUCTION: 'Production', SANDBOX: 'Sandbox' };
  // Both directions, because the code does a reverse lookup to name a status.
  const VerificationStatus: Record<string | number, string | number> = {
    OK: 0,
    VERIFICATION_FAILURE: 1,
    RETRYABLE_VERIFICATION_FAILURE: 2,
    INVALID_APP_IDENTIFIER: 3,
    INVALID_ENVIRONMENT: 4,
    INVALID_CHAIN_LENGTH: 5,
    INVALID_CERTIFICATE: 6,
    FAILURE: 7,
    0: 'OK',
    1: 'VERIFICATION_FAILURE',
    2: 'RETRYABLE_VERIFICATION_FAILURE',
    3: 'INVALID_APP_IDENTIFIER',
    4: 'INVALID_ENVIRONMENT',
    5: 'INVALID_CHAIN_LENGTH',
    6: 'INVALID_CERTIFICATE',
    7: 'FAILURE',
  };
  return {
    Environment,
    VerificationStatus,
    SignedDataVerifier: class {
      constructor(...args: unknown[]) {
        mockVerifierCtor(...args);
      }
      verifyAndDecodeTransaction = mockVerifyAndDecodeTransaction;
    },
  };
});

import { validateAppleJwsTransaction, APPLE_BUNDLE_ID } from '../apple-jws-validation';

/** A verification failure as the library throws it. */
const verificationError = (status: number) =>
  Object.assign(new Error(`verification failed with status ${status}`), { status });

const HOUR = 60 * 60 * 1000;

const transaction = (over: Record<string, unknown> = {}) => ({
  transactionId: '2000000987654321',
  originalTransactionId: '2000000111111111',
  productId: 'monthly',
  expiresDate: Date.now() + 24 * HOUR,
  environment: 'Production',
  ...over,
});

describe('risk #56 — a valid StoreKit 2 transaction', () => {
  let logSpy: jest.SpyInstance;
  let errorSpy: jest.SpyInstance;
  let warnSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.FUNCTIONS_EMULATOR;
    logSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
  });
  afterEach(() => {
    logSpy.mockRestore();
    errorSpy.mockRestore();
    warnSpy.mockRestore();
  });

  it('returns the same shape the legacy path returns', async () => {
    mockVerifyAndDecodeTransaction.mockResolvedValue(transaction());

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    // Downstream code writes subscriptions from these exact keys. A missing
    // one here is a silently incomplete subscription document.
    expect(result).toEqual({
      valid: true,
      expiresAt: expect.any(Date),
      transactionId: '2000000987654321',
      originalTransactionId: '2000000111111111',
      actualProductId: 'monthly',
      environment: 'production',
    });
  });

  it('keeps transactionId and originalTransactionId distinct', async () => {
    // Using originalTransactionId as transactionId would make the idempotency
    // guard block every renewal after the first purchase — the legacy path has
    // a comment about exactly this.
    mockVerifyAndDecodeTransaction.mockResolvedValue(transaction());
    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');
    expect(result.transactionId).not.toBe(result.originalTransactionId);
  });

  it('verifies against the bundle id the webhook uses', async () => {
    mockVerifyAndDecodeTransaction.mockResolvedValue(transaction());
    await validateAppleJwsTransaction('a.b.c', 'monthly');
    expect(mockVerifierCtor).toHaveBeenCalledWith(
      expect.any(Array), // root CAs
      true, // online checks
      'Production',
      APPLE_BUNDLE_ID,
      undefined, // APPLE_APP_ID unset in this test env
    );
  });
});

describe('sandbox and production (risk #27)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.FUNCTIONS_EMULATOR;
    jest.spyOn(console, 'log').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});
    jest.spyOn(console, 'warn').mockImplementation(() => {});
  });
  afterEach(() => jest.restoreAllMocks());

  it('tries production first, then sandbox on INVALID_ENVIRONMENT', async () => {
    mockVerifyAndDecodeTransaction
      .mockRejectedValueOnce(verificationError(4))
      .mockResolvedValueOnce(transaction({ environment: 'Sandbox' }));

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(result.valid).toBe(true);
    expect(result.environment).toBe('sandbox');
    expect(mockVerifierCtor).toHaveBeenNthCalledWith(
      1, expect.anything(), true, 'Production', APPLE_BUNDLE_ID, undefined,
    );
    expect(mockVerifierCtor).toHaveBeenNthCalledWith(
      2, expect.anything(), true, 'Sandbox', APPLE_BUNDLE_ID, undefined,
    );
  });

  it('believes the payload over the verifier that succeeded', async () => {
    // A sandbox transaction that verified in production must not be recorded
    // as real revenue. #27 stored an unknown environment as null rather than
    // defaulting to production for the same reason.
    mockVerifyAndDecodeTransaction.mockResolvedValue(
      transaction({ environment: 'Sandbox' }),
    );
    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');
    expect(result.environment).toBe('sandbox');
  });

  it('uses sandbox first under the emulator, and does not retry', async () => {
    process.env.FUNCTIONS_EMULATOR = 'true';
    mockVerifyAndDecodeTransaction.mockRejectedValue(verificationError(4));

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(result.valid).toBe(false);
    expect(mockVerifierCtor).toHaveBeenCalledTimes(1);
    expect(mockVerifierCtor).toHaveBeenCalledWith(
      expect.anything(), true, 'Sandbox', APPLE_BUNDLE_ID, undefined,
    );
  });
});

describe('what it refuses, and how clearly', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.FUNCTIONS_EMULATOR;
    jest.spyOn(console, 'log').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});
    jest.spyOn(console, 'warn').mockImplementation(() => {});
  });
  afterEach(() => jest.restoreAllMocks());

  it('refuses a transaction for a different product', async () => {
    // Strict matching, same as the legacy path: accepting it would record the
    // customer on a plan they did not buy.
    mockVerifyAndDecodeTransaction.mockResolvedValue(
      transaction({ productId: 'yearly' }),
    );

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(result.valid).toBe(false);
    expect(result.error).toContain('monthly');
    expect(result.error).toContain('yearly');
    expect(result.expiresAt).toBeUndefined();
  });

  it('refuses a revoked transaction', async () => {
    const revokedAt = Date.now() - 2 * HOUR;
    mockVerifyAndDecodeTransaction.mockResolvedValue(
      transaction({ revocationDate: revokedAt }),
    );

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(result.valid).toBe(false);
    expect(result.error).toContain('cancelled');
    expect(result.error).toContain(new Date(revokedAt).toISOString());
  });

  it('refuses an expired subscription', async () => {
    const expired = Date.now() - 3 * HOUR;
    mockVerifyAndDecodeTransaction.mockResolvedValue(
      transaction({ expiresDate: expired }),
    );

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(result.valid).toBe(false);
    expect(result.error).toContain('expired');
    expect(result.error).toContain(new Date(expired).toISOString());
  });

  it('refuses a transaction with no expiry rather than inventing one', async () => {
    mockVerifyAndDecodeTransaction.mockResolvedValue(
      transaction({ expiresDate: undefined }),
    );

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(result.valid).toBe(false);
    expect(result.error).toContain('expiry');
  });

  it('names the verification status when the signature does not verify', async () => {
    // "Please try again" would be a lie: a bad signature verifies no better on
    // the second attempt. The status name is what makes a support report
    // actionable.
    mockVerifyAndDecodeTransaction.mockRejectedValue(verificationError(6));

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(result.valid).toBe(false);
    expect(result.error).toContain('INVALID_CERTIFICATE');
    expect(result.error).not.toMatch(/try again/i);
  });

  it('does not fall back to sandbox for a non-environment failure', async () => {
    // Retrying a genuinely bad signature in the other environment would turn
    // one clear refusal into two confusing ones.
    mockVerifyAndDecodeTransaction.mockRejectedValue(verificationError(1));

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(result.valid).toBe(false);
    expect(mockVerifierCtor).toHaveBeenCalledTimes(1);
  });

  it('survives a thrown value with no status', async () => {
    mockVerifyAndDecodeTransaction.mockRejectedValue(new Error('socket hang up'));

    const result = await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(result.valid).toBe(false);
    expect(result.error).toContain('unknown');
  });

  it('never returns valid:true together with an error', async () => {
    // The caller checks `valid` and then reads `error`. A result carrying both
    // is a contradiction that would be acted on as success.
    const cases = [
      transaction({ productId: 'other' }),
      transaction({ revocationDate: Date.now() - HOUR }),
      transaction({ expiresDate: Date.now() - HOUR }),
      transaction({ expiresDate: undefined }),
    ];
    for (const t of cases) {
      mockVerifyAndDecodeTransaction.mockResolvedValue(t);
      const result = await validateAppleJwsTransaction('a.b.c', 'monthly');
      expect(result.valid).toBe(false);
      expect(result.error).toBeTruthy();
    }
  });
});

describe('APPLE_APP_ID, which the register flags as unverified', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.FUNCTIONS_EMULATOR;
    jest.spyOn(console, 'log').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });
  afterEach(() => {
    delete process.env.APPLE_APP_ID;
    jest.restoreAllMocks();
  });

  it('passes a real app id through', async () => {
    process.env.APPLE_APP_ID = '1234567890';
    mockVerifyAndDecodeTransaction.mockResolvedValue(transaction());

    await validateAppleJwsTransaction('a.b.c', 'monthly');

    expect(mockVerifierCtor).toHaveBeenCalledWith(
      expect.anything(), true, 'Production', APPLE_BUNDLE_ID, 1234567890,
    );
  });

  it.each(['0', '', 'not-a-number'])(
    'passes undefined rather than app id %s',
    async (value) => {
      // `defineInt('APPLE_APP_ID', { default: 0 })` means an unset param
      // arrives as 0. The library requires a real id for Production and
      // ignores it for Sandbox; handing it 0 is how verification fails against
      // app id zero (register Top-7 #5). undefined at least fails loudly.
      process.env.APPLE_APP_ID = value;
      mockVerifyAndDecodeTransaction.mockResolvedValue(transaction());

      await validateAppleJwsTransaction('a.b.c', 'monthly');

      expect(mockVerifierCtor).toHaveBeenCalledWith(
        expect.anything(), true, 'Production', APPLE_BUNDLE_ID, undefined,
      );
    },
  );
});
