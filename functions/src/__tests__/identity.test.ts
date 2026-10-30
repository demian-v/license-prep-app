/**
 * Instructors plan v2 §6.1 / §6.3 (P10b) — the identity check against a fake
 * Didit client (no request leaves jest): consent first; the session is
 * created on the server for the caller only, at most 3 per 30 days; the
 * webhook's V2 signature and timestamp, its dedupe inside the transaction,
 * the status mapping, a passed check never undone; the reconcile poll; and
 * which client the emulator may use.
 */
import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { DiditClient, DiditDecision, didit, fakeDidit, setDiditClient, verifyDiditSignature, webhookSecret } from '../didit-client';
import { BIOMETRIC_CONSENT_VERSIONS, eraseDiditDataForDeletedAccount, idCheckFor, runDiditErasures, runReconcileIdentitySessions, splitName } from '../identity';
import { setPushTransport } from '../push';

const db = () => admin.firestore();
const SECRET = 'didit_whsec_test_dummy';
const VERSION = BIOMETRIC_CONSENT_VERSIONS[0];
const PRIV = 'id-private';
const SCHOOL = 'id-school';
const ctx = (uid: string, provider = 'password') => ({ auth: { uid, token: { firebase: { sign_in_provider: provider } } } });
const call = (fn: any) => (data: unknown, uid = PRIV, provider?: string) =>
  testEnv.wrap(fn)(data as any, ctx(uid, provider) as any) as Promise<any>;
const pub = (uid = PRIV) => db().collection('instructors').doc(uid);
const priv = (uid = PRIV) => db().collection('instructorPrivate').doc(uid);

// ── Fake Didit ───────────────────────────────────────────────────────────────
let created: any[] = [];
let decisions: Record<string, DiditDecision> = {};
let nextSession = 0;
let reuse: string | null = null;
const fake: DiditClient = {
  async createSession(input) {
    created.push(input);
    const sessionId = reuse ?? `sess-${++nextSession}`;
    return { sessionId, sessionToken: `tok-${sessionId}`, url: null };
  },
  async getDecision(sessionId) {
    return decisions[sessionId] ?? { session_id: sessionId, status: 'In Progress' };
  },
  async deleteSession() {},
  async deleteUsers() {},
};
const approved = (sessionId: string, over: Record<string, unknown> = {}): DiditDecision => ({
  session_id: sessionId, status: 'Approved', vendor_data: PRIV,
  id_verifications: [{ status: 'Approved', full_name: 'Marek Nowak', date_of_birth: '1988-04-02', expiration_date: '2031-05-01', issuing_state: 'USA', ...over }],
});

let pushes: { token: string; title?: string }[] = [];
beforeAll(() => {
  setDiditClient(fake);
  setPushTransport({
    async send(messages) {
      pushes.push(...messages.map((m) => ({ token: m.token, title: m.notification?.title })));
      return messages.map(() => null);
    },
  });
});
afterAll(() => {
  setDiditClient(null);
  setPushTransport(null);
  testEnv.cleanup();
});

beforeEach(async () => {
  created = [];
  decisions = {};
  reuse = null;
  nextSession = 0;
  pushes = [];
  for (const uid of [PRIV, SCHOOL]) {
    await pub(uid).set({
      kind: uid === SCHOOL ? 'school' : 'schoolInstructor', name: uid === SCHOOL ? 'Lakeview Driving School' : 'Marek Nowak',
      state: 'IL', status: 'active', idCheck: 'none', licenseCheck: 'passed', stage: 0, listed: true,
    });
    await priv(uid).set({ identitySessionIds: [], biometricConsentAt: null });
    await db().collection('users').doc(uid).set({ language: 'pl' });
    await db().collection('users').doc(uid).collection('fcmTokens').doc('t').set({ token: `tok-${uid}`, platform: 'ios' });
  }
});

const consent = (uid = PRIV) => call(fns.recordBiometricConsent)({ version: VERSION, agreed: true }, uid);

describe('recordBiometricConsent (§6.3)', () => {
  it('stores when and which wording, in instructorPrivate', async () => {
    const before = Date.now();
    await consent();
    const p = (await priv().get()).data()!;
    expect(p.biometricConsentVersion).toBe(VERSION);
    expect(p.biometricConsentAt.toMillis()).toBeGreaterThanOrEqual(before - 1000);
  });
  it('refuses an unknown version, a missing agreement, a non-instructor and an anonymous session', async () => {
    await expect(call(fns.recordBiometricConsent)({ version: 'v0', agreed: true })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(call(fns.recordBiometricConsent)({ version: VERSION })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(call(fns.recordBiometricConsent)({ version: VERSION, agreed: true }, 'id-nobody')).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(call(fns.recordBiometricConsent)({ version: VERSION, agreed: true }, PRIV, 'anonymous')).rejects.toMatchObject({ code: 'permission-denied' });
  });
});

describe('createIdentitySession (§6.1 step 2)', () => {
  it('refuses without consent', async () => {
    await expect(call(fns.createIdentitySession)({})).rejects.toMatchObject({ code: 'failed-precondition', message: 'consent-required' });
    expect(created).toHaveLength(0);
  });
  it('creates the session for the caller, with the entered name, state and our consent', async () => {
    await consent();
    await expect(call(fns.createIdentitySession)({ vendorData: 'someone-else' })).resolves.toEqual({ sessionToken: 'tok-sess-1', url: null });
    expect(created[0]).toMatchObject({
      workflowId: 'wf_test_dummy', vendorData: PRIV, userState: 'US-IL',
      expectedDetails: { first_name: 'Marek', last_name: 'Nowak' },
      biometricConsent: { text_version: VERSION },
    });
    expect((await pub().get()).get('idCheck')).toBe('pending');
    expect((await priv().get()).data()).toMatchObject({ identitySessionIds: ['sess-1'], identityCurrentSessionId: 'sess-1' });
  });
  it("sends no expected name for a driving school (its name is the business's)", async () => {
    await consent(SCHOOL);
    await call(fns.createIdentitySession)({}, SCHOOL);
    expect(created[0].expectedDetails).toBeUndefined();
  });
  it('allows 3 new sessions per 30 days; Didit\'s returned unfinished one does not count', async () => {
    await consent();
    for (let i = 0; i < 3; i++) await call(fns.createIdentitySession)({});
    reuse = 'sess-3';
    await expect(call(fns.createIdentitySession)({})).resolves.toMatchObject({ sessionToken: 'tok-sess-3' });
    reuse = null;
    await expect(call(fns.createIdentitySession)({})).rejects.toMatchObject({ code: 'resource-exhausted' });
    // Older than 30 days no longer counts.
    const old = admin.firestore.Timestamp.fromMillis(Date.now() - 31 * 864e5);
    await priv().update({ identitySessionTimes: [old, old, old] });
    await expect(call(fns.createIdentitySession)({})).resolves.toBeDefined();
  });
  it('refuses once passed, and for a suspended profile', async () => {
    await consent();
    await pub().update({ idCheck: 'passed' });
    await expect(call(fns.createIdentitySession)({})).rejects.toMatchObject({ message: 'already-passed' });
    await pub().update({ idCheck: 'none', status: 'suspended' });
    await expect(call(fns.createIdentitySession)({})).rejects.toMatchObject({ message: 'suspended' });
  });
});

// ── Webhook ──────────────────────────────────────────────────────────────────
function sign(body: unknown, secret = SECRET) {
  const sort = (v: any): any => Array.isArray(v) ? v.map(sort)
    : v && typeof v === 'object' ? Object.keys(v).sort().reduce((a: any, k) => { a[k] = sort(v[k]); return a; }, {}) : v;
  return crypto.createHmac('sha256', secret).update(JSON.stringify(sort(body)), 'utf8').digest('hex');
}

async function deliver(body: Record<string, unknown>, opts: { signature?: string; timestamp?: number } = {}) {
  const ts = String(opts.timestamp ?? Math.floor(Date.now() / 1000));
  const signature = opts.signature ?? sign(body);
  const out: { status?: number; body?: unknown } = {};
  const res: any = {
    status(code: number) { out.status = code; return res; },
    json(b: unknown) { out.body = b; return res; },
    send(b: unknown) { out.body = b; return res; },
  };
  const headers: Record<string, string> = { 'x-signature-v2': signature, 'x-timestamp': ts };
  const req: any = { method: 'POST', body, header: (n: string) => headers[n.toLowerCase()] };
  await (fns.diditWebhook as any)(req, res);
  return out;
}

const event = (status: string, over: Record<string, unknown> = {}) => ({
  event_id: crypto.randomUUID(), session_id: 'sess-1', status, webhook_type: 'status.updated',
  vendor_data: PRIV, environment: 'live', timestamp: Math.floor(Date.now() / 1000), created_at: 1, ...over,
});

describe('diditWebhook (§6.1 step 4)', () => {
  beforeEach(async () => {
    await consent();
    await call(fns.createIdentitySession)({});
  });

  it('Approved → passed from the fetched decision, keeps only name/DOB/status/expiry, pushes once', async () => {
    decisions['sess-1'] = approved('sess-1', { document_number: 'D123', portrait_image: 'https://x/face.jpg' } as any);
    const e = event('Approved', { decision: { id_verifications: [{ full_name: 'Body Name' }] } });
    await expect(deliver(e)).resolves.toMatchObject({ status: 200 });
    expect((await pub().get()).get('idCheck')).toBe('passed');
    const identity = (await priv().get()).get('identity');
    expect(identity).toMatchObject({ fullName: 'Marek Nowak', dateOfBirth: '1988-04-02', documentExpiresOn: '2031-05-01', sessionId: 'sess-1' });
    expect(Object.keys(identity).sort()).toEqual(['checkedAt', 'dateOfBirth', 'documentExpiresOn', 'fullName', 'sessionId', 'status']);
    expect((await priv().get()).get('identityPendingSince')).toBeUndefined();
    expect(pushes).toEqual([{ token: `tok-${PRIV}`, title: 'Tożsamość potwierdzona' }]);
    // The same event again: deduped, nothing changes, no second push.
    await expect(deliver(e)).resolves.toMatchObject({ status: 200 });
    expect(pushes).toHaveLength(1);
    expect((await db().collection('processedWebhooks').doc(`didit_${e.event_id}`).get()).exists).toBe(true);
  });

  it('Declined → failed with Didit\'s risk code as the reason', async () => {
    decisions['sess-1'] = { session_id: 'sess-1', status: 'Declined', id_verifications: [{ status: 'Declined', warnings: [{ risk: 'DOCUMENT_EXPIRED' }] }] };
    await deliver(event('Declined'));
    expect((await pub().get()).data()).toMatchObject({ idCheck: 'failed', idCheckReason: 'DOCUMENT_EXPIRED' });
    expect(pushes).toHaveLength(1);
  });

  it('Abandoned / Expired → none (can retry); In Review → pending; a passed check is never undone', async () => {
    await deliver(event('Abandoned'));
    expect((await pub().get()).get('idCheck')).toBe('none');
    await deliver(event('In Review'));
    expect((await pub().get()).get('idCheck')).toBe('pending');
    decisions['sess-1'] = approved('sess-1');
    await deliver(event('Approved'));
    await deliver(event('Expired'));
    expect((await pub().get()).get('idCheck')).toBe('passed');
    decisions['sess-1'] = { session_id: 'sess-1', status: 'Declined' };
    await deliver(event('Declined'));
    expect((await pub().get()).get('idCheck')).toBe('passed');
  });

  it('refuses a bad signature, an old timestamp, another secret', async () => {
    const e = event('Approved');
    await expect(deliver(e, { signature: 'ab'.repeat(32) })).resolves.toMatchObject({ status: 401 });
    await expect(deliver(e, { timestamp: Math.floor(Date.now() / 1000) - 301 })).resolves.toMatchObject({ status: 401 });
    await expect(deliver(e, { signature: sign(e, 'another-secret') })).resolves.toMatchObject({ status: 401 });
    // A signature over different content.
    await expect(deliver({ ...e, vendor_data: SCHOOL }, { signature: sign(e) })).resolves.toMatchObject({ status: 401 });
    expect((await pub().get()).get('idCheck')).toBe('pending');
  });

  it('ignores a sandbox event in production, another type, and a session that is not the instructor\'s', async () => {
    decisions['sess-1'] = approved('sess-1');
    await deliver(event('Approved', { environment: 'sandbox' }));
    await deliver(event('Approved', { webhook_type: 'data.updated' }));
    await deliver(event('Approved', { vendor_data: SCHOOL }));
    await deliver(event('Approved', { session_id: 'sess-other' }));
    expect((await pub().get()).get('idCheck')).toBe('pending');
    expect((await pub(SCHOOL).get()).get('idCheck')).toBe('none');
  });

  it('dead-letters a failed decision fetch without the personal data, and asks Didit to retry', async () => {
    setDiditClient({ ...fake, async getDecision() { throw new Error('HTTP 503'); } });
    try {
      const e = event('Approved', { decision: { id_verifications: [{ full_name: 'Marek Nowak', date_of_birth: '1988-04-02' }] } });
      await expect(deliver(e)).resolves.toMatchObject({ status: 500 });
      const dl = (await db().collection('webhookDeadLetter').doc(`didit_${e.event_id}`).get()).data()!;
      expect(JSON.stringify(dl)).not.toContain('Marek');
      expect(JSON.stringify(dl)).not.toContain('1988');
    } finally {
      setDiditClient(fake);
    }
  });
});

describe('reconcileIdentitySessions (§6.1 step 5)', () => {
  beforeEach(async () => {
    await consent();
    await call(fns.createIdentitySession)({});
  });
  it('waits 10 minutes, then applies the decision the webhook missed', async () => {
    decisions['sess-1'] = approved('sess-1');
    await runReconcileIdentitySessions(Date.now());
    expect((await pub().get()).get('idCheck')).toBe('pending');
    await expect(runReconcileIdentitySessions(Date.now() + 11 * 60 * 1000)).resolves.toBeGreaterThanOrEqual(1);
    expect((await pub().get()).get('idCheck')).toBe('passed');
    expect(pushes).toHaveLength(1);
    // Nothing left to poll.
    await runReconcileIdentitySessions(Date.now() + 30 * 60 * 1000);
    expect(pushes).toHaveLength(1);
  });
  it('leaves a session still in progress pending, without rewriting it', async () => {
    const before = (await pub().get()).updateTime;
    await runReconcileIdentitySessions(Date.now() + 11 * 60 * 1000);
    expect((await pub().get()).get('idCheck')).toBe('pending');
    expect((await pub().get()).updateTime).toEqual(before);
  });
});

describe('Didit erasure on account deletion (§17)', () => {
  it('a Didit failure never blocks the deletion: queued, then retried hourly', async () => {
    let down = true;
    const deleted: string[] = [];
    setDiditClient({
      ...fake,
      async deleteSession(id) { if (down) throw new Error('HTTP 503'); deleted.push(id); },
      async deleteUsers(v) { deleted.push(`user:${v[0]}`); },
    });
    try {
      await expect(eraseDiditDataForDeletedAccount('id-gone', ['s1', 's2'])).resolves.toBeUndefined();
      const q = db().collection('diditErasures').doc('id-gone');
      expect((await q.get()).get('attempts')).toBe(1);
      await expect(runDiditErasures(Date.now())).resolves.toBe(0); // not due yet
      down = false;
      await expect(runDiditErasures(Date.now() + 61 * 60 * 1000)).resolves.toBe(1);
      expect(deleted).toEqual(['s1', 's2', 'user:id-gone']);
      expect((await q.get()).exists).toBe(false);
    } finally {
      setDiditClient(fake);
    }
  });
  it('does nothing for an account that never started a check', async () => {
    await eraseDiditDataForDeletedAccount('id-none', []);
    expect((await db().collection('diditErasures').doc('id-none').get()).exists).toBe(false);
  });
});

describe('helpers', () => {
  it('maps every Didit status', () => {
    expect(idCheckFor('Approved')).toBe('passed');
    expect(idCheckFor('APPROVED')).toBe('passed');
    expect(idCheckFor('Declined')).toBe('failed');
    for (const s of ['In Review', 'In Progress', 'Awaiting User', 'Not Started', 'Resubmitted']) expect(idCheckFor(s)).toBe('pending');
    for (const s of ['Abandoned', 'Expired', 'Kyc Expired']) expect(idCheckFor(s)).toBe('none');
    expect(idCheckFor('Something new')).toBeNull();
  });
  it('splits a name for expected_details', () => {
    expect(splitName('Marek Nowak')).toEqual({ first_name: 'Marek', last_name: 'Nowak' });
    expect(splitName(' Anna  Maria Wiśniewska ')).toEqual({ first_name: 'Anna', last_name: 'Maria Wiśniewska' });
    expect(splitName('Cher')).toEqual({ first_name: 'Cher', last_name: 'Cher' });
  });
  it('verifies V2 over sorted keys with Unicode preserved', () => {
    const body = { b: 1, a: { z: 'Wiśniewska', y: [2, 1] } };
    const now = Date.now();
    const ts = String(Math.floor(now / 1000));
    expect(verifyDiditSignature(body, sign(body), ts, [SECRET], now)).toBe(true);
    expect(verifyDiditSignature({ a: { y: [2, 1], z: 'Wiśniewska' }, b: 1 }, sign(body), ts, [SECRET], now)).toBe(true);
    expect(verifyDiditSignature(body, sign(body), ts, [''], now)).toBe(false);
    expect(verifyDiditSignature(body, undefined, ts, [SECRET], now)).toBe(false);
    expect(verifyDiditSignature(body, sign(body), 'abc', [SECRET], now)).toBe(false);
  });
});

describe('which Didit client (risk register: the emulator reads production secrets)', () => {
  const env = { ...process.env };
  beforeEach(() => setDiditClient(null));
  afterEach(() => {
    process.env = { ...env };
    setDiditClient(fake);
  });
  // Didit's keys carry no sandbox/live prefix, so the emulator never reads the
  // production names — only the sandbox ones from functions/.env.local.
  it('the emulator ignores the production key and uses the fake without sandbox values', () => {
    process.env.FUNCTIONS_EMULATOR = 'true';
    expect(didit()).toBe(fakeDidit);
    process.env.DIDIT_API_KEY = 'x'.repeat(43);
    expect(didit()).toBe(fakeDidit);
    process.env.DIDIT_SANDBOX_API_KEY = 'y'.repeat(43);
    expect(didit()).toBe(fakeDidit); // no sandbox workflow id yet
    process.env.DIDIT_SANDBOX_WORKFLOW_ID = 'wf_sandbox_dummy';
    expect(didit()).not.toBe(fakeDidit);
  });
  it('the emulator checks webhooks with the sandbox secret only', () => {
    process.env.FUNCTIONS_EMULATOR = 'true';
    expect(webhookSecret()).toBe('');
    process.env.DIDIT_SANDBOX_WEBHOOK_SECRET = 'sandbox-secret';
    expect(webhookSecret()).toBe('sandbox-secret');
    delete process.env.FUNCTIONS_EMULATOR;
    expect(webhookSecret()).toBe(SECRET);
  });
  it('production without a key refuses instead of faking', () => {
    delete process.env.FUNCTIONS_EMULATOR;
    delete process.env.DIDIT_API_KEY;
    expect(() => didit()).toThrow('identity-unavailable');
  });
});
