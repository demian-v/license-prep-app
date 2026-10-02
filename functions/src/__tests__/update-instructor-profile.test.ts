/**
 * Instructors P3b — editing the profile from Профиль (plan v2 §14.2):
 * description, school name (private instructors only), price + lesson
 * lengths, car and the private contacts. Every edit goes through
 * updateInstructorProfile; kind, role and licence data cannot change here.
 */
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest();
import * as fns from '../index';

const db = () => admin.firestore();
const ctx = (uid: string) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } } });
const register = (data: unknown, uid: string) =>
  testEnv.wrap(fns.registerAsInstructor as any)(data as any, ctx(uid) as any);
const update = (data: unknown, uid: string) =>
  testEnv.wrap(fns.updateInstructorProfile as any)(data as any, ctx(uid) as any);
const contacts = (uid: string) => testEnv.wrap(fns.getInstructorContacts as any)({} as any, ctx(uid) as any);

const school = {
  kind: 'school', name: 'Lakeview Driving School', languages: ['en'],
  state: 'IL', city: 'Chicago', zipCode: '60614',
  schoolAddress: '100 Main St, Chicago, IL', fleetSize: 3, instructorCount: 2,
  carModel: 'Toyota Corolla', carYear: 2022, hasDualControls: true,
  hourlyRateCents: 6500, lessonDurations: [60], phone: '+1 312 555 0100', contactEmail: 'school@example.com',
};
const privateInstructor = {
  ...school, kind: 'schoolInstructor', name: 'Anna Kowalska',
  schoolAddress: undefined, fleetSize: undefined, instructorCount: undefined,
};
const pub = async (uid: string) => (await db().collection('instructors').doc(uid).get()).data()!;
const priv = async (uid: string) => (await db().collection('instructorPrivate').doc(uid).get()).data()!;

async function wipe(...uids: string[]) {
  for (const uid of uids) {
    await db().collection('instructors').doc(uid).delete().catch(() => {});
    await db().collection('instructorPrivate').doc(uid).delete().catch(() => {});
    await db().collection('users').doc(uid).delete().catch(() => {});
  }
}
afterAll(() => testEnv.cleanup());

describe('updateInstructorProfile', () => {
  beforeEach(async () => {
    await wipe('edit-s', 'edit-p', 'edit-x');
    await register(school, 'edit-s');
    await register(privateInstructor, 'edit-p');
  });

  it('saves the description, trimmed, and lets it be cleared', async () => {
    await expect(update({ section: 'bio', bio: '  Calm, patient lessons.  ' }, 'edit-s')).resolves.toEqual({ section: 'bio' });
    expect((await pub('edit-s')).bio).toBe('Calm, patient lessons.');
    await update({ section: 'bio', bio: '' }, 'edit-s');
    expect((await pub('edit-s')).bio).toBe('');
  });

  it('refuses a description over 600 characters', async () => {
    await expect(update({ section: 'bio', bio: 'x'.repeat(601) }, 'edit-s'))
      .rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(update({ section: 'bio', bio: 'x'.repeat(600) }, 'edit-s')).resolves.toBeTruthy();
  });

  it('lets a private instructor name their school, and clear it', async () => {
    await update({ section: 'school', schoolName: 'Northside Driving School' }, 'edit-p');
    expect((await pub('edit-p')).schoolName).toBe('Northside Driving School');
    await update({ section: 'school', schoolName: '' }, 'edit-p');
    expect((await pub('edit-p')).schoolName).toBeNull();
    await expect(update({ section: 'school', schoolName: 'x' }, 'edit-p')).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it("refuses a school's school-name edit: it is the profile name", async () => {
    await expect(update({ section: 'school', schoolName: 'Other' }, 'edit-s')).rejects.toMatchObject({ code: 'invalid-argument' });
    expect((await pub('edit-s')).schoolName).toBe('Lakeview Driving School');
  });

  it('saves the price and lesson lengths, de-duplicated and sorted', async () => {
    await update({ section: 'price', hourlyRateCents: 8000, lessonDurations: [120, 60, 60] }, 'edit-s');
    expect(await pub('edit-s')).toMatchObject({ hourlyRateCents: 8000, lessonDurations: [60, 120] });
  });

  it.each([
    [{ hourlyRateCents: 1999, lessonDurations: [60] }],
    [{ hourlyRateCents: 20001, lessonDurations: [60] }],
    [{ hourlyRateCents: 6000.5, lessonDurations: [60] }],
    [{ hourlyRateCents: 6000, lessonDurations: [] }],
    [{ hourlyRateCents: 6000, lessonDurations: [45] }],
  ])('refuses a bad price %j', async (price) => {
    await expect(update({ section: 'price', ...price }, 'edit-s')).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('saves the car and checks it', async () => {
    await update({ section: 'car', carModel: 'Honda Civic', carYear: 2021, hasDualControls: false }, 'edit-p');
    expect(await pub('edit-p')).toMatchObject({ carModel: 'Honda Civic', carYear: 2021, hasDualControls: false });
    await expect(update({ section: 'car', carModel: 'Honda Civic', carYear: 1990, hasDualControls: true }, 'edit-p'))
      .rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(update({ section: 'car', carModel: 'Honda Civic', carYear: 2021 }, 'edit-p'))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('writes the contacts to the private doc only, and reads them back', async () => {
    await update({ section: 'contacts', phone: ' +1 773 555 0199 ', contactEmail: ' anna@example.com ' }, 'edit-p');
    expect(await priv('edit-p')).toMatchObject({ phone: '+1 773 555 0199', contactEmail: 'anna@example.com' });
    const p = await pub('edit-p');
    expect(p.phone).toBeUndefined();
    expect(p.contactEmail).toBeUndefined();
    await expect(contacts('edit-p')).resolves.toEqual({ phone: '+1 773 555 0199', contactEmail: 'anna@example.com' });
    // The rest of the private doc (licence, Stripe, moderation) is kept.
    expect((await priv('edit-p')).moderation).toEqual({ photo: { status: 'none' } });
  });

  it('refuses a bad phone or email', async () => {
    await expect(update({ section: 'contacts', phone: '555', contactEmail: 'a@b.co' }, 'edit-p'))
      .rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(update({ section: 'contacts', phone: '+1 773 555 0199', contactEmail: 'nope' }, 'edit-p'))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('never changes kind, role, licence or listing fields, whatever is sent', async () => {
    const before = await pub('edit-p');
    await update({
      section: 'bio', bio: 'Hi', kind: 'school', licenseCheck: 'passed', stage: 2, listed: false,
      status: 'suspended', state: 'TX', userType: 'student',
    }, 'edit-p');
    const after = await pub('edit-p');
    for (const f of ['kind', 'licenseCheck', 'state', 'status']) expect(after[f]).toEqual(before[f]);
    expect((await db().collection('users').doc('edit-p').get()).get('userType')).toBe('instructor');
  });

  it('keeps a private instructor price hidden from students until the licence is checked', async () => {
    await update({ section: 'price', hourlyRateCents: 9000, lessonDurations: [60] }, 'edit-p');
    const { publicInstructor } = await import('../instructors');
    const out = publicInstructor('edit-p', await pub('edit-p'));
    expect(out.priceHidden).toBe(true);
    expect(out.hourlyRateCents).toBeUndefined();
  });

  it('saves weekly hours, merged and sorted, and drops empty days', async () => {
    await update({ section: 'availability', availability: {
      tue: [{ start: '14:00', end: '18:00' }, { start: '09:00', end: '12:00' }],
      mon: [{ start: '09:00', end: '10:30' }, { start: '10:00', end: '12:00' }, { start: '12:00', end: '13:00' }],
      sun: [],
    } }, 'edit-s');
    expect((await pub('edit-s')).availability).toEqual({
      mon: [{ start: '09:00', end: '13:00' }],
      tue: [{ start: '09:00', end: '12:00' }, { start: '14:00', end: '18:00' }],
    });
    await update({ section: 'availability', availability: {} }, 'edit-s');
    expect((await pub('edit-s')).availability).toEqual({});
  });

  it.each([
    ['an unknown day', { holiday: [{ start: '09:00', end: '10:00' }] }],
    ['off the 30-minute grid', { mon: [{ start: '09:15', end: '10:00' }] }],
    ['before 06:00', { mon: [{ start: '05:30', end: '07:00' }] }],
    ['after 22:00', { mon: [{ start: '21:00', end: '22:30' }] }],
    ['an empty interval', { mon: [{ start: '10:00', end: '10:00' }] }],
    ['a backwards interval', { mon: [{ start: '12:00', end: '10:00' }] }],
    ['a bad time', { mon: [{ start: '9:00', end: '10:00' }] }],
    ['extra keys', { mon: [{ start: '09:00', end: '10:00', note: 'x' }] }],
    ['a list', [{ start: '09:00', end: '10:00' }]],
    ['not a map', 'mon 9-5'],
  ])('refuses hours with %s', async (_name, availability) => {
    await expect(update({ section: 'availability', availability }, 'edit-s'))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('weekly hours count towards stage 2 (computeListing)', async () => {
    const { computeListing } = await import('../instructors');
    await update({ section: 'availability', availability: { sat: [{ start: '08:00', end: '14:00' }] } }, 'edit-s');
    const p = await pub('edit-s');
    expect(computeListing({ ...p, idCheck: 'passed', licenseCheck: 'passed', payoutsEnabled: true }).stage).toBe(2);
  });

  it('refuses an unknown section, a non-instructor, a suspended profile and no sign-in', async () => {
    await expect(update({ section: 'name', name: 'X' }, 'edit-s')).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(update({ section: 'bio', bio: 'Hi' }, 'edit-x')).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(contacts('edit-x')).rejects.toMatchObject({ code: 'failed-precondition' });
    await db().collection('instructors').doc('edit-s').update({ status: 'suspended' });
    await expect(update({ section: 'bio', bio: 'Hi' }, 'edit-s')).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(testEnv.wrap(fns.updateInstructorProfile as any)({ section: 'bio', bio: 'Hi' } as any, {} as any))
      .rejects.toMatchObject({ code: 'unauthenticated' });
  });
});
