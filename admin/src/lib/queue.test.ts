import { describe, expect, it } from 'vitest';
import type { QueueItem } from './api';
import { byStage, describe as describeItem, matches, priority, resolutionLabel, sortItems } from './queue';

const item = (over: Partial<QueueItem>): QueueItem => ({
  key: `${over.type ?? 'review'}:${over.id ?? 'x'}`, type: 'review', id: 'x', stage: 'new', urgent: false,
  createdAtMs: 1000, resolvedAtMs: null, resolution: null, ...over,
});

describe('the board', () => {
  it('urgent first, then money waiting on the admin, then the oldest', () => {
    const old = item({ id: 'old', createdAtMs: 1 });
    const newer = item({ id: 'new', createdAtMs: 50 });
    const noShow = item({ id: 'ns', type: 'no_show', urgent: true, createdAtMs: 99 });
    const lost = item({ id: 'cd', type: 'card_dispute', actionable: true, createdAtMs: 80 });
    expect(sortItems([newer, old, lost, noShow]).map((i) => i.id)).toEqual(['ns', 'cd', 'old', 'new']);
  });

  it('resolved items: most recent first, and never marked urgent', () => {
    const a = item({ id: 'a', stage: 'resolved', resolvedAtMs: 5, urgent: true });
    const b = item({ id: 'b', stage: 'resolved', resolvedAtMs: 9 });
    expect(sortItems([a, b]).map((i) => i.id)).toEqual(['b', 'a']);
    expect(priority(a)).toBeNull();
  });

  it('splits into the three columns', () => {
    const cols = byStage([item({ id: '1' }), item({ id: '2', stage: 'in_review' }), item({ id: '3', stage: 'resolved' })]);
    expect([cols.new.length, cols.in_review.length, cols.resolved.length]).toEqual([1, 1, 1]);
  });

  it('an open card dispute is Stripe’s, not high priority', () => {
    expect(priority(item({ type: 'card_dispute', actionable: false }))).toBeNull();
    expect(priority(item({ type: 'card_dispute', actionable: true }))).toBe('high');
  });
});

describe('cards read right', () => {
  it('a review report quotes what was reported', () => {
    const d = describeItem(item({ reason: 'harassment', reported: { rating: 1, comment: 'Rude' }, instructor: { uid: 'i', name: 'Northside', kind: 'school', state: 'IL', status: 'active', stage: 2 } }));
    expect(d).toMatchObject({ title: 'Review of Northside', subtitle: 'Harassment · “Rude”' });
  });

  it('an alert names the school and the count', () => {
    expect(describeItem(item({ type: 'alert', count: 4, instructor: { uid: 'i', name: 'Bayou City', kind: 'school', state: 'TX', status: 'active', stage: 2 } })).title)
      .toBe('Bayou City cancelled 4 lessons');
  });

  it('resolutions and the filter', () => {
    expect(resolutionLabel(item({ resolution: 'review_hidden' }))).toBe('Review hidden');
    expect(resolutionLabel(item({ resolution: 'keep_unpaid' }))).toBe('Kept unpaid');
    const r = item({ type: 'licence', name: 'Lakeview', schoolLicenseNumber: 'IL-DS-1000', licenseState: 'IL' });
    expect(matches(r, 'lakeview')).toBe(true);
    expect(matches(r, 'il-ds-1000')).toBe(true);
    expect(matches(r, 'houston')).toBe(false);
  });
});
