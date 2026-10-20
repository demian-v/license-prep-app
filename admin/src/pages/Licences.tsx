import { Fingerprint, ImageIcon } from 'lucide-react';
import { useData } from '../lib/data';
import { sortItems, resolutionLabel } from '../lib/queue';
import { age, date } from '../lib/format';
import { Empty, PageHeader, Panel, StatTile } from '../components/ui';
import { useOpenItem } from '../components/Items';

/**
 * Licence review (plan v2 §6.4): the admin checks the number against the
 * state's online lookup and approves it with an expiry date. Licence photos,
 * ID results and photo moderation arrive with P10b (Didit, Vision).
 */
export default function Licences() {
  const { items } = useData();
  const open = useOpenItem();
  const licences = sortItems(items.filter((i) => i.type === 'licence'));
  const pending = licences.filter((i) => i.stage !== 'resolved');
  const done = licences.filter((i) => i.stage === 'resolved');

  return (
    <>
      <PageHeader title="Licences" subtitle="Compare each number with the state's lookup, then approve it until its expiry date" />
      <div className="mb-4 flex flex-wrap gap-3">
        <StatTile label="To review" value={pending.length} />
        <StatTile label="Schools" value={pending.filter((i) => i.kind === 'school').length} />
        <StatTile label="Private instructors" value={pending.filter((i) => i.kind !== 'school').length} />
        <StatTile label="Reviewed · 30 days" value={done.length} />
      </div>
      <div className="grid gap-4 lg:grid-cols-[2fr_1fr]">
        <Panel title="Waiting for review" subtitle="Oldest first">
          {pending.length === 0 ? <Empty>No licence waiting</Empty> : (
            <div className="grid gap-2.5 sm:grid-cols-2">
              {pending.map((i) => (
                <button key={i.key} onClick={() => open(i)} className="card interactive p-4 text-left">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[14.5px] font-semibold">{i.name}</span>
                    <span className="text-[12px] text-ink-3">{age(i.createdAtMs)}</span>
                  </div>
                  <div className="mt-0.5 text-[12.5px] text-ink-3">{i.kind === 'school' ? 'Driving school' : `Private instructor${i.schoolName ? ` · ${i.schoolName}` : ''}`} · {i.licenseState}</div>
                  <div className="mt-3 grid gap-1 font-mono text-[13px]">
                    {i.schoolLicenseNumber && <span><span className="font-sans text-ink-3">School </span>{i.schoolLicenseNumber}</span>}
                    {i.instructorLicenseNumber && <span><span className="font-sans text-ink-3">Instructor </span>{i.instructorLicenseNumber}</span>}
                  </div>
                  {i.stage === 'in_review' && <div className="mt-2 text-[12px] font-semibold" style={{ color: 'var(--accent-ink)' }}>In review</div>}
                </button>
              ))}
            </div>
          )}
        </Panel>
        <div className="grid content-start gap-4">
          <Panel title="Reviewed" subtitle="Last 30 days">
            {done.length === 0 ? <Empty>None yet</Empty> : (
              <ul className="space-y-1">
                {done.map((i) => (
                  <li key={i.key}>
                    <button onClick={() => open(i)} className="flex w-full items-center justify-between gap-3 rounded-xl px-2 py-2 text-left hover:bg-[var(--card)]">
                      <span className="min-w-0 truncate text-[13.5px] font-medium">{i.name}</span>
                      <span className="shrink-0 text-[12px] text-ink-3">{resolutionLabel(i)}{i.licenseExpiresAtMs ? ` · until ${date(i.licenseExpiresAtMs)}` : ''}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </Panel>
          <Panel title="Identity checks" subtitle="Didit results arrive with P10b" className="opacity-70">
            <div className="flex items-center gap-3 text-[13px] text-ink-3"><Fingerprint size={20} aria-hidden /> ID + selfie results will be listed here.</div>
          </Panel>
          <Panel title="Photos" subtitle="SafeSearch moderation arrives with P10b" className="opacity-70">
            <div className="flex items-center gap-3 text-[13px] text-ink-3"><ImageIcon size={20} aria-hidden /> Licence photos and held profile photos will be shown here.</div>
          </Panel>
        </div>
      </div>
    </>
  );
}
