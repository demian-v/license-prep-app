import { api, type QueueItem } from './api';
import { describe } from './queue';

/**
 * What the admin can do with an item. Every moderation action has its Undo
 * (hide, never delete — plan v2 §18a); money actions can't be undone, so
 * they ask first (`confirm`) and the toast has no Undo.
 */
export interface Action {
  id: string;
  label: string;
  tone?: 'primary' | 'danger';
  /** A licence approval needs the expiry date. */
  needsDate?: boolean;
  confirm?: { title: string; body: string; cta: string };
  /** How the card looks right away, before the server's answer (the board animates it). */
  optimistic: Partial<QueueItem>;
  toast: string;
  run: (opts: { expiresAtMs?: number }) => Promise<unknown>;
  undo?: () => Promise<unknown>;
}

const reportStatus = (item: QueueItem, status: 'open' | 'in_review' | 'dismissed' | 'resolved') =>
  api.setReportStatus({ reportId: item.id, status });

const now = () => Date.now();

export function actionsFor(item: QueueItem): Action[] {
  const name = describe(item).title;
  const isReport = ['review', 'message', 'instructor', 'content', 'alert'].includes(item.type);
  const instructorUid = item.instructorUid ?? item.instructor?.uid ?? null;
  const suspended = item.instructor?.status === 'suspended';
  const out: Action[] = [];

  if (item.stage === 'resolved') {
    // The way back, where there is one.
    if (item.type === 'review' && item.resolution === 'review_hidden' && instructorUid && item.reviewId) {
      out.push({ id: 'unhide', label: 'Show review again', optimistic: { stage: 'new', resolution: null }, toast: 'Review shown again',
        run: () => api.hideReview({ instructorUid, reviewId: item.reviewId!, hidden: false, reportId: item.id }) });
    } else if (item.resolution === 'instructor_suspended' && instructorUid) {
      out.push({ id: 'lift', label: 'Lift suspension', optimistic: { stage: 'new', resolution: null }, toast: 'Suspension lifted',
        run: () => api.setInstructorStatus({ uid: instructorUid, status: 'active', reportId: item.id }) });
    } else if (isReport) {
      out.push({ id: 'reopen', label: 'Reopen', optimistic: { stage: 'new', resolution: null }, toast: 'Reopened', run: () => reportStatus(item, 'open') });
    } else if (item.type === 'licence') {
      out.push({ id: 'pending', label: 'Back to pending', optimistic: { stage: 'new', resolution: null }, toast: 'Licence back to pending',
        run: () => api.reviewLicense({ uid: item.id, approved: null }) });
    }
    return out;
  }

  const inReview = item.stage === 'in_review';
  const reviewToggle: Action = {
    id: inReview ? 'unreview' : 'review',
    label: inReview ? 'Back to New' : 'Start review',
    optimistic: { stage: inReview ? 'new' : 'in_review' },
    toast: inReview ? 'Back to New' : 'In review',
    run: () => isReport
      ? reportStatus(item, inReview ? 'open' : 'in_review')
      : api.setInReview({ type: item.type === 'licence' ? 'licence' : 'booking', id: item.id, on: !inReview }),
    undo: () => isReport
      ? reportStatus(item, inReview ? 'in_review' : 'open')
      : api.setInReview({ type: item.type === 'licence' ? 'licence' : 'booking', id: item.id, on: inReview }),
  };
  const resolved = (resolution: string): Partial<QueueItem> => ({ stage: 'resolved', resolution, resolvedAtMs: now() });

  switch (item.type) {
    case 'review':
      if (instructorUid && item.reviewId && item.current) {
        out.push({ id: 'hide', label: 'Hide review', tone: 'primary', optimistic: resolved('review_hidden'), toast: `Hidden: ${name}`,
          run: () => api.hideReview({ instructorUid, reviewId: item.reviewId!, hidden: true, reportId: item.id }),
          undo: () => api.hideReview({ instructorUid, reviewId: item.reviewId!, hidden: false, reportId: item.id }) });
      }
      break;
    case 'message':
    case 'instructor':
    case 'alert':
      if (instructorUid && (item.type !== 'message' || item.sender === 'instructor') && !suspended) {
        out.push({ id: 'suspend', label: item.type === 'alert' ? 'Suspend school' : 'Suspend instructor', tone: 'primary',
          optimistic: resolved('instructor_suspended'), toast: `Suspended: ${item.instructor?.name ?? 'instructor'}`,
          run: () => api.setInstructorStatus({ uid: instructorUid, status: 'suspended', reportId: item.id }),
          undo: () => api.setInstructorStatus({ uid: instructorUid, status: 'active', reportId: item.id }) });
      }
      break;
    case 'content':
      out.push({ id: 'fixed', label: 'Mark fixed', tone: 'primary', optimistic: resolved('resolved'), toast: `Fixed: ${name}`,
        run: () => reportStatus(item, 'resolved'), undo: () => reportStatus(item, 'open') });
      break;
    case 'licence':
      out.push({ id: 'approve', label: 'Approve licence', tone: 'primary', needsDate: true, optimistic: resolved('passed'), toast: `Licence approved: ${item.name}`,
        run: ({ expiresAtMs }) => api.reviewLicense({ uid: item.id, approved: true, expiresAtMs }),
        undo: () => api.reviewLicense({ uid: item.id, approved: null }) });
      out.push({ id: 'reject', label: 'Reject', tone: 'danger', optimistic: resolved('rejected'), toast: `Licence rejected: ${item.name}`,
        run: () => api.reviewLicense({ uid: item.id, approved: false }),
        undo: () => api.reviewLicense({ uid: item.id, approved: null }) });
      break;
    case 'no_show':
      out.push({ id: 'refund', label: 'Refund the student', tone: 'primary', optimistic: resolved('refund'), toast: `Refunded: ${item.studentName}`,
        confirm: { title: 'Refund this lesson?', body: `The whole payment goes back to the student's card (a payout already made to the school is reversed first). This can't be undone.`, cta: 'Refund' },
        run: () => api.resolveNoShow({ bookingId: item.id, outcome: 'refund' }) });
      out.push({ id: 'release', label: 'Release the payout', optimistic: resolved('release'), toast: `Payout released: ${item.instructorName}`,
        confirm: { title: 'Pay the school?', body: `The lesson counts as given and the school is paid within the hour (Stripe is checked for a transfer already made). This can't be undone.`, cta: 'Release payout' },
        run: () => api.resolveNoShow({ bookingId: item.id, outcome: 'release' }) });
      break;
    case 'card_dispute':
      if (item.actionable) {
        out.push({ id: 'pay', label: 'Pay the school', tone: 'primary', optimistic: resolved('pay'), toast: `Paid by hand: ${item.instructorName}`,
          confirm: { title: 'Pay the school by hand?', body: `The bank returned the student's payment, so the lesson price comes from DriveUSA's own balance. This can't be undone.`, cta: 'Pay school' },
          run: () => api.resolveLostDispute({ bookingId: item.id, outcome: 'pay' }) });
        out.push({ id: 'keep', label: 'Keep unpaid', optimistic: resolved('keep_unpaid'), toast: `Kept unpaid: ${item.instructorName}`,
          confirm: { title: 'Keep the payout cancelled?', body: 'The school is not paid for this lesson. This is final.', cta: 'Keep unpaid' },
          run: () => api.resolveLostDispute({ bookingId: item.id, outcome: 'keep_unpaid' }) });
      }
      break;
  }
  if (isReport) {
    out.push({ id: 'dismiss', label: 'Dismiss', optimistic: resolved('dismissed'), toast: `Dismissed: ${name}`,
      run: () => reportStatus(item, 'dismissed'), undo: () => reportStatus(item, 'open') });
  }
  if (item.type !== 'card_dispute' || item.actionable) out.push(reviewToggle);
  return out;
}
