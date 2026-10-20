import { useEffect, useMemo, useState } from 'react';
import { Download } from 'lucide-react';
import { useData } from '../lib/data';
import { aggregate, toCsv } from '../lib/insights';
import { describe, TYPE_META } from '../lib/queue';
import { age, money } from '../lib/format';
import { AreaChart, Bars, Donut, Meter } from '../components/charts';
import { CountUp, Empty, PageHeader, Panel, Segmented, StatTile, Tag } from '../components/ui';
import { useOpenItem } from '../components/Items';

const STATE_COLORS = ['#60a5fa', '#a78bfa', '#4ade80', '#f472b6', '#fbbf24', '#22d3ee'];

export default function Insights() {
  const { bookings, loadBookings, items } = useData();
  const open = useOpenItem();
  const [days, setDays] = useState<7 | 30 | 90>(30);
  useEffect(() => { if (!bookings[days]) void loadBookings(days); }, [days, bookings, loadBookings]);
  const rows = useMemo(() => bookings[days] ?? [], [bookings, days]);
  const s = useMemo(() => aggregate(rows, days), [rows, days]);
  // Oldest first, whatever the priority (urgent items are on Overview and the bell).
  const slowest = items.filter((i) => i.stage !== 'resolved' && !i.urgent)
    .sort((a, b) => (a.createdAtMs ?? 0) - (b.createdAtMs ?? 0)).slice(0, 3);

  function exportCsv() {
    const url = URL.createObjectURL(new Blob([toCsv(rows)], { type: 'text/csv' }));
    const a = Object.assign(document.createElement('a'), { href: url, download: `driveusa-bookings-${days}d-${new Date().toISOString().slice(0, 10)}.csv` });
    a.click();
    URL.revokeObjectURL(url);
  }

  // Days on 7D/30D; full weeks ending today on 90D (a partial week would dip the line).
  const weekly = days === 90;
  const weeks = Array.from({ length: Math.floor(s.perDay.length / 7) }, (_, w) => s.perDay.slice(s.perDay.length - (w + 1) * 7, s.perDay.length - w * 7)).reverse();
  const series = weekly ? weeks.map((w) => w.reduce((a, p) => a + p.count, 0)) : s.perDay.map((p) => p.count);
  const fmt = new Intl.DateTimeFormat('en-US', days === 7 ? { weekday: 'short' } : { month: 'short', day: 'numeric' });
  const labels = weekly ? weeks.map((w) => fmt.format(w[0].dayMs)) : s.perDay.map((p) => fmt.format(p.dayMs));

  return (
    <>
      <PageHeader title="Insights" subtitle={`Lessons booked in the last ${days} days`}>
        <Segmented id="insights-range" label="Range" value={String(days) as '7' | '30' | '90'} onChange={(v) => setDays(Number(v) as 7 | 30 | 90)}
          options={[{ value: '7', label: '7D' }, { value: '30', label: '30D' }, { value: '90', label: '90D' }]} />
        <button className="btn" onClick={exportCsv} disabled={!rows.length}><Download size={15} /> Export CSV</button>
      </PageHeader>
      <div className="mb-4 flex flex-wrap gap-3">
        <StatTile label="Bookings" value={s.bookings} />
        <StatTile label="DriveUSA fees" value={s.feesCents} format={(n) => money(Math.round(n), { whole: true })} />
        <StatTile label="Refunded" value={s.refundsCents} format={(n) => money(Math.round(n), { whole: true })} />
        <StatTile label="Paid to schools" value={s.paidOutCents} format={(n) => money(Math.round(n), { whole: true })} />
        <StatTile label="Disputes" value={s.disputes} />
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel className="lg:col-span-2" title="Bookings" subtitle={weekly ? 'Per week' : 'Per day'}
          action={<span className="text-[13px] text-ink-3"><span className="text-[22px] font-semibold text-ink"><CountUp value={s.bookings} /></span> booked</span>}>
          <AreaChart key={days} values={series} labels={labels} caption={`Bookings ${weekly ? 'per week' : 'per day'}, last ${days} days`} />
        </Panel>
        <Panel title="By state" subtitle="Where the lessons were">
          {s.byState.length === 0 ? <Empty>No lessons in this range</Empty> : (
            <div className="flex flex-wrap items-center gap-6">
              <Donut key={days} caption="lessons" centre={<CountUp value={s.byState.reduce((a, b) => a + b.count, 0)} />}
                slices={s.byState.map((b, i) => ({ label: b.state, value: b.count, color: STATE_COLORS[i % STATE_COLORS.length] }))} />
              <ul className="min-w-[180px] flex-1 space-y-2">
                {s.byState.map((b, i) => (
                  <li key={b.state} className="flex items-center gap-2.5 text-[13.5px]">
                    <span className="h-2.5 w-2.5 rounded-full" style={{ background: STATE_COLORS[i % STATE_COLORS.length] }} />
                    <span className="flex-1 font-medium">{b.state}</span>
                    <span className="tabular-nums">{b.count}</span>
                    <span className="w-10 text-right text-ink-3 tabular-nums">{Math.round(b.share * 100)}%</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </Panel>
        <Panel title="Payouts on time" subtitle="Paid within 2 h of the 48-hour mark">
          <div className="mb-3 flex items-baseline gap-2">
            <span className="text-[40px] leading-none font-semibold tabular-nums">{s.onTimeRate === null ? '—' : <CountUp value={s.onTimeRate * 100} />}</span>
            <span className="text-[16px] text-ink-3">{s.onTimeRate === null ? 'no payouts yet' : '% on time'}</span>
          </div>
          <Meter parts={[{ label: 'on time', value: s.onTime, color: '#4ade80' }, { label: 'late', value: s.late, color: '#fb7185' }]} />
          <div className="mt-2 flex gap-4 text-[12.5px] text-ink-3"><span><b className="text-ink">{s.onTime}</b> on time</span><span><b className="text-ink">{s.late}</b> late</span></div>
          <h3 className="mt-5 mb-2 text-[13px] font-semibold text-ink-2">Waiting longest</h3>
          {slowest.length === 0 ? <p className="text-[13px] text-ink-3">Nothing waiting</p> : (
            <ul className="space-y-1">
              {slowest.map((i) => (
                <li key={i.key}>
                  <button onClick={() => open(i)} className="flex w-full items-center gap-3 rounded-xl px-1.5 py-1.5 text-left hover:bg-[var(--card)]">
                    <Tag hue={TYPE_META[i.type].hue}>{TYPE_META[i.type].label}</Tag>
                    <span className="min-w-0 flex-1 truncate text-[13.5px] font-medium">{describe(i).title}</span>
                    <span className="text-[13px] font-semibold tabular-nums">{age(i.createdAtMs)}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </Panel>
        <Panel className="lg:col-span-2" title="DriveUSA fees" subtitle="Per week, from lessons that kept their fee">
          <Bars key={days} values={s.feesPerWeek.map((w) => w.cents)} format={(c) => money(c)} caption="Fees per week"
            labels={s.feesPerWeek.map((w) => new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' }).format(w.weekMs))} highlight={s.feesPerWeek.length - 1} />
        </Panel>
      </div>
    </>
  );
}
