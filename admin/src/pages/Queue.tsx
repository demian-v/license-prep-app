import { useMemo, useState } from 'react';
import { LayoutGroup, motion } from 'motion/react';
import { Columns3, List, Search } from 'lucide-react';
import type { QueueType } from '../lib/api';
import { useData } from '../lib/data';
import { byStage, describe, matches, priority, resolutionLabel, STAGES, TYPE_META } from '../lib/queue';
import { age } from '../lib/format';
import { Empty, PageHeader, Panel, Priority, Rise, Segmented, StatTile, Tag } from '../components/ui';
import { QueueCard, useOpenItem } from '../components/Items';
import { useSettings } from '../lib/settings';

const KINDS: QueueType[] = ['review', 'message', 'instructor', 'alert', 'content', 'licence', 'no_show', 'card_dispute'];

export default function Queue({ urgentOnly: urgentInitial = false }: { urgentOnly?: boolean }) {
  const { items } = useData();
  const open = useOpenItem();
  const { reduced } = useSettings();
  const [view, setView] = useState<'board' | 'list'>('board');
  const [kinds, setKinds] = useState<Set<QueueType>>(new Set());
  const [urgentOnly, setUrgentOnly] = useState(urgentInitial);
  const [query, setQuery] = useState('');

  const shown = useMemo(() => items.filter((i) => (kinds.size === 0 || kinds.has(i.type))
    && (!urgentOnly || (i.stage !== 'resolved' && priority(i) !== null)) && matches(i, query)), [items, kinds, urgentOnly, query]);
  const columns = byStage(shown);
  const waiting = items.filter((i) => i.stage !== 'resolved');
  const toggle = (k: QueueType) => setKinds((s) => { const n = new Set(s); if (n.has(k)) n.delete(k); else n.add(k); return n; });

  return (
    <>
      <PageHeader title="Queue" subtitle={`${waiting.length} open across ${new Set(waiting.map((i) => i.type)).size} kinds · resolved items stay 30 days`}>
        <Segmented id="queue-view" label="View" value={view} onChange={setView}
          options={[{ value: 'board', label: <><Columns3 size={15} /> Board</> }, { value: 'list', label: <><List size={15} /> List</> }]} />
      </PageHeader>

      <div className="mb-4 flex flex-wrap gap-3">
        <StatTile label="Open" value={waiting.length} />
        <StatTile label="Urgent" value={waiting.filter((i) => priority(i) === 'urgent').length} tone="urgent" />
        <StatTile label="In review" value={columns.in_review.length} />
        <StatTile label="Resolved · 30 days" value={items.filter((i) => i.stage === 'resolved').length} />
      </div>

      <Rise className="glass mb-4 flex flex-wrap items-center gap-2 !rounded-[22px] p-2">
        <button className={`chip btn small ${kinds.size === 0 ? 'primary' : ''}`} onClick={() => setKinds(new Set())} aria-pressed={kinds.size === 0}>All kinds</button>
        {KINDS.map((k) => (
          <button key={k} className="chip btn small" aria-pressed={kinds.has(k)} onClick={() => toggle(k)}
            style={kinds.has(k) ? { background: `hsl(${TYPE_META[k].hue} 80% 55% / 0.22)`, boxShadow: `inset 0 0 0 1px hsl(${TYPE_META[k].hue} 85% 65% / 0.5)` } : undefined}>
            <span className="h-2 w-2 rounded-full" style={{ background: `hsl(${TYPE_META[k].hue} 85% 60%)` }} />{TYPE_META[k].label}
          </button>
        ))}
        <button className="chip btn small" aria-pressed={urgentOnly} onClick={() => setUrgentOnly((u) => !u)}
          style={urgentOnly ? { background: 'hsl(0 80% 55% / 0.22)', boxShadow: 'inset 0 0 0 1px hsl(0 85% 65% / 0.5)' } : undefined}>Urgent only</button>
        <label className="relative ml-auto min-w-[220px] flex-1 sm:flex-none">
          <Search size={15} className="absolute top-1/2 left-3 -translate-y-1/2 text-ink-3" aria-hidden />
          <input className="field w-full !pl-9" placeholder="Filter by name, school, state" value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Filter" />
        </label>
      </Rise>

      {view === 'board' ? (
        <LayoutGroup>
          <div className="grid gap-4 md:grid-cols-3">
            {STAGES.map((s) => (
              <Panel key={s.id} className="!p-3">
                <header className="mb-3 flex items-center gap-2 px-1.5 pt-1">
                  <span className="h-2.5 w-2.5 rounded-full" style={{ background: `hsl(${s.hue} 85% 62%)`, boxShadow: `0 0 10px hsl(${s.hue} 85% 62% / 0.7)` }} />
                  <h2 className="text-[15px] font-semibold">{s.label}</h2>
                  <motion.span key={columns[s.id].length} initial={reduced ? false : { scale: 1.35 }} animate={{ scale: 1 }}
                    className="rounded-full px-2 text-[12px] font-semibold text-ink-2" style={{ background: 'var(--field)' }}>{columns[s.id].length}</motion.span>
                </header>
                <div className="scroll-fade no-scrollbar max-h-[calc(100vh-380px)] min-h-[200px] space-y-2.5 overflow-y-auto pb-10">
                  {columns[s.id].map((i) => <QueueCard key={i.key} item={i} />)}
                  {columns[s.id].length === 0 && <Empty>{s.id === 'resolved' ? 'Nothing resolved yet' : 'Nothing here'}</Empty>}
                </div>
              </Panel>
            ))}
          </div>
        </LayoutGroup>
      ) : (
        <Panel className="!p-2">
          {shown.length === 0 ? <Empty>Nothing matches</Empty> : (
            <table className="w-full text-left text-[13.5px]">
              <thead className="text-[12px] text-ink-3">
                <tr><th className="px-3 py-2 font-medium">Kind</th><th className="px-3 py-2 font-medium">Item</th><th className="px-3 py-2 font-medium">Stage</th><th className="px-3 py-2 text-right font-medium">Waiting</th></tr>
              </thead>
              <tbody>
                {[...columns.new, ...columns.in_review, ...columns.resolved].map((i) => (
                  <tr key={i.key} onClick={() => open(i)} className="cursor-pointer border-t hover:bg-[var(--card)]" style={{ borderColor: 'var(--line)' }}>
                    <td className="px-3 py-2.5"><Tag hue={TYPE_META[i.type].hue}>{TYPE_META[i.type].label}</Tag></td>
                    <td className="px-3 py-2.5">
                      <button className="text-left font-semibold" onClick={(e) => { e.stopPropagation(); open(i); }}>{describe(i).title}</button>
                      <div className="line-clamp-1 text-[12.5px] text-ink-3">{describe(i).subtitle}</div>
                    </td>
                    <td className="px-3 py-2.5 whitespace-nowrap">{i.stage === 'resolved' ? resolutionLabel(i) : <span className="inline-flex items-center gap-1.5">{STAGES.find((s) => s.id === i.stage)!.label} <Priority level={priority(i)} /></span>}</td>
                    <td className="px-3 py-2.5 text-right whitespace-nowrap text-ink-3">{i.stage === 'resolved' ? '—' : age(i.createdAtMs)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Panel>
      )}
    </>
  );
}
