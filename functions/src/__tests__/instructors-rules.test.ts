/**
 * Instructors plan v2 §7 — Firestore rules for the marketplace collections.
 *
 * Students never read instructor data directly (it is served by callables
 * gated on requirePaidSubscriber), so every non-owner read below must fail —
 * including a paying user's. Own demo project, like firestore-rules.test.ts.
 */
import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-instructors-rules',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const as = (uid: string, provider = 'password') =>
  env.authenticatedContext(uid, { firebase: { sign_in_provider: provider } } as any).firestore();
const seed = (fn: (db: any) => Promise<unknown>) =>
  env.withSecurityRulesDisabled(async (ctx) => { await fn(ctx.firestore()); });

const instructorDoc = (over: Record<string, unknown> = {}) => ({
  kind: 'school', name: 'Lakeview Driving School', state: 'IL', city: 'Chicago',
  cityKey: 'chicago', languages: ['en', 'pl'], schoolName: 'Lakeview Driving School',
  bio: 'Patient lessons.', hourlyRateCents: 6000, lessonDurations: [60, 90],
  availability: {}, status: 'active', listed: true, stage: 0,
  ratingSum: 0, ratingCount: 0, ratingAvg: 0, ...over,
});

describe('users — the role is server-owned', () => {
  it('a client cannot create its user doc with userType', async () => {
    await assertFails(as('u1').collection('users').doc('u1').set({ name: 'A', userType: 'instructor' }));
  });

  it('a client cannot add userType to its existing user doc', async () => {
    await seed((db) => db.collection('users').doc('u1').set({ name: 'A' }));
    await assertFails(as('u1').collection('users').doc('u1').update({ userType: 'instructor' }));
  });

  it('a client CAN record its signup intent (signupRole / signupKind)', async () => {
    await assertSucceeds(as('u1').collection('users').doc('u1').set({
      name: 'A', signupRole: 'instructor', signupKind: 'school',
    }));
  });
});

describe('users/{uid}/fcmTokens', () => {
  const token = { token: 'abc', platform: 'ios', updatedAt: new Date() };

  it('the owner can register a token', async () => {
    await assertSucceeds(as('u1').collection('users').doc('u1').collection('fcmTokens').doc('t1').set(token));
  });

  it('another user cannot write or read it', async () => {
    await assertFails(as('u2').collection('users').doc('u1').collection('fcmTokens').doc('t1').set(token));
    await seed((db) => db.collection('users').doc('u1').collection('fcmTokens').doc('t1').set(token));
    await assertFails(as('u2').collection('users').doc('u1').collection('fcmTokens').doc('t1').get());
  });

  it('rejects an unknown platform or extra keys', async () => {
    const ref = as('u1').collection('users').doc('u1').collection('fcmTokens').doc('t1');
    await assertFails(ref.set({ ...token, platform: 'web' }));
    await assertFails(ref.set({ ...token, extra: 1 }));
  });
});

describe('instructors/{uid}', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await db.collection('instructors').doc('i1').set(instructorDoc());
      // A paying student: even they must not read the doc directly.
      await db.collection('users').doc('paid1').set({ isActive: true });
    });
  });

  it('the owner can read their own doc', async () => {
    await assertSucceeds(as('i1').collection('instructors').doc('i1').get());
  });

  it('a paying student cannot read it directly (served by callable)', async () => {
    await assertFails(as('paid1').collection('instructors').doc('i1').get());
  });

  it('an anonymous session cannot read even its "own" doc', async () => {
    await assertFails(as('i1', 'anonymous').collection('instructors').doc('i1').get());
  });

  it('a client cannot list the collection', async () => {
    await assertFails(as('paid1').collection('instructors').where('listed', '==', true).get());
  });

  it('the owner can edit allowlisted fields', async () => {
    await assertSucceeds(as('i1').collection('instructors').doc('i1').update({
      bio: 'New bio', hourlyRateCents: 7000, availability: { mon: [{ start: '09:00', end: '12:00' }] },
    }));
  });

  it('the owner can deactivate and reactivate', async () => {
    const ref = as('i1').collection('instructors').doc('i1');
    await assertSucceeds(ref.update({ status: 'deactivated' }));
    await assertSucceeds(ref.update({ status: 'active' }));
  });

  it.each(['listed', 'stage', 'idCheck', 'licenseCheck', 'photoUrl', 'photoApproved',
    'ratingSum', 'ratingAvg', 'payoutsEnabled', 'timezone', 'kind', 'state', 'schoolLicenseNumber'])(
    'the owner cannot write server-owned field %s', async (field) => {
      await assertFails(as('i1').collection('instructors').doc('i1').update({ [field]: 'x' }));
    });

  it('the owner cannot suspend themselves', async () => {
    await assertFails(as('i1').collection('instructors').doc('i1').update({ status: 'suspended' }));
  });

  it('a suspended owner cannot reactivate', async () => {
    await seed((db) => db.collection('instructors').doc('i1').update({ status: 'suspended' }));
    await assertFails(as('i1').collection('instructors').doc('i1').update({ status: 'active' }));
  });

  it('rejects an hourly rate outside $20–$200 or a non-integer rate', async () => {
    const ref = as('i1').collection('instructors').doc('i1');
    await assertFails(ref.update({ hourlyRateCents: 1999 }));
    await assertFails(ref.update({ hourlyRateCents: 20001 }));
    await assertFails(ref.update({ hourlyRateCents: 6000.5 }));
  });

  it('rejects a bio over 600 characters', async () => {
    await assertFails(as('i1').collection('instructors').doc('i1').update({ bio: 'x'.repeat(601) }));
  });

  it('another user cannot edit it', async () => {
    await assertFails(as('i2').collection('instructors').doc('i1').update({ bio: 'hijack' }));
  });

  it('nobody can create or delete from the client', async () => {
    await assertFails(as('i9').collection('instructors').doc('i9').set(instructorDoc()));
    await assertFails(as('i1').collection('instructors').doc('i1').delete());
  });
});

describe('instructors/{uid}/reviews', () => {
  beforeEach(async () => {
    await seed((db) => db.collection('instructors').doc('i1').collection('reviews').doc('s1')
      .set({ rating: 5, comment: 'Great', studentDisplayName: 'Anna K.' }));
  });

  it('the instructor can read their reviews', async () => {
    await assertSucceeds(as('i1').collection('instructors').doc('i1').collection('reviews').doc('s1').get());
  });

  it('nobody else reads them directly, and nobody writes them', async () => {
    await assertFails(as('s2').collection('instructors').doc('i1').collection('reviews').doc('s1').get());
    await assertFails(as('s1').collection('instructors').doc('i1').collection('reviews').doc('s1')
      .set({ rating: 1 }));
  });
});

describe('server-only collections', () => {
  it('instructorPrivate is closed even to its owner', async () => {
    await seed((db) => db.collection('instructorPrivate').doc('i1').set({ phone: '+1' }));
    await assertFails(as('i1').collection('instructorPrivate').doc('i1').get());
    await assertFails(as('i1').collection('instructorPrivate').doc('i1').set({ phone: '+2' }));
  });

  it('bookingSlots is closed', async () => {
    await seed((db) => db.collection('bookingSlots').doc('i1_20261001T0900').set({ bookingId: 'b1' }));
    await assertFails(as('s1').collection('bookingSlots').doc('i1_20261001T0900').get());
    await assertFails(as('s1').collection('bookingSlots').doc('i1_20261001T0930').set({ bookingId: 'b2' }));
  });
});

describe('instructorStats and config', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await db.collection('instructorStats').doc('IL').set({ listedCount: 12 });
      await db.collection('config').doc('instructors').set({ launchStates: ['IL', 'TX'] });
      await db.collection('config').doc('secret').set({ x: 1 });
    });
  });

  it('a signed-in user reads the per-state count and launch config', async () => {
    await assertSucceeds(as('s1').collection('instructorStats').doc('IL').get());
    await assertSucceeds(as('s1').collection('config').doc('instructors').get());
  });

  it('an anonymous session reads neither', async () => {
    await assertFails(as('a1', 'anonymous').collection('instructorStats').doc('IL').get());
    await assertFails(as('a1', 'anonymous').collection('config').doc('instructors').get());
  });

  it('other config docs stay closed and nothing is client-writable', async () => {
    await assertFails(as('s1').collection('config').doc('secret').get());
    await assertFails(as('s1').collection('config').doc('instructors').set({ launchStates: ['CA'] }));
    await assertFails(as('s1').collection('instructorStats').doc('IL').set({ listedCount: 999 }));
  });
});

describe('favorites/{uid}', () => {
  it('the owner can save a list', async () => {
    await assertSucceeds(as('s1').collection('favorites').doc('s1')
      .set({ instructorUids: ['i1'], updatedAt: new Date() }));
  });

  it('rejects extra keys and lists over 200', async () => {
    const ref = as('s1').collection('favorites').doc('s1');
    await assertFails(ref.set({ instructorUids: ['i1'], note: 'x' }));
    await assertFails(ref.set({ instructorUids: Array.from({ length: 201 }, (_, i) => `i${i}`) }));
  });

  it('another user cannot read or write it', async () => {
    await seed((db) => db.collection('favorites').doc('s1').set({ instructorUids: ['i1'] }));
    await assertFails(as('s2').collection('favorites').doc('s1').get());
    await assertFails(as('s2').collection('favorites').doc('s1').set({ instructorUids: [] }));
  });
});

describe('conversations and messages', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await db.collection('conversations').doc('s1_i1').set({
        studentUid: 's1', instructorUid: 'i1', participantUids: ['s1', 'i1'], contactUnlocked: false,
      });
      await db.collection('conversations').doc('s1_i1').collection('messages').doc('m1')
        .set({ senderUid: 's1', text: 'Hi', masked: false });
    });
  });

  it('both participants can read the thread and its messages', async () => {
    for (const uid of ['s1', 'i1']) {
      await assertSucceeds(as(uid).collection('conversations').doc('s1_i1').get());
      await assertSucceeds(as(uid).collection('conversations').doc('s1_i1').collection('messages').doc('m1').get());
    }
  });

  it('a participant can list their own threads', async () => {
    await assertSucceeds(as('s1').collection('conversations').where('participantUids', 'array-contains', 's1').get());
  });

  it('an outsider cannot read the thread or its messages', async () => {
    await assertFails(as('x1').collection('conversations').doc('s1_i1').get());
    await assertFails(as('x1').collection('conversations').doc('s1_i1').collection('messages').doc('m1').get());
  });

  it('nobody writes from the client (masking lives in sendMessage)', async () => {
    await assertFails(as('s1').collection('conversations').doc('s1_i1').update({ contactUnlocked: true }));
    await assertFails(as('s1').collection('conversations').doc('s1_i1').collection('messages').doc('m2')
      .set({ senderUid: 's1', text: 'call me 312 555 0100' }));
  });
});

describe('bookings/{bookingId}', () => {
  beforeEach(async () => {
    await seed((db) => db.collection('bookings').doc('b1').set({
      studentUid: 's1', instructorUid: 'i1', status: 'confirmed', totalCents: 7500,
    }));
  });

  it('the student and the instructor can read it', async () => {
    await assertSucceeds(as('s1').collection('bookings').doc('b1').get());
    await assertSucceeds(as('i1').collection('bookings').doc('b1').get());
  });

  it('an outsider cannot, and nobody writes from the client', async () => {
    await assertFails(as('x1').collection('bookings').doc('b1').get());
    await assertFails(as('s1').collection('bookings').doc('b1').update({ status: 'refunded' }));
    await assertFails(as('s1').collection('bookings').doc('b2').set({ studentUid: 's1', instructorUid: 'i1' }));
  });
});
