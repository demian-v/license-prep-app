import { ArrowRight } from 'lucide-react';
import { useData } from '../lib/data';
import { describe, sortItems, TYPE_META } from '../lib/queue';
import { age, greeting, money } from '../lib/format';
import { weekOverWeek } from '../lib/insights';
import { Bars, Rings } from '../components/charts';
import { CountUp, Empty, PageHeader, Panel, Priority, StatTile, Tag } from '../components/ui';
import { useOpenItem } from '../components/Items';
import { priority } from '../lib/queue';
import type { Page } from '../components/Shell';

const REPORT_TYPES = ['review', 'message', 'instructor', 'content', 'alert'];
const DISPUTE_TYPES = ['no_show', 'card_dispute'];

export default function Overview({ onPage }: { onPage: (p: Page) => void }) {
  const { items, bookings } = useData();
  const open = useOpenItem();
  const waiting = items.filter((i) => i.stage !== 'resolved');
  const today = new Date().setHours(0, 0, 0, 0);
  const of = (types: string[]) => {
    const all = items.filter((i) => types.includes(i.type));
    return {
      open: all.filter((i) => i.stage !== 'resolved').length,
      cleared: all.filter((i) => i.stage === 'resolved' && (i.resolvedAtMs ?? 0) >= today).length,
    };
  };
  const reports = of(REPORT_TYPES);
  const licences = of(['licence']);
  const disputes = of(DISPUTE_TYPES);
  const heldCents = waiting.filter((i) => DISPUTE_TYPES.includes(i.type)).reduce((a, i) => a + (i.lessonCents ?? 0), 0);
  const upNext = sortItems(waiting).slice(0, 5);
  const [first, ...rest] = upNext;

  const rows = bookings[30] ?? [];
  const days = Array.from({ length: 7 }, (_, i) => today - (6 - i) * 864e5);
  const perDay = days.map((d) => rows.filter((b) => (b.createdAtMs ?? 0) >= d && (b.createdAtMs ?? 0) < d + 864e5).length);
  const wow = weekOverWeek(rows);
  const urgent = waiting.filter((i) => i.urgent).length;

  return (
    <>
      <PageHeader title={`${greeting(new Date().getHours())}`}
        subtitle={`${new Intl.DateTimeFormat('en-US', { weekday: 'long', month: 'long', day: 'numeric' }).format(Date.now())} · ${waiting.length} waiting, ${urgent} urgent`}>
        <button className="btn primary" onClick={() => onPage('queue')}>Open the queue <ArrowRight size={16} /></button>
      </PageHeader>

      <div className="mb-4 flex flex-wrap gap-3">
        <StatTile label="Open reports" value={reports.open} />
        <StatTile label="Licences to review" value={licences.open} />
        <StatTile label="No-shows & disputes" value={disputes.open} tone="urgent" />
        <StatTile label="Payouts held" value={heldCents / 100} format={(n) => money(Math.round(n) * 100, { whole: true })} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Panel title="Today" subtitle="Clear the rings">
          <div className="flex flex-wrap items-center justify-center gap-8 py-2">
            <Rings size={164} rings={[
              { label: 'Reports', value: reports.cleared, total: reports.cleared + reports.open, color: '#f43f5e' },
              { label: 'Licences', value: licences.cleared, total: licences.cleared + licences.open, color: '#4ade80' },
              { label: 'Disputes', value: disputes.cleared, total: disputes.cleared + disputes.open, color: '#22d3ee' },
            ]} />
            <div className="space-y-3">
              {[['Reports', reports, '#f43f5e'], ['Licences', licences, '#4ade80'], ['Disputes', disputes, '#22d3ee']].map(([label, c, color]) => {
                const counts = c as { open: number; cleared: number };
                return (
                  <div key={label as string} className="border-l-[3px] pl-3" style={{ borderColor: color as string }}>
                    <div className="text-[12.5px] text-ink-3">{label as string}</div>
                    <div className="text-[20px] leading-6 font-semibold"><CountUp value={counts.cleared} /><span className="text-[14px] font-medium text-ink-3"> / {counts.cleared + counts.open}</span></div>
                  </div>
                );
              })}
            </div>
          </div>
        </Panel>

        <Panel title="Up next" subtitle="Waiting longest, urgent first" action={<button className="text-[13px] font-semibold" style={{ color: 'var(--accent-ink)' }} onClick={() => onPage('queue')}>All items</button>}>
          {!first ? <Empty>Nothing waiting. 🎉</Empty> : (
            <>
              <button onClick={() => open(first)} className="mb-3 block w-full rounded-[18px] p-4 text-left"
                style={{ background: 'color-mix(in srgb, var(--accent) 22%, transparent)', boxShadow: 'inset 0 0 0 1px color-mix(in srgb, var(--accent-ink) 35%, transparent)' }}>
                <div className="flex items-center gap-2"><Tag hue={TYPE_META[first.type].hue}>{TYPE_META[first.type].label}</Tag><Priority level={priority(first)} /><span className="ml-auto text-[12.5px] text-ink-2">waiting {age(first.createdAtMs)}</span></div>
                <div className="mt-2 text-[17px] leading-6 font-semibold">{describe(first).title}</div>
                <div className="mt-0.5 line-clamp-1 text-[13px] text-ink-2">{describe(first).subtitle}</div>
              </button>
              <ul className="space-y-1">
                {rest.map((i) => (
                  <li key={i.key}>
                    <button onClick={() => open(i)} className="flex w-full items-center gap-3 rounded-xl px-2 py-2 text-left hover:bg-[var(--card)]">
                      <span className="h-5 w-[3px] rounded-full" style={{ background: `hsl(${TYPE_META[i.type].hue} 85% 60%)` }} />
                      <span className="min-w-0 flex-1 truncate text-[14px] font-medium">{describe(i).title}</span>
                      <span className="text-[12.5px] text-ink-3">{age(i.createdAtMs)}</span>
                    </button>
                  </li>
                ))}
              </ul>
            </>
          )}
        </Panel>

        <Panel className="lg:col-span-2" title="This week" subtitle="Lessons booked per day"
          action={<span className="text-[13px] text-ink-3"><span className="text-[20px] font-semibold text-ink"><CountUp value={wow.thisWeek} /></span> booked{wow.change !== null && <span className={wow.change >= 0 ? 'text-[var(--good)]' : 'text-[var(--bad)]'}> {wow.change >= 0 ? '+' : ''}{Math.round(wow.change * 100)}% vs last week</span>}</span>}>
          <Bars values={perDay} highlight={6} caption="Lessons booked per day this week"
            labels={days.map((d) => new Intl.DateTimeFormat('en-US', { weekday: 'short' }).format(d))} />
        </Panel>
      </div>
    </>
  );
}
