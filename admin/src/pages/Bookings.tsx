import { useData } from '../lib/data';
import { priority, reasonLabel, resolutionLabel, sortItems } from '../lib/queue';
import { age, date, money } from '../lib/format';
import { Empty, PageHeader, Panel, Priority, StatTile } from '../components/ui';
import { useOpenItem } from '../components/Items';
import type { QueueItem } from '../lib/api';

/** No-show reports (plan v2 §9.3) and card disputes (P9): where the schools' money is held. */
export default function Bookings() {
  const { items, bookings } = useData();
  const open = useOpenItem();
  const noShows = sortItems(items.filter((i) => i.type === 'no_show'));
  const disputes = sortItems(items.filter((i) => i.type === 'card_dispute'));
  const waiting = (l: QueueItem[]) => l.filter((i) => i.stage !== 'resolved');
  const rows = bookings[30] ?? [];

  const list = (l: QueueItem[], none: string) => l.length === 0 ? <Empty>{none}</Empty> : (
    <ul className="space-y-2">
      {l.map((i) => (
        <li key={i.key}>
          <button onClick={() => open(i)} className="card interactive flex w-full items-center gap-4 p-3.5 text-left">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2"><span className="truncate text-[14px] font-semibold">{i.instructorName}</span><Priority level={priority(i)} /></div>
              <div className="truncate text-[12.5px] text-ink-3">{i.studentName} · lesson {date(i.startAtMs ?? null, true)} · {i.type === 'no_show' ? reasonLabel(i.noShowReason) : i.disputeStatus === 'open' ? 'Stripe is running it' : `dispute ${i.disputeStatus}`}</div>
            </div>
            <div className="text-right">
              <div className="text-[15px] font-semibold tabular-nums">{money(i.totalCents ?? 0)}</div>
              <div className="text-[12px] text-ink-3">{i.stage === 'resolved' ? resolutionLabel(i) : `waiting ${age(i.createdAtMs)}`}</div>
            </div>
          </button>
        </li>
      ))}
    </ul>
  );

  return (
    <>
      <PageHeader title="Bookings & disputes" subtitle="A refund or a payout here can't be undone; each asks first" />
      <div className="mb-4 flex flex-wrap gap-3">
        <StatTile label="No-show reports" value={waiting(noShows).length} tone="urgent" />
        <StatTile label="Lost card disputes" value={waiting(disputes).filter((i) => i.actionable).length} />
        <StatTile label="Disputes Stripe is running" value={waiting(disputes).filter((i) => !i.actionable).length} />
        <StatTile label="Lessons booked · 30 days" value={rows.length} />
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel title="No-show reports" subtitle="The student says the lesson didn't happen; the payout is held">{list(noShows, 'No reports')}</Panel>
        <Panel title="Card disputes" subtitle="Lost: pay the school by hand or keep it unpaid. Open: Stripe runs it">{list(disputes, 'No disputes')}</Panel>
      </div>
    </>
  );
}
