import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { requireAdmin } from './entitlement';
import { ratingTotals } from './reviews';
import { processRefund } from './bookings';
import { stripe, STRIPE_SECRETS } from './stripe-client';
import { sendPushToUser } from './push';
import { sweepPaginated, SWEEP_TIME_BUDGET_MS, SweepResult } from './sweep';

/**
 * The admin dashboard's server side (instructors plan v2 §18a, P10a).
 *
 * The dashboard (the private repo driveusa-admin, a web app on the Firebase JS SDK) is only a
 * client: every read and every action is a callable here, each gated on
 * requireAdmin (admins/{uid}, empty in production until P11). Reads go
 * through callables too, so no rule had to widen for the panel — the
 * collections it shows stay closed to every client.
 *
 * Moderation hides, never deletes (owner, 2026-10-07): a hidden review keeps
 * its text as evidence and drops out of the rating numbers; every moderation
 * action can be undone. Money actions (refund, release, paying a school by
 * hand) cannot, so the dashboard confirms them first.
 */

const db = () => admin.firestore();
const ID = /^[A-Za-z0-9_-]{1,128}$/;
const DAY_MS = 24 * 3600 * 1000;
/** How long a resolved item stays in the board's Resolved column. */
const RESOLVED_WINDOW_MS = 30 * DAY_MS;
/** School cancellations in this window that raise an alert (plan v2 §9.3). */
export const CANCELLATION_ALERT_COUNT = 3;
const CANCELLATION_WINDOW_MS = 30 * DAY_MS;

function id(v: unknown, name: string): string {
  if (typeof v !== 'string' || !ID.test(v)) {
    throw new functions.https.HttpsError('invalid-argument', `Invalid or missing field: ${name}`);
  }
  return v;
}
const ms = (t: unknown): number | null => (t instanceof Timestamp ? t.toMillis() : null);

// ── Reads ────────────────────────────────────────────────────────────────────

export type QueueType = 'review' | 'message' | 'instructor' | 'content' | 'alert' | 'licence' | 'no_show' | 'card_dispute';
export type QueueStage = 'new' | 'in_review' | 'resolved';

export interface QueueItem {
  key: string;
  type: QueueType;
  /** The report id, the instructor's uid (licence) or the booking id. */
  id: string;
  stage: QueueStage;
  urgent: boolean;
  createdAtMs: number | null;
  resolvedAtMs: number | null;
  resolution: string | null;
  [detail: string]: unknown;
}

const reportStage = (status: unknown): QueueStage =>
  status === 'in_review' ? 'in_review' : status === 'dismissed' || status === 'resolved' ? 'resolved' : 'new';

async function instructorSummaries(uids: string[]) {
  const unique = [...new Set(uids)];
  const docs = unique.length ? await db().getAll(...unique.map((u) => db().collection('instructors').doc(u))) : [];
  return new Map(docs.map((d) => [d.id, d.exists ? {
    uid: d.id, name: d.get('name') ?? '', kind: d.get('kind') ?? null, state: d.get('state') ?? null,
    status: d.get('status') ?? null, stage: d.get('stage') ?? 0,
  } : { uid: d.id, name: '', kind: null, state: null, status: 'deleted', stage: 0 }]));
}

/** One report as a queue item, with what the board shows beside it. */
async function reportItem(doc: FirebaseFirestore.QueryDocumentSnapshot): Promise<QueueItem> {
  const r = doc.data();
  const contentType: string = r.contentType ?? '';
  const type: QueueType = contentType === 'review' || contentType === 'message' || contentType === 'instructor'
    ? contentType : contentType === 'school_cancellations' ? 'alert' : 'content';
  const base: QueueItem = {
    key: `${type}:${doc.id}`, type, id: doc.id, stage: reportStage(r.status),
    urgent: type === 'alert' || r.reason === 'harassment',
    createdAtMs: ms(r.createdAt), resolvedAtMs: ms(r.resolvedAt), resolution: r.resolution ?? null,
    reason: r.reason ?? null, message: r.message ?? null, contentType,
    language: r.language ?? null, state: r.state ?? null,
  };
  const entity = r.entity ?? {};
  if (type === 'review') {
    // The stored copy (what was reported) beside the current text (an edit since).
    const found = typeof entity.reviewId === 'string'
      ? await db().collection('instructors').doc(entity.instructorUid).collection('reviews')
        .where('reviewId', '==', entity.reviewId).limit(1).get()
      : null;
    const now = found && !found.empty ? found.docs[0] : null;
    return {
      ...base, instructorUid: entity.instructorUid ?? null, reviewId: entity.reviewId ?? null,
      reported: r.review ?? null,
      current: now ? {
        rating: now.get('rating'), comment: now.get('comment') ?? '', author: now.get('studentDisplayName') ?? '',
        hidden: now.get('hidden') === true, updatedAtMs: ms(now.get('updatedAt')),
      } : null,
    };
  }
  if (type === 'message') {
    const conv = typeof entity.conversationId === 'string' ? db().collection('conversations').doc(entity.conversationId) : null;
    const [c, m] = conv && typeof entity.messageId === 'string'
      ? await Promise.all([conv.get(), conv.collection('messages').doc(entity.messageId).get()]) : [null, null];
    const sender: string | null = m?.exists ? m.get('senderUid') : null;
    const fromInstructor = !!sender && sender === c?.get('instructorUid');
    return {
      ...base, conversationId: entity.conversationId ?? null,
      current: m?.exists ? { text: m.get('text') ?? '', masked: m.get('masked') === true, createdAtMs: ms(m.get('createdAt')) } : null,
      sender: sender ? (fromInstructor ? 'instructor' : 'student') : null,
      senderName: fromInstructor ? c?.get('instructorName') ?? '' : c?.get('studentDisplayName') ?? '',
      instructorUid: c?.get('instructorUid') ?? null,
    };
  }
  if (type === 'instructor' || type === 'alert') {
    return { ...base, instructorUid: entity.instructorUid ?? null, count: r.count ?? null };
  }
  return { ...base, entity };
}

function bookingDetail(b: FirebaseFirestore.DocumentSnapshot) {
  return {
    instructorUid: b.get('instructorUid'), instructorName: b.get('instructorName') ?? '',
    studentName: b.get('studentDisplayName') ?? '', startAtMs: ms(b.get('startAt')),
    localDate: b.get('localDate') ?? null, localTime: b.get('localTime') ?? null, timezone: b.get('timezone') ?? null,
    durationMinutes: b.get('durationMinutes') ?? null, lessonCents: b.get('lessonCents') ?? 0,
    platformFeeCents: b.get('platformFeeCents') ?? 0, totalCents: b.get('totalCents') ?? 0,
    status: b.get('status'), paymentProvider: b.get('paymentProvider') ?? null,
  };
}

/**
 * Everything the board shows: reports (all kinds, the school-cancellation
 * alerts among them), licences waiting for review, no-show reports and lost
 * card disputes — open ones, and what was resolved in the last 30 days.
 * Every query is single-field (no composite index, risk #15).
 */
export const adminGetQueue = functions.https.onCall(async (_data, context) => {
  await requireAdmin(context);
  const since = Timestamp.fromMillis(Date.now() - RESOLVED_WINDOW_MS);
  const [reports, pendingLicences, reviewedLicences, disputed, resolvedNoShows, cardDisputes] = await Promise.all([
    db().collection('reports').orderBy('createdAt', 'desc').limit(300).get(),
    db().collection('instructors').where('licenseCheck', '==', 'pending').get(),
    db().collection('instructors').where('licenseReviewedAt', '>=', since).get(),
    db().collection('bookings').where('status', '==', 'disputed').get(),
    db().collection('bookings').where('noShowResolvedAt', '>=', since).get(),
    db().collection('bookings').where('disputeStatus', 'in', ['open', 'lost', 'prevented']).get(),
  ]);

  const items: QueueItem[] = [];
  for (const doc of reports.docs) {
    const stage = reportStage(doc.get('status'));
    if (stage === 'resolved' && (ms(doc.get('resolvedAt')) ?? 0) < since.toMillis()) continue;
    items.push(await reportItem(doc));
  }

  const licenceDocs = [...pendingLicences.docs, ...reviewedLicences.docs.filter((d) => d.get('licenseCheck') !== 'pending')];
  const privates = licenceDocs.length
    ? await db().getAll(...licenceDocs.map((d) => db().collection('instructorPrivate').doc(d.id))) : [];
  licenceDocs.forEach((d, i) => {
    const pending = d.get('licenseCheck') === 'pending';
    items.push({
      key: `licence:${d.id}`, type: 'licence', id: d.id,
      stage: pending ? (privates[i].get('adminReviewingAt') ? 'in_review' : 'new') : 'resolved',
      urgent: false,
      createdAtMs: ms(d.get('updatedAt')) ?? ms(d.get('createdAt')),
      resolvedAtMs: pending ? null : ms(d.get('licenseReviewedAt')),
      resolution: pending ? null : d.get('licenseCheck'),
      instructorUid: d.id, name: d.get('name') ?? '', kind: d.get('kind'), state: d.get('state'),
      licenseState: d.get('licenseState') ?? d.get('state'),
      schoolName: d.get('schoolName') ?? null, schoolLicenseNumber: d.get('schoolLicenseNumber') ?? null,
      instructorLicenseNumber: privates[i].get('licenseNumber') ?? null,
      licenseExpiresAtMs: ms(d.get('licenseExpiresAt')),
      // P10b: the licence photo, fetched separately (adminGetLicenseImage).
      hasLicenseImage: typeof privates[i].get('licenseImagePath') === 'string',
      licensePhotoAtMs: ms(d.get('licensePhotoAt')),
    });
  });

  const seen = new Set<string>();
  for (const b of [...disputed.docs, ...resolvedNoShows.docs]) {
    if (seen.has(b.id)) continue;
    seen.add(b.id);
    const open = b.get('status') === 'disputed';
    items.push({
      key: `no_show:${b.id}`, type: 'no_show', id: b.id,
      stage: open ? (b.get('adminReviewingAt') ? 'in_review' : 'new') : 'resolved',
      urgent: open, createdAtMs: ms(b.get('noShowReportedAt')),
      resolvedAtMs: ms(b.get('noShowResolvedAt')), resolution: b.get('noShowResolution') ?? null,
      noShowReason: b.get('noShowReason') ?? null, ...bookingDetail(b),
    });
  }

  for (const b of cardDisputes.docs) {
    const status = b.get('disputeStatus');
    // A lost dispute the admin has decided (paid by hand or kept unpaid) stays a while in Resolved.
    const decided = b.get('lostDisputeResolution') != null;
    if (decided && (ms(b.get('lostDisputeResolvedAt')) ?? 0) < since.toMillis()) continue;
    // An open dispute is Stripe's to run; it shows so the held payout is visible.
    const waitingOnAdmin = status !== 'open' && !decided && b.get('payoutCancelledAt') != null;
    items.push({
      key: `card_dispute:${b.id}`, type: 'card_dispute', id: b.id,
      stage: decided ? 'resolved' : waitingOnAdmin && b.get('adminReviewingAt') ? 'in_review' : 'new',
      // A lost dispute waits on the admin from the moment the payout was cancelled.
      urgent: false, createdAtMs: ms(b.get('payoutCancelledAt')) ?? ms(b.get('updatedAt')),
      resolvedAtMs: ms(b.get('lostDisputeResolvedAt')), resolution: b.get('lostDisputeResolution') ?? null,
      disputeStatus: status, disputeReason: b.get('disputeReason') ?? null,
      disputeAmountCents: b.get('disputeAmountCents') ?? null, payoutReleased: b.get('payoutReleasedAt') != null,
      actionable: waitingOnAdmin, ...bookingDetail(b),
    });
  }

  const instructors = await instructorSummaries(items
    .map((i) => i.instructorUid).filter((u): u is string => typeof u === 'string'));
  return {
    items: items.map((i) => (typeof i.instructorUid === 'string' ? { ...i, instructor: instructors.get(i.instructorUid) ?? null } : i)),
    generatedAtMs: Date.now(),
  };
});

/** Every instructor, with what the Instructors page lists. */
export const adminListInstructors = functions.https.onCall(async (_data, context) => {
  await requireAdmin(context);
  const since = Date.now() - CANCELLATION_WINDOW_MS;
  const [instructors, cancelled] = await Promise.all([
    db().collection('instructors').get(),
    db().collection('bookings').where('cancelledAt', '>=', Timestamp.fromMillis(since)).get(),
  ]);
  const cancellations = new Map<string, number>();
  for (const b of cancelled.docs) {
    if (b.get('cancelledBy') !== 'instructor') continue;
    cancellations.set(b.get('instructorUid'), (cancellations.get(b.get('instructorUid')) ?? 0) + 1);
  }
  return {
    instructors: instructors.docs.map((d) => ({
      uid: d.id, name: d.get('name') ?? '', kind: d.get('kind') ?? null, state: d.get('state') ?? null,
      city: d.get('city') ?? null, status: d.get('status') ?? null, listed: d.get('listed') === true,
      stage: d.get('stage') ?? 0, idCheck: d.get('idCheck') ?? 'none', licenseCheck: d.get('licenseCheck') ?? 'none',
      licenseExpiresAtMs: ms(d.get('licenseExpiresAt')), payoutsEnabled: d.get('payoutsEnabled') === true,
      ratingAvg: d.get('ratingAvg') ?? 0, ratingCount: d.get('ratingCount') ?? 0,
      photoStatus: d.get('photoStatus') ?? 'none', createdAtMs: ms(d.get('createdAt')),
      cancellations30d: cancellations.get(d.id) ?? 0,
    })),
  };
});

/**
 * Bookings made in the last 7, 30 or 90 days, one compact row each, for
 * Insights and its CSV. Amounts and statuses only: no student names.
 */
export const adminGetBookings = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);
  const days = [7, 30, 90].includes(data?.days) ? data.days : 30;
  const snap = await db().collection('bookings')
    .where('createdAt', '>=', Timestamp.fromMillis(Date.now() - days * DAY_MS)).get();
  const instructors = await instructorSummaries(snap.docs.map((b) => b.get('instructorUid')));
  return {
    days,
    bookings: snap.docs.map((b) => {
      const startAtMs = ms(b.get('startAt'));
      return {
        id: b.id, createdAtMs: ms(b.get('createdAt')), startAtMs, status: b.get('status'),
        state: instructors.get(b.get('instructorUid'))?.state ?? null, instructorName: b.get('instructorName') ?? '',
        lessonCents: b.get('lessonCents') ?? 0, platformFeeCents: b.get('platformFeeCents') ?? 0,
        totalCents: b.get('totalCents') ?? 0, feeKind: b.get('feeKind') ?? null,
        cancelledBy: b.get('cancelledBy') ?? null, refundedAtMs: ms(b.get('refundedAt')),
        // When the school was due its money: 48 h after the end of the lesson.
        payoutDueAtMs: startAtMs === null ? null : startAtMs + (b.get('durationMinutes') ?? 0) * 60000 + 2 * DAY_MS,
        payoutReleasedAtMs: ms(b.get('payoutReleasedAt')), disputeStatus: b.get('disputeStatus') ?? null,
        noShow: b.get('noShowReportedAt') != null, paymentProvider: b.get('paymentProvider') ?? null,
      };
    }),
  };
});

// ── Moderation (reversible) ──────────────────────────────────────────────────

const REPORT_STATUSES = ['open', 'in_review', 'dismissed', 'resolved'];

function reportUpdate(status: string, by: string, resolution: string | null) {
  const done = status === 'dismissed' || status === 'resolved';
  return {
    status,
    resolution: done ? resolution ?? status : FieldValue.delete(),
    resolvedAt: done ? Timestamp.now() : FieldValue.delete(),
    resolvedBy: done ? by : FieldValue.delete(),
    updatedAt: Timestamp.now(),
  };
}

/**
 * A report's triage state: `in_review`, `dismissed`, `resolved` (a content
 * report whose question was fixed), or back to `open` (Undo).
 */
export const adminSetReportStatus = functions.https.onCall(async (data, context) => {
  const by = await requireAdmin(context);
  const reportId = id(data?.reportId, 'reportId');
  const status = REPORT_STATUSES.includes(data?.status) ? data.status : null;
  if (!status) throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: status');
  const ref = db().collection('reports').doc(reportId);
  await db().runTransaction(async (tx) => {
    if (!(await tx.get(ref)).exists) throw new functions.https.HttpsError('not-found', 'No such report.');
    tx.update(ref, reportUpdate(status, by, status === 'dismissed' ? 'dismissed' : status === 'resolved' ? 'resolved' : null));
  });
  return { reportId, status };
});

/**
 * Hides a review (or shows it again): `hidden` + who/when/which report. A
 * hidden review leaves `ratingSum` / `ratingCount` / `ratingAvg` in the same
 * transaction and comes back into them when unhidden; its text stays. The
 * report it came from is resolved with it, and reopened by the unhide.
 */
export const adminHideReview = functions.https.onCall(async (data, context) => {
  const by = await requireAdmin(context);
  const instructorUid = id(data?.instructorUid, 'instructorUid');
  const reviewId = id(data?.reviewId, 'reviewId');
  const hide = data?.hidden !== false;
  const reportId = data?.reportId == null ? null : id(data.reportId, 'reportId');
  const instructorRef = db().collection('instructors').doc(instructorUid);
  const found = await instructorRef.collection('reviews').where('reviewId', '==', reviewId).limit(1).get();
  if (found.empty) throw new functions.https.HttpsError('not-found', 'This review no longer exists.');
  const ref = found.docs[0].ref;
  await db().runTransaction(async (tx) => {
    const [instructor, review] = await Promise.all([tx.get(instructorRef), tx.get(ref)]);
    if (!review.exists) throw new functions.https.HttpsError('not-found', 'This review no longer exists.');
    const reportRef = reportId ? db().collection('reports').doc(reportId) : null;
    const report = reportRef ? await tx.get(reportRef) : null;
    const wasHidden = review.get('hidden') === true;
    if (wasHidden !== hide && instructor.exists) {
      const rating = review.get('rating');
      tx.update(instructorRef, ratingTotals(instructor.get('ratingSum') ?? 0, instructor.get('ratingCount') ?? 0,
        hide ? rating : null, hide ? null : rating));
    }
    const at = Timestamp.now();
    tx.update(ref, hide
      ? { hidden: true, hiddenAt: at, hiddenBy: by, hiddenReportId: reportId ?? FieldValue.delete() }
      : { hidden: FieldValue.delete(), hiddenAt: FieldValue.delete(), hiddenBy: FieldValue.delete(), hiddenReportId: FieldValue.delete() });
    if (report?.exists) tx.update(reportRef!, hide ? reportUpdate('resolved', by, 'review_hidden') : reportUpdate('open', by, null));
  });
  return { hidden: hide };
});

/**
 * Suspends an instructor or lifts it. A suspended profile is unlisted
 * (computeListing needs `active`), so it can't be found or booked, and can't
 * start payouts or edit itself; lessons already booked stay. Lifting puts
 * back the status it had (an owner may have deactivated it before). A
 * report or alert passed along is resolved, and reopened by the lift.
 */
export const adminSetInstructorStatus = functions.https.onCall(async (data, context) => {
  const by = await requireAdmin(context);
  const uid = id(data?.uid, 'uid');
  const status = data?.status === 'suspended' || data?.status === 'active' ? data.status : null;
  if (!status) throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: status');
  const reportId = data?.reportId == null ? null : id(data.reportId, 'reportId');
  const ref = db().collection('instructors').doc(uid);
  const result = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new functions.https.HttpsError('not-found', 'No such instructor.');
    const reportRef = reportId ? db().collection('reports').doc(reportId) : null;
    const report = reportRef ? await tx.get(reportRef) : null;
    const now = snap.get('status');
    const at = Timestamp.now();
    let next = now;
    if (status === 'suspended' && now !== 'suspended') {
      next = 'suspended';
      tx.update(ref, { status: next, statusBeforeSuspension: now ?? 'active', suspendedAt: at, suspendedBy: by, updatedAt: at });
    } else if (status === 'active' && now === 'suspended') {
      next = snap.get('statusBeforeSuspension') ?? 'active';
      tx.update(ref, {
        status: next, statusBeforeSuspension: FieldValue.delete(), suspendedAt: FieldValue.delete(),
        suspendedBy: FieldValue.delete(), updatedAt: at,
      });
    }
    if (report?.exists) {
      tx.update(reportRef!, status === 'suspended' ? reportUpdate('resolved', by, 'instructor_suspended') : reportUpdate('open', by, null));
    }
    return next;
  });
  return { uid, status: result };
});

/**
 * The licence review (plan v2 §6.4): the admin compared the number with the
 * state's lookup. `approved: true` → `passed` until `expiresAtMs` (in the
 * future); `false` → `rejected`; `null` → back to `pending` (Undo).
 * onInstructorWrite moves the stage.
 */
export const adminReviewLicense = functions.https.onCall(async (data, context) => {
  const by = await requireAdmin(context);
  const uid = id(data?.uid, 'uid');
  const approved = data?.approved;
  if (approved !== true && approved !== false && approved !== null) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: approved');
  }
  const expiresAtMs = data?.expiresAtMs;
  if (approved === true && (!Number.isInteger(expiresAtMs) || expiresAtMs <= Date.now())) {
    throw new functions.https.HttpsError('invalid-argument', 'A future expiry date is required.');
  }
  const ref = db().collection('instructors').doc(uid);
  const privRef = db().collection('instructorPrivate').doc(uid);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new functions.https.HttpsError('not-found', 'No such instructor.');
    if (snap.get('licenseCheck') === 'none') throw new functions.https.HttpsError('failed-precondition', 'no-license-number');
    const at = Timestamp.now();
    tx.update(ref, approved === null
      ? { licenseCheck: 'pending', licenseExpiresAt: null, licenseReviewedAt: FieldValue.delete(), licenseReviewedBy: FieldValue.delete(), updatedAt: at }
      : {
        licenseCheck: approved ? 'passed' : 'rejected',
        licenseExpiresAt: approved ? Timestamp.fromMillis(expiresAtMs) : null,
        licenseReviewedAt: at, licenseReviewedBy: by, updatedAt: at,
      });
    tx.set(privRef, { adminReviewingAt: FieldValue.delete() }, { merge: true });
  });
  return { uid, licenseCheck: approved === null ? 'pending' : approved ? 'passed' : 'rejected' };
});

/**
 * The licence photo for the review (P10b), as a data URL: licence images are
 * closed to every client in storage.rules, so the admin gets the bytes
 * through this callable rather than a Storage link. At most 5 MB (the upload
 * rule), well under a callable's response limit.
 */
export const adminGetLicenseImage = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);
  const uid = id(data?.uid, 'uid');
  const priv = await db().collection('instructorPrivate').doc(uid).get();
  const path = priv.get('licenseImagePath');
  if (typeof path !== 'string') throw new functions.https.HttpsError('not-found', 'no-license-image');
  const bucket = priv.get('licenseImageBucket');
  const [bytes] = await (typeof bucket === 'string' ? admin.storage().bucket(bucket) : admin.storage().bucket()).file(path).download();
  return { dataUrl: `data:image/jpeg;base64,${bytes.toString('base64')}`, uploadedAtMs: ms(priv.get('moderation.license.updatedAt')) };
});

/**
 * «In review» on the board: the admin has picked an item up. Reports carry
 * it as their status; a licence on instructorPrivate, a booking on itself.
 */
export const adminSetInReview = functions.https.onCall(async (data, context) => {
  const by = await requireAdmin(context);
  const type = data?.type;
  const itemId = id(data?.id, 'id');
  const on = data?.on !== false;
  if (type === 'report') {
    const ref = db().collection('reports').doc(itemId);
    await db().runTransaction(async (tx) => {
      const r = await tx.get(ref);
      if (!r.exists) throw new functions.https.HttpsError('not-found', 'No such report.');
      if (reportStage(r.get('status')) === 'resolved') throw new functions.https.HttpsError('failed-precondition', 'resolved');
      tx.update(ref, reportUpdate(on ? 'in_review' : 'open', by, null));
    });
  } else if (type === 'licence' || type === 'booking') {
    const ref = db().collection(type === 'licence' ? 'instructorPrivate' : 'bookings').doc(itemId);
    if (!(await ref.get()).exists) throw new functions.https.HttpsError('not-found', 'Not found.');
    await ref.set({ adminReviewingAt: on ? Timestamp.now() : FieldValue.delete() }, { merge: true });
  } else {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: type');
  }
  return { on };
});

// ── Money (not reversible: the dashboard confirms first) ─────────────────────

/**
 * A transfer already made for this lesson, found by its `transfer_group`
 * (the booking id). The release job could pay in the same instant as a
 * `reportNoShow`, leaving a transfer the booking doesn't record (risk
 * register, P9), so nothing here pays again without asking Stripe first.
 * Null for a lesson the emulator's gateway "paid".
 */
export async function existingTransfer(bookingId: string, b: FirebaseFirestore.DocumentSnapshot): Promise<string | null> {
  if (b.get('stripeTransferId')) return b.get('stripeTransferId');
  if (b.get('paymentProvider') !== 'stripe') return null;
  const list = await stripe().transfers.list({ transfer_group: bookingId, limit: 10 });
  const live = list.data.find((t) => !t.reversed);
  return live?.id ?? null;
}

/**
 * A no-show report (`disputed`, plan v2 §9.3): `refund` returns the whole
 * payment (a transfer already made is reversed first, processRefund) and the
 * student is told; `release` lets the school be paid — at once by the hourly
 * job (back to `completed`, due now), or recorded as paid when Stripe shows
 * the transfer was already made. reportNoShow refuses a resolved lesson.
 */
export const adminResolveNoShow = functions.runWith({ secrets: STRIPE_SECRETS }).https.onCall(async (data, context) => {
  const by = await requireAdmin(context);
  const bookingId = id(data?.bookingId, 'bookingId');
  const outcome = data?.outcome === 'refund' || data?.outcome === 'release' ? data.outcome : null;
  if (!outcome) throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: outcome');
  const ref = db().collection('bookings').doc(bookingId);
  const before = await ref.get();
  if (!before.exists || before.get('status') !== 'disputed') throw new functions.https.HttpsError('failed-precondition', 'not-disputed');
  const transferId = await existingTransfer(bookingId, before);

  const refund = await db().runTransaction(async (tx) => {
    const b = await tx.get(ref);
    if (b.get('status') !== 'disputed') throw new functions.https.HttpsError('failed-precondition', 'not-disputed');
    const at = Timestamp.now();
    const resolved = {
      noShowResolution: outcome, noShowResolvedAt: at, noShowResolvedBy: by,
      adminReviewingAt: FieldValue.delete(), ...(transferId ? { stripeTransferId: transferId } : {}), updatedAt: at,
    };
    const stripePaid = b.get('paymentProvider') === 'stripe' && typeof b.get('stripePaymentIntentId') === 'string';
    if (outcome === 'refund') {
      tx.update(ref, {
        ...resolved, status: 'refunded', cancelledBy: 'admin', payoutReleaseAt: FieldValue.delete(),
        ...(stripePaid ? { refundStatus: 'pending', refundDueAt: at } : { refundedAt: at }),
      });
      return stripePaid;
    }
    tx.update(ref, transferId
      ? { ...resolved, status: 'payout_released', payoutReleasedAt: at, payoutReleaseAt: FieldValue.delete() }
      : { ...resolved, status: 'completed', payoutReleaseAt: at });
    return false;
  });
  if (refund) await processRefund(bookingId);
  const after = await ref.get();
  return { bookingId, status: after.get('status'), refundStatus: after.get('refundStatus') ?? null };
});

/**
 * A card dispute the platform lost cancels the school's payout (owner,
 * 2026-10-17); the admin decides whether to pay the school anyway — the
 * lesson may well have happened — or to keep it unpaid. Paying transfers the
 * lesson price from the platform's balance (the disputed charge's money is
 * gone, so not `source_transaction`), after checking Stripe for a transfer
 * already made.
 */
export const adminResolveLostDispute = functions.runWith({ secrets: STRIPE_SECRETS }).https.onCall(async (data, context) => {
  const by = await requireAdmin(context);
  const bookingId = id(data?.bookingId, 'bookingId');
  const outcome = data?.outcome === 'pay' || data?.outcome === 'keep_unpaid' ? data.outcome : null;
  if (!outcome) throw new functions.https.HttpsError('invalid-argument', 'Invalid or missing field: outcome');
  const ref = db().collection('bookings').doc(bookingId);
  const b = await ref.get();
  if (!b.exists || !['lost', 'prevented'].includes(b.get('disputeStatus')) || b.get('payoutCancelledAt') == null
    || b.get('payoutReleasedAt') != null || b.get('lostDisputeResolution') != null) {
    throw new functions.https.HttpsError('failed-precondition', 'not-a-lost-dispute');
  }
  let transferId: string | null = null;
  if (outcome === 'pay') {
    transferId = await existingTransfer(bookingId, b);
    if (!transferId && b.get('paymentProvider') === 'stripe') {
      const priv = await db().collection('instructorPrivate').doc(b.get('instructorUid')).get();
      const destination: string | undefined = priv.get('stripeAccountId');
      if (!destination) throw new functions.https.HttpsError('failed-precondition', 'no-connected-account');
      const transfer = await stripe().transfers.create({
        amount: b.get('lessonCents'), currency: 'usd', destination, transfer_group: bookingId,
        metadata: { bookingId, reason: 'admin_after_lost_dispute' },
      }, { idempotencyKey: `booking-admin-transfer-${bookingId}` });
      transferId = transfer.id;
    }
  }
  await db().runTransaction(async (tx) => {
    const now = await tx.get(ref);
    if (now.get('lostDisputeResolution') != null) return;
    const at = Timestamp.now();
    tx.update(ref, {
      lostDisputeResolution: outcome, lostDisputeResolvedAt: at, lostDisputeResolvedBy: by,
      adminReviewingAt: FieldValue.delete(), updatedAt: at,
      ...(outcome === 'pay' ? {
        payoutReleasedAt: at, stripeTransferId: transferId,
        status: now.get('status') === 'completed' ? 'payout_released' : now.get('status'),
      } : {}),
    });
  });
  return { bookingId, outcome, transferId };
});

// ── Licence expiry (daily) ───────────────────────────────────────────────────

/**
 * `passed` licences whose `licenseExpiresAt` has come → `expired` (stage 2
 * goes, onInstructorWrite), and the instructor is told. One field in the
 * query, so no composite index; the status is checked per doc.
 */
export async function runExpireInstructorLicenses(nowMs = Date.now()): Promise<SweepResult> {
  return sweepPaginated({
    label: 'expireInstructorLicenses',
    baseQuery: db().collection('instructors').where('licenseExpiresAt', '<=', Timestamp.fromMillis(nowMs)).orderBy('licenseExpiresAt'),
    deadline: Date.now() + SWEEP_TIME_BUDGET_MS,
    handle: async (doc) => {
      const expired = await db().runTransaction(async (tx) => {
        const snap = await tx.get(doc.ref);
        if (snap.get('licenseCheck') !== 'passed' || (ms(snap.get('licenseExpiresAt')) ?? Infinity) > nowMs) return false;
        tx.update(doc.ref, { licenseCheck: 'expired', updatedAt: Timestamp.now() });
        return true;
      });
      // After the commit, so a retried transaction cannot push twice.
      if (expired) await sendPushToUser(doc.id, 'license_expired', 'profile');
    },
  });
}

export const expireInstructorLicenses = functions
  .runWith({ timeoutSeconds: 540, memory: '256MB' })
  .pubsub.schedule('every day 03:00').timeZone('America/Chicago')
  .onRun(async () => { await runExpireInstructorLicenses(); });

// ── School cancellations alert (plan v2 §9.3) ────────────────────────────────

/**
 * After a school cancels: 3 school cancellations in 30 days raise an alert
 * on the board — a report doc (`contentType: 'school_cancellations'`,
 * `userId: 'system'`, one per school), so it triages like the rest. Only
 * cancellations after the last time it was closed count, so a dismissed
 * alert comes back after three new ones, not after the next one.
 */
export async function noteSchoolCancellation(instructorUid: string, nowMs = Date.now()): Promise<boolean> {
  const ref = db().collection('reports').doc(`alert_cancellations_${instructorUid}`);
  const bookings = await db().collection('bookings').where('instructorUid', '==', instructorUid).get();
  return db().runTransaction(async (tx) => {
    const alert = await tx.get(ref);
    const closedAtMs = reportStage(alert.get('status')) === 'resolved' ? ms(alert.get('resolvedAt')) ?? 0 : 0;
    const from = Math.max(nowMs - CANCELLATION_WINDOW_MS, closedAtMs);
    const count = bookings.docs.filter((b) => b.get('cancelledBy') === 'instructor' && (ms(b.get('cancelledAt')) ?? 0) > from).length;
    if (count < CANCELLATION_ALERT_COUNT) return false;
    const at = Timestamp.fromMillis(nowMs);
    if (alert.exists && reportStage(alert.get('status')) !== 'resolved') {
      tx.update(ref, { count, updatedAt: at });
      return false;
    }
    tx.set(ref, {
      contentType: 'school_cancellations', reason: 'cancellations', entity: { instructorUid },
      count, userId: 'system', status: 'open', createdAt: at, updatedAt: at,
    });
    return true;
  });
}
