import { describe, expect, it } from 'vitest';
import type { BookingRow } from './api';
import { aggregate, toCsv, weekOverWeek } from './insights';
import { age, money } from './format';

const NOW = new Date(2026, 9, 19, 15, 0).getTime();
const DAY = 864e5;
const row = (over: Partial<BookingRow>): BookingRow => ({
  id: 'b', createdAtMs: NOW - DAY, startAtMs: NOW, status: 'payout_released', state: 'IL', instructorName: 'Lakeview',
  lessonCents: 6500, platformFeeCents: 325, totalCents: 6825, feeKind: 'later', cancelledBy: null, refundedAtMs: null,
  payoutDueAtMs: NOW, payoutReleasedAtMs: NOW + 3600e3, disputeStatus: null, noShow: false, paymentProvider: 'emulator', ...over,
});

describe('insights', () => {
  it('fees only from statuses that keep them; refunds; payouts; on-time within 2 h of the 48 h mark', () => {
    const s = aggregate([
      row({ id: '1' }),
      row({ id: '2', payoutReleasedAtMs: NOW + 30 * 3600e3 }),
      row({ id: '3', status: 'refunded', payoutReleasedAtMs: null, platformFeeCents: 1625, totalCents: 8125 }),
      row({ id: '4', status: 'late_cancelled', payoutReleasedAtMs: NOW, state: 'TX' }),
      row({ id: '5', createdAtMs: NOW - 40 * DAY }),
    ], 30, NOW);
    expect(s.bookings).toBe(4);
    expect(s.feesCents).toBe(325 * 3);
    expect(s.refundsCents).toBe(8125);
    expect(s.paidOutCents).toBe(6500 * 3);
    expect([s.onTime, s.late]).toEqual([1, 1]);
    expect(s.onTimeRate).toBe(0.5);
    expect(s.byState).toEqual([{ state: 'IL', count: 3, share: 0.75 }, { state: 'TX', count: 1, share: 0.25 }]);
  });

  it('buckets per day and per week, oldest first', () => {
    const s = aggregate([row({ createdAtMs: NOW }), row({ createdAtMs: NOW - 2 * DAY }), row({ createdAtMs: NOW - 2 * DAY })], 7, NOW);
    expect(s.perDay.map((d) => d.count)).toEqual([0, 0, 0, 0, 2, 0, 1]);
    expect(s.feesPerWeek.map((w) => w.cents)).toEqual([975]);
  });

  it('counts no-shows and disputes not won', () => {
    expect(aggregate([row({ noShow: true }), row({ disputeStatus: 'won' }), row({ disputeStatus: 'lost' })], 7, NOW).disputes).toBe(2);
  });

  it('week over week', () => {
    expect(weekOverWeek([row({ createdAtMs: NOW }), row({ createdAtMs: NOW - DAY }), row({ createdAtMs: NOW - 8 * DAY })], NOW)).toEqual({ thisWeek: 2, change: 1 });
    expect(weekOverWeek([], NOW)).toEqual({ thisWeek: 0, change: null });
  });

  it('CSV: dollars, ISO times, quoted names, no student', () => {
    const csv = toCsv([row({ instructorName: 'Smith, "Ace" School', createdAtMs: Date.UTC(2026, 9, 1) })]);
    const [header, line] = csv.trim().split('\n');
    expect(header.split(',')).toContain('platformFeeUsd');
    expect(header).not.toMatch(/student/i);
    expect(line).toContain('"Smith, ""Ace"" School"');
    expect(line).toContain('2026-10-01T00:00:00.000Z');
    expect(line).toContain(',65.00,3.25,68.25,');
  });
});

describe('format', () => {
  it('money and waiting time', () => {
    expect(money(6825)).toBe('$68.25');
    expect(money(250000)).toBe('$2,500');
    expect(age(NOW - 5 * 60e3, NOW)).toBe('5 min');
    expect(age(NOW - 3 * 3600e3, NOW)).toBe('3 h');
    expect(age(NOW - 3 * DAY, NOW)).toBe('3 d');
  });
});

describe('fees per week', () => {
  it('full weeks ending today, labelled by their first day; older days left out', () => {
    const s = aggregate([row({ createdAtMs: NOW }), row({ createdAtMs: NOW - 8 * DAY }), row({ createdAtMs: NOW - 29 * DAY })], 30, NOW);
    expect(s.feesPerWeek).toHaveLength(4);
    expect(s.feesPerWeek.map((w) => w.cents)).toEqual([0, 0, 325, 325]);
    expect(new Date(s.feesPerWeek[3].weekMs).getDate()).toBe(13);
  });
});
