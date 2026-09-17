import axios from 'axios';

/**
 * Risk #35 — a mail transport, behind an interface.
 *
 * The register's #35 is not "we picked the wrong mail library", it is "the code
 * claimed to send mail that it never sent". Three helpers ended in
 * `return true` and callers wrote that into `subscriptionLogs.emailSent`, so the
 * money-state audit trail recorded notifications nobody received.
 *
 * Two rules follow from that, and they are enforced below rather than
 * documented and hoped for:
 *
 *  1. A send either happened or it did not. `delivered` is never optimistic.
 *  2. **There is no silent fallback.** In production without a configured
 *     transport, `createEmailSender` THROWS. It does not quietly log and
 *     pretend, because quietly pretending is the original defect.
 *
 * The interface exists so the vendor is swappable. Resend was chosen (owner,
 * 2026-09-17) and is an HTTP API, which is why `nodemailer` — an SMTP client
 * nothing imported — is removed rather than upgraded.
 */

export interface EmailMessage {
  to: string;
  subject: string;
  html: string;
  text: string;
}

export interface SendResult {
  delivered: boolean;
  transport: 'resend' | 'log';
  id?: string;
  error?: string;
}

export interface EmailSender {
  send(message: EmailMessage): Promise<SendResult>;
}

/** The address mail is sent from. A real mailbox, so replies reach a human. */
export const MAIL_FROM = 'DriveUSA <driveusaservice@driveusallc.com>';

const RESEND_ENDPOINT = 'https://api.resend.com/emails';

/**
 * Local transport. Writes the message — including the code — to the emulator
 * log, so the whole flow is exercisable before a domain is verified.
 *
 * `delivered: true` is honest here: the message reached the only destination
 * this transport has, and `transport: 'log'` says exactly what that was. The
 * factory below is what stops it ever being used in production.
 */
export class LoggingEmailSender implements EmailSender {
  async send(message: EmailMessage): Promise<SendResult> {
    console.log(
      `\n📧 [LOCAL MAIL — NOT SENT ANYWHERE]\n` +
      `   to:      ${message.to}\n` +
      `   subject: ${message.subject}\n` +
      `   ${message.text.replace(/\n/g, '\n   ')}\n`
    );
    return { delivered: true, transport: 'log' };
  }
}

/** Resend, over its HTTP API. No SMTP client needed. */
export class ResendEmailSender implements EmailSender {
  constructor(private readonly apiKey: string) {}

  async send(message: EmailMessage): Promise<SendResult> {
    try {
      const response = await axios.post(
        RESEND_ENDPOINT,
        {
          from: MAIL_FROM,
          to: [message.to],
          subject: message.subject,
          html: message.html,
          text: message.text,
        },
        {
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
          timeout: 10_000,
        }
      );
      return { delivered: true, transport: 'resend', id: response.data?.id };
    } catch (error: unknown) {
      // Report the failure rather than swallowing it. The caller decides what
      // to tell the user; what it must not do is record a send that failed.
      const detail = axios.isAxiosError(error)
        ? `${error.response?.status ?? 'network'}: ${JSON.stringify(error.response?.data ?? error.message)}`
        : error instanceof Error ? error.message : 'unknown error';
      console.error(`❌ Resend rejected the message: ${detail}`);
      return { delivered: false, transport: 'resend', error: detail };
    }
  }
}

/** True when running under the Firebase emulator suite. */
export function isEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === 'true';
}

/**
 * Pick a transport.
 *
 * With a key: Resend. Without one, locally: the log transport, so the flow can
 * be developed and tested. Without one, in production: **throw**. A missing
 * mail transport in production is a misconfiguration, and the one thing it must
 * never do is look like success.
 */
export function createEmailSender(apiKey: string | undefined): EmailSender {
  if (apiKey && apiKey.trim().length > 0) {
    return new ResendEmailSender(apiKey);
  }
  if (isEmulator()) {
    return new LoggingEmailSender();
  }
  throw new Error(
    'RESEND_API_KEY is not set. Refusing to pretend mail was sent — ' +
    'set it with: firebase functions:secrets:set RESEND_API_KEY'
  );
}
