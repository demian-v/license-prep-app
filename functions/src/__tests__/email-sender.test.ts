/**
 * Risk #35 — the transport must never pretend.
 *
 * The original defect was helpers returning a hardcoded `true`, which callers
 * recorded as a sent notification. These tests pin the rule that replaced it:
 * in production with no transport configured, the factory throws rather than
 * falling back to something that looks like success.
 */
import {
  createEmailSender,
  LoggingEmailSender,
  ResendEmailSender,
  isEmulator,
} from '../email/sender';

const withEnv = (value: string | undefined, fn: () => void) => {
  const previous = process.env.FUNCTIONS_EMULATOR;
  if (value === undefined) delete process.env.FUNCTIONS_EMULATOR;
  else process.env.FUNCTIONS_EMULATOR = value;
  try { fn(); } finally {
    if (previous === undefined) delete process.env.FUNCTIONS_EMULATOR;
    else process.env.FUNCTIONS_EMULATOR = previous;
  }
};

describe('Risk #35 — choosing a transport', () => {
  it('uses Resend when a key is configured', () => {
    withEnv('true', () => {
      expect(createEmailSender('re_test_key')).toBeInstanceOf(ResendEmailSender);
    });
  });

  it('prefers Resend over the log transport even under the emulator', () => {
    withEnv('true', () => {
      expect(createEmailSender('re_test_key')).not.toBeInstanceOf(LoggingEmailSender);
    });
  });

  it('falls back to the log transport locally, so the flow is testable', () => {
    withEnv('true', () => {
      expect(createEmailSender(undefined)).toBeInstanceOf(LoggingEmailSender);
    });
  });

  it('THROWS in production when no key is set, rather than pretending', () => {
    // This is the whole point of #35: silence that looks like success is worse
    // than a loud failure.
    withEnv(undefined, () => {
      expect(() => createEmailSender(undefined)).toThrow(/RESEND_API_KEY is not set/);
    });
  });

  it('treats an empty or whitespace key as not set', () => {
    withEnv(undefined, () => {
      expect(() => createEmailSender('')).toThrow(/RESEND_API_KEY/);
      expect(() => createEmailSender('   ')).toThrow(/RESEND_API_KEY/);
    });
  });
});

describe('Risk #35 — the log transport is honest about what it is', () => {
  it('reports transport: log, not resend', async () => {
    const result = await new LoggingEmailSender().send({
      to: 'a@example.com', subject: 's', html: '<p>h</p>', text: 't',
    });
    expect(result.transport).toBe('log');
    expect(result.delivered).toBe(true);
  });
});

describe('Risk #35 — emulator detection', () => {
  it('is true only when FUNCTIONS_EMULATOR is exactly "true"', () => {
    withEnv('true', () => expect(isEmulator()).toBe(true));
    withEnv('false', () => expect(isEmulator()).toBe(false));
    withEnv(undefined, () => expect(isEmulator()).toBe(false));
  });
});
