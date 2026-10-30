import * as functions from 'firebase-functions/v1';
import * as crypto from 'crypto';
import { defineSecret } from 'firebase-functions/params';

/**
 * Didit, the identity check (instructors plan v2 §6.1, P10b). Endpoints and
 * the webhook signature from docs.didit.me (read 2026-10-28):
 * POST /v3/session/, GET /v3/session/{id}/decision/,
 * DELETE /v3/session/{id}/delete/, POST /v3/users/delete/; `x-api-key`.
 *
 * Keys never live in the repo (it is public). All three are secrets —
 * Secret Manager in production, the git-ignored functions/.secret.local on
 * the emulator — and `defineSecret`, never `defineString` (that hangs the
 * emulator at a prompt; risk register 2026-10-17).
 *
 * The emulator reads a secret missing from .secret.local from PRODUCTION
 * Secret Manager (risk register 2026-10-17), so the emulator never uses
 * these three. It reads only DIDIT_SANDBOX_API_KEY, DIDIT_SANDBOX_WORKFLOW_ID
 * and DIDIT_SANDBOX_WEBHOOK_SECRET from the git-ignored functions/.env.local
 * (a deploy never reads .env.local, and production has no such names); without
 * them it gets the fake below. Didit's keys carry no sandbox/live prefix
 * (checked 2026-10-29), so the key itself can't tell them apart.
 */
export const diditApiKey = defineSecret('DIDIT_API_KEY');
export const diditWebhookSecret = defineSecret('DIDIT_WEBHOOK_SECRET');
export const diditWorkflowId = defineSecret('DIDIT_WORKFLOW_ID');

/** Every function that talks to Didit declares all three. */
export const DIDIT_SECRETS = [diditApiKey, diditWebhookSecret, diditWorkflowId];

const BASE = 'https://verification.didit.me';

export interface DiditSessionInput {
  workflowId: string;
  /** Our uid: Didit groups sessions by it, and the webhook carries it back. */
  vendorData: string;
  expectedDetails?: { first_name: string; last_name: string };
  /** ISO 3166-2, e.g. US-IL. */
  userState?: string;
  /** The consent our own screen collected (§6.3), so Didit doesn't ask again. */
  biometricConsent: { given_at: string; text_version: string };
}

/** The part of a V3 decision we read. Status casing varies, so compare lowercased. */
export interface DiditDecision {
  session_id?: string;
  status?: string;
  vendor_data?: string;
  id_verifications?: Array<{
    status?: string;
    first_name?: string | null;
    last_name?: string | null;
    full_name?: string | null;
    date_of_birth?: string | null;
    expiration_date?: string | null;
    issuing_state?: string | null;
    warnings?: Array<{ risk?: string }>;
  }>;
}

export interface DiditClient {
  createSession(input: DiditSessionInput): Promise<{ sessionId: string; sessionToken: string; url: string | null }>;
  getDecision(sessionId: string): Promise<DiditDecision>;
  /** Resolves when the session is gone, including a 404 (already deleted). */
  deleteSession(sessionId: string): Promise<void>;
  deleteUsers(vendorData: string[]): Promise<void>;
}

function secret(s: ReturnType<typeof defineSecret>): string {
  try {
    return s.value() ?? '';
  } catch {
    return '';
  }
}

const onEmulator = () => process.env.FUNCTIONS_EMULATOR === 'true';

export function workflowId(): string {
  return onEmulator() ? process.env.DIDIT_SANDBOX_WORKFLOW_ID ?? '' : secret(diditWorkflowId);
}

let override: DiditClient | null = null;

/** Tests only: a fake client (no network in jest). null restores the choice below. */
export function setDiditClient(fake: DiditClient | null) {
  override = fake;
}

/**
 * The client to use. Production: the real one, or none without a key.
 * Emulator: the real one only with the sandbox values from .env.local, else
 * the fake.
 */
export function didit(): DiditClient {
  if (override) return override;
  if (onEmulator()) {
    const sandboxKey = process.env.DIDIT_SANDBOX_API_KEY ?? '';
    return sandboxKey && workflowId() ? realClient(sandboxKey) : fakeDidit;
  }
  const key = secret(diditApiKey);
  if (!key || !workflowId()) throw new functions.https.HttpsError('failed-precondition', 'identity-unavailable');
  return realClient(key);
}

async function call(key: string, method: string, path: string, body?: unknown): Promise<Response> {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { 'x-api-key': key, ...(body !== undefined ? { 'content-type': 'application/json' } : {}) },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return res;
}

async function ok(res: Response, what: string): Promise<unknown> {
  if (!res.ok) {
    // Never log the body: a Didit error can echo personal data.
    throw new Error(`Didit ${what} failed: HTTP ${res.status}`);
  }
  return res.json();
}

function realClient(key: string): DiditClient {
  return {
    async createSession(input) {
      const r = await ok(await call(key, 'POST', '/v3/session/', {
        workflow_id: input.workflowId,
        vendor_data: input.vendorData,
        ...(input.expectedDetails ? { expected_details: input.expectedDetails } : {}),
        ...(input.userState ? { user_state: input.userState } : {}),
        biometric_consent: input.biometricConsent,
      }), 'create session') as { session_id: string; session_token: string; url?: string };
      return { sessionId: r.session_id, sessionToken: r.session_token, url: r.url ?? null };
    },
    async getDecision(sessionId) {
      return await ok(await call(key, 'GET', `/v3/session/${encodeURIComponent(sessionId)}/decision/`), 'decision') as DiditDecision;
    },
    async deleteSession(sessionId) {
      const res = await call(key, 'DELETE', `/v3/session/${encodeURIComponent(sessionId)}/delete/`,
        { deletion_instruction: 'privacy_erasure' });
      if (res.status !== 404) await ok(res, 'delete session');
    },
    async deleteUsers(vendorData) {
      await ok(await call(key, 'POST', '/v3/users/delete/', { vendor_data_list: vendorData }), 'delete users');
    },
  };
}

/**
 * The emulator's Didit: a session that approves when the decision is read,
 * with the instructor's own entered name, so the whole flow (consent →
 * session → webhook or reconcile → stage 1) runs locally with no vendor.
 */
const fakeSessions = new Map<string, string>();
export const fakeDidit: DiditClient = {
  async createSession(input) {
    const sessionId = `fake-${crypto.randomUUID()}`;
    fakeSessions.set(sessionId, input.vendorData);
    return { sessionId, sessionToken: `fake-token-${sessionId}`, url: null };
  },
  async getDecision(sessionId) {
    return {
      session_id: sessionId, status: 'Approved', vendor_data: fakeSessions.get(sessionId),
      id_verifications: [{ status: 'Approved', full_name: 'Emulator Person', date_of_birth: '1990-01-01', expiration_date: '2030-01-01', issuing_state: 'USA' }],
    };
  },
  async deleteSession() {},
  async deleteUsers() {},
};

/**
 * Keys sorted at every level. Didit also writes whole-valued floats as ints;
 * JSON.stringify already does, so its sample's shortenFloats isn't needed.
 */
function sortKeys(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(sortKeys);
  if (v !== null && typeof v === 'object') {
    return Object.keys(v as object).sort().reduce((acc, k) => {
      acc[k] = sortKeys((v as Record<string, unknown>)[k]);
      return acc;
    }, {} as Record<string, unknown>);
  }
  return v;
}

/**
 * `X-Signature-V2`: HMAC-SHA256 over the sorted, compact, Unicode-preserved
 * JSON of the body, with `X-Timestamp` within 300 s; constant-time compare.
 * Offline: no API call.
 */
export function verifyDiditSignature(
  body: unknown, signature: string | undefined, timestamp: string | undefined,
  secrets: string[], nowMs = Date.now(),
): boolean {
  if (!signature || !timestamp || !/^\d+$/.test(timestamp)) return false;
  if (Math.abs(Math.floor(nowMs / 1000) - parseInt(timestamp, 10)) > 300) return false;
  const canonical = JSON.stringify(sortKeys(body));
  const given = Buffer.from(signature, 'utf8');
  return secrets.filter(Boolean).some((s) => {
    const expected = Buffer.from(crypto.createHmac('sha256', s).update(canonical, 'utf8').digest('hex'), 'utf8');
    return expected.length === given.length && crypto.timingSafeEqual(expected, given);
  });
}

export function webhookSecret(): string {
  return onEmulator() ? process.env.DIDIT_SANDBOX_WEBHOOK_SECRET ?? '' : secret(diditWebhookSecret);
}
