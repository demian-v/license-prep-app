import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';

/** The board's item kinds (functions/src/admin.ts QueueType). */
export type QueueType = 'review' | 'message' | 'instructor' | 'content' | 'alert' | 'licence' | 'no_show' | 'card_dispute';
export type Stage = 'new' | 'in_review' | 'resolved';

export interface InstructorRef {
  uid: string; name: string; kind: string | null; state: string | null; status: string | null; stage: number;
}

/** One item as adminGetQueue returns it; the type decides which details are there. */
export interface QueueItem {
  key: string;
  type: QueueType;
  id: string;
  stage: Stage;
  urgent: boolean;
  createdAtMs: number | null;
  resolvedAtMs: number | null;
  resolution: string | null;
  instructor?: InstructorRef | null;
  instructorUid?: string | null;
  // reports
  reason?: string | null;
  message?: string | null;
  contentType?: string;
  language?: string | null;
  state?: string | null;
  reviewId?: string | null;
  reported?: { rating: number; comment: string } | null;
  current?: { rating?: number; comment?: string; author?: string; hidden?: boolean; text?: string; masked?: boolean; updatedAtMs?: number | null; createdAtMs?: number | null } | null;
  sender?: 'instructor' | 'student' | null;
  senderName?: string;
  count?: number | null;
  entity?: Record<string, unknown>;
  // licences
  name?: string;
  kind?: string;
  licenseState?: string;
  schoolName?: string | null;
  schoolLicenseNumber?: string | null;
  instructorLicenseNumber?: string | null;
  licenseExpiresAtMs?: number | null;
  // bookings
  instructorName?: string;
  studentName?: string;
  startAtMs?: number | null;
  localDate?: string | null;
  localTime?: string | null;
  timezone?: string | null;
  durationMinutes?: number | null;
  lessonCents?: number;
  platformFeeCents?: number;
  totalCents?: number;
  status?: string;
  paymentProvider?: string | null;
  noShowReason?: string | null;
  disputeStatus?: string | null;
  disputeReason?: string | null;
  disputeAmountCents?: number | null;
  payoutReleased?: boolean;
  actionable?: boolean;
}

export interface InstructorRow {
  uid: string; name: string; kind: string | null; state: string | null; city: string | null; status: string | null;
  listed: boolean; stage: number; idCheck: string; licenseCheck: string; licenseExpiresAtMs: number | null;
  payoutsEnabled: boolean; ratingAvg: number; ratingCount: number; photoStatus: string; createdAtMs: number | null;
  cancellations30d: number;
}

export interface BookingRow {
  id: string; createdAtMs: number | null; startAtMs: number | null; status: string; state: string | null;
  instructorName: string; lessonCents: number; platformFeeCents: number; totalCents: number; feeKind: string | null;
  cancelledBy: string | null; refundedAtMs: number | null; payoutDueAtMs: number | null; payoutReleasedAtMs: number | null;
  disputeStatus: string | null; noShow: boolean; paymentProvider: string | null;
}

function callable<Req, Res>(name: string) {
  const fn = httpsCallable<Req, Res>(functions, name);
  return async (data: Req): Promise<Res> => (await fn(data)).data;
}

export const api = {
  queue: callable<Record<string, never>, { items: QueueItem[]; generatedAtMs: number }>('adminGetQueue'),
  instructors: callable<Record<string, never>, { instructors: InstructorRow[] }>('adminListInstructors'),
  bookings: callable<{ days: 7 | 30 | 90 }, { days: number; bookings: BookingRow[] }>('adminGetBookings'),
  setReportStatus: callable<{ reportId: string; status: 'open' | 'in_review' | 'dismissed' | 'resolved' }, unknown>('adminSetReportStatus'),
  hideReview: callable<{ instructorUid: string; reviewId: string; hidden: boolean; reportId?: string }, unknown>('adminHideReview'),
  setInstructorStatus: callable<{ uid: string; status: 'active' | 'suspended'; reportId?: string }, { status: string }>('adminSetInstructorStatus'),
  reviewLicense: callable<{ uid: string; approved: boolean | null; expiresAtMs?: number }, unknown>('adminReviewLicense'),
  setInReview: callable<{ type: 'report' | 'licence' | 'booking'; id: string; on: boolean }, unknown>('adminSetInReview'),
  resolveNoShow: callable<{ bookingId: string; outcome: 'refund' | 'release' }, { status: string }>('adminResolveNoShow'),
  resolveLostDispute: callable<{ bookingId: string; outcome: 'pay' | 'keep_unpaid' }, unknown>('adminResolveLostDispute'),
};

/** The server's short reason (HttpsError message) for the island's error toast. */
export function errorText(e: unknown): string {
  const err = e as { code?: string; message?: string };
  if (err?.code === 'functions/permission-denied') return 'This account is not an admin.';
  if (err?.code === 'functions/unavailable' || err?.code === 'functions/internal') return 'Emulators not reachable — are they running?';
  return err?.message || 'Something went wrong.';
}
