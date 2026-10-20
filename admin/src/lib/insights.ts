import type { BookingRow } from './api';

const DAY = 864e5;
/** Statuses that keep the platform's fee (plan v2 §9.3). */
const FEE_KEPT = new Set(['confirmed', 'completed', 'late_cancelled', 'disputed', 'payout_released']);

export interface Insights {
  bookings: number;
  feesCents: number;
  refundsCents: number;
  paidOutCents: number;
  disputes: number;
  onTimeRate: number | null;
  onTime: number;
  late: number;
  /** Bookings made per day, oldest first, `days` long. */
  perDay: { dayMs: number; count: number }[];
  /** Fees per full week (7-day buckets ending today, `weekMs` = the first day), oldest first. */
  feesPerWeek: { weekMs: number; cents: number }[];
  /** Lessons by the school's state, largest first. */
  byState: { state: string; count: number; share: number }[];
}

const startOfDay = (ms: number) => { const d = new Date(ms); d.setHours(0, 0, 0, 0); return d.getTime(); };

export function aggregate(rows: BookingRow[], days: number, nowMs = Date.now()): Insights {
  const from = startOfDay(nowMs) - (days - 1) * DAY;
  const inRange = rows.filter((b) => (b.createdAtMs ?? 0) >= from);
  const perDay = Array.from({ length: days }, (_, i) => ({ dayMs: from + i * DAY, count: 0 }));
  const weeks = Math.max(1, Math.floor(days / 7));
  const feesPerWeek = Array.from({ length: weeks }, (_, i) => ({ weekMs: startOfDay(nowMs) - ((weeks - 1 - i) * 7 + 6) * DAY, cents: 0 }));
  const states = new Map<string, number>();
  let feesCents = 0, refundsCents = 0, paidOutCents = 0, disputes = 0, onTime = 0, late = 0;

  for (const b of inRange) {
    const day = Math.floor((startOfDay(b.createdAtMs!) - from) / DAY);
    if (perDay[day]) perDay[day].count += 1;
    if (FEE_KEPT.has(b.status)) {
      feesCents += b.platformFeeCents;
      const ago = Math.floor((startOfDay(nowMs) - startOfDay(b.createdAtMs!)) / DAY);
      const w = weeks - 1 - Math.floor(ago / 7);
      if (feesPerWeek[w]) feesPerWeek[w].cents += b.platformFeeCents;
    }
    if (b.status === 'refunded') refundsCents += b.totalCents;
    if (b.payoutReleasedAtMs != null) {
      paidOutCents += b.lessonCents;
      // On time: paid within 2 h of the 48 h mark (the job runs hourly).
      if (b.payoutDueAtMs != null && b.status !== 'late_cancelled') {
        if (b.payoutReleasedAtMs <= b.payoutDueAtMs + 2 * 3600e3) onTime += 1; else late += 1;
      }
    }
    if (b.noShow || (b.disputeStatus && b.disputeStatus !== 'won')) disputes += 1;
    if (b.status !== 'expired' && b.status !== 'pending_payment') states.set(b.state ?? '—', (states.get(b.state ?? '—') ?? 0) + 1);
  }
  const lessons = [...states.values()].reduce((a, b) => a + b, 0);
  return {
    bookings: inRange.length, feesCents, refundsCents, paidOutCents, disputes,
    onTimeRate: onTime + late ? onTime / (onTime + late) : null, onTime, late,
    perDay, feesPerWeek,
    byState: [...states.entries()].map(([state, count]) => ({ state, count, share: lessons ? count / lessons : 0 }))
      .sort((a, b) => b.count - a.count || a.state.localeCompare(b.state)),
  };
}

/** Last 7 days against the 7 before, for "+4% vs last week". Null with nothing to compare. */
export function weekOverWeek(rows: BookingRow[], nowMs = Date.now()): { thisWeek: number; change: number | null } {
  const today = startOfDay(nowMs);
  const count = (from: number, to: number) => rows.filter((b) => (b.createdAtMs ?? 0) >= from && (b.createdAtMs ?? 0) < to).length;
  const thisWeek = count(today - 6 * DAY, today + DAY);
  const last = count(today - 13 * DAY, today - 6 * DAY);
  return { thisWeek, change: last ? (thisWeek - last) / last : null };
}

const CSV_COLUMNS: (keyof BookingRow)[] = [
  'id', 'createdAtMs', 'startAtMs', 'status', 'state', 'instructorName', 'lessonCents', 'platformFeeCents', 'totalCents',
  'feeKind', 'cancelledBy', 'refundedAtMs', 'payoutReleasedAtMs', 'disputeStatus', 'noShow', 'paymentProvider',
];

/** One row per booking; times as ISO, amounts in dollars; quoted per RFC 4180. */
export function toCsv(rows: BookingRow[]): string {
  const cell = (k: keyof BookingRow, v: unknown): string => {
    if (v == null) return '';
    if (k.endsWith('AtMs')) return new Date(v as number).toISOString();
    if (k.endsWith('Cents')) return ((v as number) / 100).toFixed(2);
    const s = String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const header = CSV_COLUMNS.map((c) => c.replace(/AtMs$/, 'At').replace(/Cents$/, 'Usd')).join(',');
  return [header, ...rows.map((r) => CSV_COLUMNS.map((c) => cell(c, r[c])).join(','))].join('\n') + '\n';
}
