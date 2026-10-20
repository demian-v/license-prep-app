import { useMemo, useState } from 'react';
import { Search, Star } from 'lucide-react';
import { useData } from '../lib/data';
import type { InstructorRow } from '../lib/api';
import { Avatar, Empty, PageHeader, Panel, Rise, Segmented, StatTile } from '../components/ui';

const STAGE = ['Not checked', 'ID checked', 'Bookable'];
const pill = (text: string, hue: number | null) => (
  <span className="tag" style={{ ['--h' as string]: hue ?? 220, ...(hue === null ? { background: 'var(--field)', color: 'var(--ink-3)' } : {}) }}>{text}</span>
);
const check = (v: string) => pill(v, v === 'passed' ? 142 : v === 'pending' ? 38 : v === 'rejected' || v === 'failed' || v === 'expired' ? 0 : null);

export default function Instructors() {
  const { instructors, setInstructorStatus } = useData();
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<'all' | 'active' | 'suspended'>('all');
  const rows = useMemo(() => instructors
    .filter((r) => status === 'all' || (status === 'suspended' ? r.status === 'suspended' : r.status !== 'suspended'))
    .filter((r) => `${r.name} ${r.city} ${r.state}`.toLowerCase().includes(query.trim().toLowerCase()))
    .sort((a, b) => b.cancellations30d - a.cancellations30d || a.name.localeCompare(b.name)), [instructors, query, status]);

  return (
    <>
      <PageHeader title="Instructors" subtitle="Suspending unlists a profile: no search, no new bookings, no payouts set-up. Lessons already booked stay.">
        <Segmented id="instr-status" label="Status" value={status} onChange={setStatus}
          options={[{ value: 'all', label: 'All' }, { value: 'active', label: 'Active' }, { value: 'suspended', label: 'Suspended' }]} />
      </PageHeader>
      <div className="mb-4 flex flex-wrap gap-3">
        <StatTile label="Listed" value={instructors.filter((r) => r.listed).length} />
        <StatTile label="Bookable" value={instructors.filter((r) => r.stage === 2 && r.listed).length} />
        <StatTile label="Suspended" value={instructors.filter((r) => r.status === 'suspended').length} />
        <StatTile label="3+ school cancellations" value={instructors.filter((r) => r.cancellations30d >= 3).length} tone="urgent" />
      </div>
      <Rise className="mb-4">
        <label className="relative block max-w-[360px]">
          <Search size={15} className="absolute top-1/2 left-3 -translate-y-1/2 text-ink-3" aria-hidden />
          <input className="field glass w-full !pl-9" placeholder="Name, city or state" value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Search instructors" />
        </label>
      </Rise>
      <Panel className="!p-2">
        {rows.length === 0 ? <Empty>No instructor matches</Empty> : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[860px] text-left text-[13.5px]">
              <thead className="text-[12px] text-ink-3">
                <tr>{['Instructor', 'Stage', 'Licence', 'ID', 'Payouts', 'Rating', 'Cancelled · 30 d', ''].map((h) => <th key={h} className="px-3 py-2 font-medium">{h}</th>)}</tr>
              </thead>
              <tbody>
                {rows.map((r: InstructorRow) => (
                  <tr key={r.uid} className="border-t" style={{ borderColor: 'var(--line)', opacity: r.status === 'active' ? 1 : 0.72 }}>
                    <td className="px-3 py-2.5">
                      <div className="flex items-center gap-2.5">
                        <Avatar name={r.name} size={30} />
                        <div>
                          <div className="font-semibold">{r.name}</div>
                          <div className="text-[12px] text-ink-3">{r.kind === 'school' ? 'School' : 'Private'} · {r.city}, {r.state} · {r.status}{r.listed ? '' : ' · unlisted'}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-3 py-2.5 whitespace-nowrap">{STAGE[r.stage] ?? r.stage}</td>
                    <td className="px-3 py-2.5">{check(r.licenseCheck)}</td>
                    <td className="px-3 py-2.5">{check(r.idCheck)}</td>
                    <td className="px-3 py-2.5">{r.kind === 'school' ? pill(r.payoutsEnabled ? 'on' : 'off', r.payoutsEnabled ? 142 : null) : <span className="text-ink-3">—</span>}</td>
                    <td className="px-3 py-2.5 whitespace-nowrap">{r.ratingCount ? <span className="inline-flex items-center gap-1"><Star size={13} fill="#fbbf24" stroke="#fbbf24" aria-hidden /> {r.ratingAvg} <span className="text-ink-3">({r.ratingCount})</span></span> : <span className="text-ink-3">—</span>}</td>
                    <td className={`px-3 py-2.5 tabular-nums ${r.cancellations30d >= 3 ? 'font-semibold text-[var(--bad)]' : ''}`}>{r.cancellations30d}</td>
                    <td className="px-3 py-2.5 text-right">
                      {r.status === 'suspended'
                        ? <button className="btn small" onClick={() => void setInstructorStatus(r, 'active')}>Lift suspension</button>
                        : <button className="btn small" onClick={() => void setInstructorStatus(r, 'suspended')}>Suspend</button>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
    </>
  );
}
