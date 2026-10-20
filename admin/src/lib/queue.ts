import type { QueueItem, QueueType, Stage } from './api';
import { money } from './format';

/** Each kind's label and tag hue (one colour per type on the board). */
export const TYPE_META: Record<QueueType, { label: string; hue: number }> = {
  review: { label: 'Review report', hue: 38 },
  message: { label: 'Message report', hue: 199 },
  instructor: { label: 'Instructor report', hue: 268 },
  content: { label: 'Question report', hue: 172 },
  alert: { label: 'Cancellations', hue: 340 },
  licence: { label: 'Licence', hue: 226 },
  no_show: { label: 'No-show', hue: 2 },
  card_dispute: { label: 'Card dispute', hue: 24 },
};

export const STAGES: { id: Stage; label: string; hue: number }[] = [
  { id: 'new', label: 'New', hue: 220 },
  { id: 'in_review', label: 'In review', hue: 268 },
  { id: 'resolved', label: 'Resolved', hue: 142 },
];

/** Urgent: a no-show (money held for a student who says the lesson didn't happen), harassment, an alert. High: money waiting on the admin. */
export function priority(item: QueueItem): 'urgent' | 'high' | null {
  if (item.stage === 'resolved') return null;
  if (item.urgent) return 'urgent';
  if (item.type === 'card_dispute' && item.actionable) return 'high';
  return null;
}

/** Waiting longest first; urgent before the rest. Resolved: most recent first. */
export function sortItems(items: QueueItem[]): QueueItem[] {
  return [...items].sort((a, b) => {
    if (a.stage === 'resolved' && b.stage === 'resolved') return (b.resolvedAtMs ?? 0) - (a.resolvedAtMs ?? 0);
    const pa = priority(a) === 'urgent' ? 0 : priority(a) === 'high' ? 1 : 2;
    const pb = priority(b) === 'urgent' ? 0 : priority(b) === 'high' ? 1 : 2;
    return pa - pb || (a.createdAtMs ?? 0) - (b.createdAtMs ?? 0);
  });
}

export function byStage(items: QueueItem[]): Record<Stage, QueueItem[]> {
  const out: Record<Stage, QueueItem[]> = { new: [], in_review: [], resolved: [] };
  for (const i of sortItems(items)) out[i.stage].push(i);
  return out;
}

const CONTENT_LABEL: Record<string, string> = { quiz_question: 'Question', theory_section: 'Theory section', profile_section: 'Profile section' };
const REASON: Record<string, string> = {
  harassment: 'Harassment', inappropriate: 'Inappropriate', spam: 'Spam', other: 'Other', fake_profile: 'Fake profile',
  translation: 'Translation', image: 'Image', cancellations: 'School cancellations',
  instructor_no_show: "Instructor didn't come", lesson_not_given: "Lesson wasn't given",
  fraudulent: 'Fraudulent', product_not_received: 'Not received', duplicate: 'Duplicate', general: 'General',
};
export const reasonLabel = (r: string | null | undefined) => (r ? REASON[r] ?? r.replace(/_/g, ' ') : '');

/** The card's headline and one line under it. */
export function describe(item: QueueItem): { title: string; subtitle: string; person: string } {
  const who = item.instructor?.name || item.instructorName || item.name || '';
  switch (item.type) {
    case 'review':
      return { title: `Review of ${who || 'a school'}`, subtitle: `${reasonLabel(item.reason)} · “${item.reported?.comment ?? ''}”`, person: who };
    case 'message':
      return { title: `Message from ${item.senderName || 'someone'}`, subtitle: `${reasonLabel(item.reason)} · “${item.current?.text ?? 'deleted'}”`, person: item.senderName ?? '' };
    case 'instructor':
      return { title: who || 'An instructor', subtitle: `${reasonLabel(item.reason)}${item.message ? ` · ${item.message}` : ''}`, person: who };
    case 'alert':
      return { title: `${who || 'A school'} cancelled ${item.count ?? 3} lessons`, subtitle: 'In the last 30 days', person: who };
    case 'content':
      return {
        title: `${CONTENT_LABEL[item.contentType ?? ''] ?? 'Content'}: ${reasonLabel(item.reason)}`,
        subtitle: `${item.message ?? String(item.entity?.questionId ?? item.entity?.topicDocId ?? '')}${item.language ? ` · ${item.language.toUpperCase()}` : ''}`,
        person: '',
      };
    case 'licence':
      return {
        title: `${who} · licence`,
        subtitle: [item.schoolLicenseNumber, item.instructorLicenseNumber].filter(Boolean).join(' · ') + ` · ${item.licenseState ?? ''}`,
        person: who,
      };
    case 'no_show':
      return { title: `No-show · ${who}`, subtitle: `${item.studentName} · ${item.localDate ?? ''} ${item.localTime ?? ''} · ${money(item.totalCents ?? 0)}`, person: item.studentName ?? '' };
    case 'card_dispute':
      return {
        title: `Card dispute · ${who}`,
        subtitle: `${item.disputeStatus === 'open' ? 'Stripe is running it' : `Lost · payout cancelled`} · ${money(item.disputeAmountCents ?? item.totalCents ?? 0)}`,
        person: who,
      };
  }
}

/** What a resolved item's resolution reads as. */
export function resolutionLabel(item: QueueItem): string {
  const r = item.resolution;
  const map: Record<string, string> = {
    review_hidden: 'Review hidden', dismissed: 'Dismissed', resolved: 'Fixed', instructor_suspended: 'Suspended',
    passed: 'Licence approved', rejected: 'Licence rejected', expired: 'Licence expired', pending: 'Back to pending',
    refund: 'Refunded', release: 'Payout released', pay: 'School paid by hand', keep_unpaid: 'Kept unpaid',
  };
  return r ? map[r] ?? r : '';
}

export function matches(item: QueueItem, query: string): boolean {
  const q = query.trim().toLowerCase();
  if (!q) return true;
  const d = describe(item);
  return [d.title, d.subtitle, d.person, item.instructor?.state, item.state].filter(Boolean).join(' ').toLowerCase().includes(q);
}
