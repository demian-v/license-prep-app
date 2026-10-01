/**
 * Instructors plan v2 §4.3 / §5 / §6.4 — registration, the listing rule and
 * the trigger that keeps `listed`, `stage` and the per-state count honest.
 * Owner decision 2026-09-30: verification can be skipped at signup, so a
 * complete profile is listed at stage 0.
 */
import * as fs from 'fs';
import * as path from 'path';
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';
import { computeListing } from '../instructors';
import { RELEASED_STATES, timezoneForZip } from '../zip-timezone';

const db = () => admin.firestore();
const ctx = (uid: string, provider = 'password') => ({ auth: { uid, token: { firebase: { sign_in_provider: provider } } } });
const register = (data: unknown, uid: string, provider?: string) =>
  testEnv.wrap(fns.registerAsInstructor as any)(data as any, ctx(uid, provider) as any);
const submitLicense = (data: unknown, uid: string) =>
  testEnv.wrap(fns.submitLicenseNumber as any)(data as any, ctx(uid) as any);

const school = {
  kind: 'school', name: 'Lakeview Driving School', languages: ['en', 'pl'],
  state: 'IL', city: 'Chicago', zipCode: '60614',
  schoolAddress: '100 Main St, Chicago, IL', fleetSize: 3, instructorCount: 2,
  carModel: 'Toyota Corolla', carYear: 2022, hasDualControls: true,
  hourlyRateCents: 6500, lessonDurations: [60, 90], bio: 'Patient lessons.',
  phone: '+1 312 555 0100', contactEmail: 'school@example.com',
};

async function wipe(...uids: string[]) {
  for (const uid of uids) {
    await db().collection('instructors').doc(uid).delete().catch(() => {});
    await db().collection('instructorPrivate').doc(uid).delete().catch(() => {});
    await db().collection('users').doc(uid).delete().catch(() => {});
  }
}
afterAll(() => testEnv.cleanup());

describe('registerAsInstructor', () => {
  beforeEach(() => wipe('reg-a', 'reg-b', 'reg-c', 'reg-d', 'reg-e'));

  it('creates the public and private docs and grants the role', async () => {
    await expect(register(school, 'reg-a')).resolves.toEqual({ state: 'IL', listed: true, stage: 0 });
    const pub = (await db().collection('instructors').doc('reg-a').get()).data()!;
    expect(pub).toMatchObject({ kind: 'school', schoolName: 'Lakeview Driving School', timezone: 'America/Chicago',
      listed: true, stage: 0, idCheck: 'none', licenseCheck: 'none', status: 'active', cityKey: 'chicago' });
    expect(pub.phone).toBeUndefined();
    const priv = (await db().collection('instructorPrivate').doc('reg-a').get()).data()!;
    expect(priv).toMatchObject({ phone: '+1 312 555 0100', contactEmail: 'school@example.com' });
    const user = (await db().collection('users').doc('reg-a').get()).data()!;
    expect(user).toMatchObject({ userType: 'instructor', state: 'IL' });
  });

  it('marks a licence number given at signup as pending review', async () => {
    await register({ ...school, schoolLicenseNumber: 'IL-DS-1234' }, 'reg-b');
    expect((await db().collection('instructors').doc('reg-b').get()).get('licenseCheck')).toBe('pending');
  });

  it('refuses a second registration', async () => {
    await register(school, 'reg-a');
    await expect(register(school, 'reg-a')).rejects.toMatchObject({ code: 'already-exists' });
  });

  it('refuses a state that is not released, and an anonymous session', async () => {
    await expect(register({ ...school, state: 'AL' }, 'reg-c')).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(register(school, 'reg-c', 'anonymous')).rejects.toMatchObject({ code: 'permission-denied' });
  });

  // «Private instructor» (owner, 2026-09-30): the school name is optional at
  // signup and can be added later in Профиль; a bad one is still refused.
  it('registers a private instructor without a school name', async () => {
    const { schoolAddress, fleetSize, instructorCount, ...rest } = school;
    void schoolAddress; void fleetSize; void instructorCount;
    const instructor = { ...rest, kind: 'schoolInstructor', name: 'Marek Nowak' };
    await expect(register(instructor, 'reg-d')).resolves.toMatchObject({ listed: true });
    expect((await db().collection('instructors').doc('reg-d').get()).get('schoolName')).toBeNull();
    await expect(register({ ...instructor, schoolName: 'x' }, 'reg-e')).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it.each([
    ['hourlyRateCents', 1500], ['languages', ['xx']], ['zipCode', '6061'], ['phone', '12345'],
    ['lessonDurations', [45]], ['carYear', 1980], ['bio', 'x'.repeat(601)],
  ])('rejects a bad %s', async (field, value) => {
    await expect(register({ ...school, [field]: value }, 'reg-c')).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});

describe('submitLicenseNumber', () => {
  beforeEach(() => wipe('lic-a', 'lic-none', 'lic-p'));

  it('adds the number later and puts it up for review', async () => {
    await register(school, 'lic-a');
    await expect(submitLicense({ schoolLicenseNumber: 'IL-DS-9' }, 'lic-a')).resolves.toEqual({ licenseCheck: 'pending' });
    expect((await db().collection('instructors').doc('lic-a').get()).get('schoolLicenseNumber')).toBe('IL-DS-9');
  });

  it('refuses a caller who is not an instructor', async () => {
    await expect(submitLicense({ schoolLicenseNumber: 'IL-DS-9' }, 'lic-none')).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  // Owner, 2026-09-30: a private instructor may be verified on their own
  // instructor licence. In Illinois that licence is only issued to someone
  // "employed or associated with" a licensed school (92 Ill. Adm. Code
  // 1060.120(a)(8)), so it already implies one.
  const privateInstructor = () => {
    const { schoolAddress, fleetSize, instructorCount, ...rest } = school;
    void schoolAddress; void fleetSize; void instructorCount;
    return { ...rest, kind: 'schoolInstructor', name: 'Carlos Diaz' };
  };

  it('accepts a private instructor\'s own licence alone', async () => {
    await register(privateInstructor(), 'lic-p');
    await expect(submitLicense({ instructorLicenseNumber: 'IL-INS-77' }, 'lic-p')).resolves.toEqual({ licenseCheck: 'pending' });
    expect((await db().collection('instructorPrivate').doc('lic-p').get()).get('licenseNumber')).toBe('IL-INS-77');
    expect((await db().collection('instructors').doc('lic-p').get()).get('schoolLicenseNumber')).toBeNull();
  });

  it('puts a changed own licence back up for review', async () => {
    await register(privateInstructor(), 'lic-p');
    await submitLicense({ instructorLicenseNumber: 'IL-INS-77' }, 'lic-p');
    await db().collection('instructors').doc('lic-p').update({ licenseCheck: 'passed' });
    await expect(submitLicense({ instructorLicenseNumber: 'IL-INS-77' }, 'lic-p')).resolves.toEqual({ licenseCheck: 'passed' });
    await expect(submitLicense({ instructorLicenseNumber: 'IL-INS-78' }, 'lic-p')).resolves.toEqual({ licenseCheck: 'pending' });
  });

  it('still requires some licence number', async () => {
    await register(privateInstructor(), 'lic-p');
    await expect(submitLicense({}, 'lic-p')).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('still requires a school\'s own school licence', async () => {
    await register(school, 'lic-a');
    await expect(submitLicense({ instructorLicenseNumber: 'IL-INS-77' }, 'lic-a')).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});

describe('computeListing', () => {
  const base = { name: 'A', state: 'IL', city: 'Chicago', languages: ['en'], hourlyRateCents: 6000,
    lessonDurations: [60], status: 'active' };

  it('lists a complete active profile at stage 0 with nothing verified', () => {
    expect(computeListing(base)).toEqual({ listed: true, stage: 0 });
  });
  it('does not list a deactivated or suspended profile', () => {
    expect(computeListing({ ...base, status: 'deactivated' }).listed).toBe(false);
    expect(computeListing({ ...base, status: 'suspended' }).listed).toBe(false);
  });
  it('stage 1 once the ID check passed; 2 only with licence, payouts and hours', () => {
    expect(computeListing({ ...base, idCheck: 'passed' }).stage).toBe(1);
    const full = { ...base, idCheck: 'passed', licenseCheck: 'passed', payoutsEnabled: true,
      availability: { mon: [{ start: '09:00', end: '12:00' }] } };
    expect(computeListing(full).stage).toBe(2);
    expect(computeListing({ ...full, availability: {} }).stage).toBe(1);
    const expired = { ...full, licenseExpiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000) };
    expect(computeListing(expired).stage).toBe(1);
  });
});

describe('onInstructorWrite', () => {
  const wrapped = () => testEnv.wrap(fns.onInstructorWrite as any);
  const snap = (data: unknown, id: string) => testEnv.firestore.makeDocumentSnapshot(data as any, `instructors/${id}`);
  // Its own fake state: list-instructors.test.ts reads every listed profile
  // in 'ZI', so leftovers here would show up there.
  const doc = { name: 'A', state: 'ZT', city: 'X', languages: ['en'], hourlyRateCents: 6000, lessonDurations: [60] };

  beforeEach(async () => {
    const old = await db().collection('instructors').where('state', '==', 'ZT').get();
    await Promise.all(old.docs.map((d) => d.ref.delete()));
    await db().collection('instructorStats').doc('ZT').delete().catch(() => {});
  });

  it('corrects `listed` when the owner deactivates, then recounts the state', async () => {
    const before = { ...doc, status: 'active', listed: true, stage: 0 };
    const after = { ...doc, status: 'deactivated', listed: true, stage: 0 };
    await db().collection('instructors').doc('trig-a').set(after);
    await wrapped()(testEnv.makeChange(snap(before, 'trig-a'), snap(after, 'trig-a')));
    expect((await db().collection('instructors').doc('trig-a').get()).get('listed')).toBe(false);

    // The re-fired event (listed true -> false) recounts ZT: nobody listed.
    const corrected = { ...after, listed: false };
    await wrapped()(testEnv.makeChange(snap(after, 'trig-a'), snap(corrected, 'trig-a')));
    expect((await db().collection('instructorStats').doc('ZT').get()).get('listedCount')).toBe(0);
  });

  it('counts a newly listed profile, and a repeated delivery does not double it', async () => {
    const created = { ...doc, status: 'active', listed: true, stage: 0 };
    await db().collection('instructors').doc('trig-b').set(created);
    const event = testEnv.makeChange(testEnv.firestore.makeDocumentSnapshot(null as any, 'instructors/trig-b'), snap(created, 'trig-b'));
    await wrapped()(event);
    await wrapped()(event);
    expect((await db().collection('instructorStats').doc('ZT').get()).get('listedCount')).toBe(1);
  });
});

describe('timezoneForZip', () => {
  it('uses the state zone and the split-state exceptions', () => {
    expect(timezoneForZip('IL', '60614')).toBe('America/Chicago');
    expect(timezoneForZip('TX', '77002')).toBe('America/Chicago');
    expect(timezoneForZip('TX', '79901')).toBe('America/Denver');
    expect(timezoneForZip('FL', '32501')).toBe('America/Chicago');
    expect(timezoneForZip('FL', '33101')).toBe('America/New_York');
    expect(timezoneForZip('AZ', '85001')).toBe('America/Phoenix');
    expect(timezoneForZip('AL', '35203')).toBeNull();
  });
});

describe('server and app agree on the released states', () => {
  it('RELEASED_STATES matches StateData.releasedStateIds', () => {
    const dart = fs.readFileSync(path.join(__dirname, '../../../lib/data/state_data.dart'), 'utf8');
    const block = dart.slice(dart.indexOf('releasedStateIds'), dart.indexOf('};', dart.indexOf('releasedStateIds')));
    const ids = Array.from(block.matchAll(/'([A-Z]{2})'/g)).map((m) => m[1]).sort();
    expect(ids).toEqual([...RELEASED_STATES].sort());
  });
});
