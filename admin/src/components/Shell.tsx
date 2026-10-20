import { useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import {
  BarChart3, Bell, CalendarClock, CarFront, Check, Columns3, LayoutGrid, Moon, RotateCw, Settings, ShieldCheck, Sun, Undo2, Users, X,
} from 'lucide-react';
import { useSettings } from '../lib/settings';
import { useIsland } from '../lib/island';
import { useData } from '../lib/data';
import { spring } from '../lib/motion';
import { Avatar, CountUp } from './ui';
import { Rings } from './charts';

export type Page = 'overview' | 'queue' | 'licences' | 'bookings' | 'instructors' | 'insights' | 'settings';

export const NAV: { id: Page; label: string; icon: typeof LayoutGrid }[] = [
  { id: 'overview', label: 'Overview', icon: LayoutGrid },
  { id: 'queue', label: 'Queue', icon: Columns3 },
  { id: 'licences', label: 'Licences', icon: ShieldCheck },
  { id: 'bookings', label: 'Bookings & disputes', icon: CalendarClock },
  { id: 'instructors', label: 'Instructors', icon: Users },
  { id: 'insights', label: 'Insights', icon: BarChart3 },
  { id: 'settings', label: 'Settings', icon: Settings },
];

/** The wallpaper; a change crossfades (two layers for a moment). */
export function Wallpaper() {
  const { wallpaper, reduced } = useSettings();
  return (
    <div aria-hidden className="fixed inset-0 -z-10">
      <AnimatePresence initial={false}>
        <motion.div key={wallpaper} className="absolute inset-0" style={{ background: wallpaper }}
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: reduced ? 0 : 0.6 }} />
      </AnimatePresence>
    </div>
  );
}

/** The floating glass rail: logo tile, pages, the admin at the bottom. */
export function Rail({ page, onPage, email }: { page: Page; onPage: (p: Page) => void; email: string }) {
  return (
    <nav aria-label="Pages" className="glass fixed top-4 bottom-4 left-4 z-30 flex w-[68px] flex-col items-center gap-2 !rounded-[34px] py-4">
      <div className="mb-2 grid h-11 w-11 place-items-center rounded-[14px] text-white" style={{ background: 'var(--accent)', boxShadow: '0 6px 18px -4px var(--accent-glow), inset 0 1px 0 rgb(255 255 255 / 0.3)' }}>
        <CarFront size={22} aria-hidden />
        <span className="sr-only">DriveUSA Admin</span>
      </div>
      {NAV.map(({ id, label, icon: Icon }) => (
        <button key={id} onClick={() => onPage(id)} aria-label={label} title={label} aria-current={page === id ? 'page' : undefined}
          className={`rail-item relative grid h-11 w-11 place-items-center rounded-full ${page === id ? 'text-ink' : 'text-ink-3 hover:text-ink'}`}>
          {page === id && (
            <motion.span layoutId="rail-selected" transition={spring} className="absolute inset-0 rounded-full"
              style={{ background: 'var(--card-hover)', boxShadow: 'inset 0 0 0 1px var(--edge), 0 4px 12px rgb(0 0 0 / 0.25)' }} />
          )}
          <Icon size={19} className="relative" aria-hidden />
        </button>
      ))}
      <div className="mt-auto" title={email}><Avatar name={email.replace(/@.*/, '').replace(/[-.]/g, ' ')} size={34} /></div>
    </nav>
  );
}

/**
 * The island, top centre: an opaque black pill (as in the reference) with
 * the live count; it springs open into a card with today's progress, and
 * becomes the toast after an action («Review hidden · Undo»).
 */
export function Island() {
  const { toast, dismiss } = useIsland();
  const { items, loading } = useData();
  const [open, setOpen] = useState(false);
  const waiting = items.filter((i) => i.stage !== 'resolved');
  const urgent = waiting.filter((i) => i.urgent).length;
  const today = new Date().setHours(0, 0, 0, 0);
  const clearedToday = items.filter((i) => i.stage === 'resolved' && (i.resolvedAtMs ?? 0) >= today).length;
  const mode = toast ? 'toast' : open ? 'open' : 'pill';
  const width = mode === 'toast' ? 420 : mode === 'open' ? 380 : 210;

  return (
    <div className="pointer-events-none fixed top-4 left-1/2 z-50 -translate-x-1/2" aria-live="polite">
      <motion.div layout transition={spring} onClick={() => !toast && setOpen((o) => !o)}
        className="pointer-events-auto cursor-pointer overflow-hidden text-white"
        style={{ width, borderRadius: mode === 'open' ? 28 : 22, background: '#050505', boxShadow: '0 12px 30px -10px rgb(0 0 0 / 0.6), inset 0 0 0 1px rgb(255 255 255 / 0.08)' }}>
        <AnimatePresence mode="popLayout" initial={false}>
          {mode === 'toast' && toast && (
            <motion.div key={`t-${toast.id}`} className="flex h-11 items-center gap-3 pr-2 pl-2" initial={{ opacity: 0, filter: 'blur(6px)' }} animate={{ opacity: 1, filter: 'blur(0px)' }} exit={{ opacity: 0, filter: 'blur(6px)' }}>
              <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full" style={{ background: toast.tone === 'error' ? '#dc2626' : toast.tone === 'done' ? '#16a34a' : 'var(--accent)' }}>
                {toast.tone === 'error' ? <X size={15} /> : <Check size={15} />}
              </span>
              <span className="min-w-0 flex-1 truncate text-[13.5px] font-medium">{toast.text}</span>
              {toast.undo ? (
                <button onClick={(e) => { e.stopPropagation(); const u = toast.undo!; dismiss(); void u(); }}
                  className="inline-flex h-8 items-center gap-1.5 rounded-full px-3 text-[13px] font-semibold" style={{ background: 'rgb(255 255 255 / 0.12)' }}>
                  <Undo2 size={14} /> Undo
                </button>
              ) : (
                <button onClick={(e) => { e.stopPropagation(); dismiss(); }} aria-label="Close" className="grid h-8 w-8 place-items-center rounded-full" style={{ background: 'rgb(255 255 255 / 0.1)' }}><X size={14} /></button>
              )}
            </motion.div>
          )}
          {mode === 'pill' && (
            <motion.div key="pill" className="flex h-11 items-center gap-2.5 pr-4 pl-3" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
              <PillRing done={clearedToday} total={clearedToday + waiting.length} spinning={loading} />
              <span className="text-[13px] font-medium text-white/85">Queue</span>
              <span className="ml-auto text-[14px] font-semibold tabular-nums" style={{ color: urgent ? '#fca5a5' : '#fcd34d' }}>
                <CountUp value={waiting.length} /> waiting
              </span>
            </motion.div>
          )}
          {mode === 'open' && (
            <motion.div key="open" className="flex items-center gap-5 p-5" initial={{ opacity: 0, filter: 'blur(6px)' }} animate={{ opacity: 1, filter: 'blur(0px)' }} exit={{ opacity: 0 }}>
              <Rings size={86} rings={[{ label: 'Cleared today', value: clearedToday, total: clearedToday + waiting.length, color: '#4ade80' }]} />
              <div className="min-w-0">
                <div className="text-[12px] text-white/60">Today</div>
                <div className="text-[30px] leading-9 font-semibold tabular-nums text-[#fcd34d]">{clearedToday}<span className="text-[16px] text-white/50"> cleared</span></div>
                <div className="text-[13px] text-white/70">{waiting.length} waiting · {urgent} urgent</div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  );
}

function PillRing({ done, total, spinning }: { done: number; total: number; spinning: boolean }) {
  const r = 8;
  const c = 2 * Math.PI * r;
  return (
    <motion.svg width="22" height="22" viewBox="0 0 22 22" aria-hidden animate={spinning ? { rotate: 360 } : { rotate: 0 }}
      transition={spinning ? { repeat: Infinity, duration: 1, ease: 'linear' } : { duration: 0 }}>
      <circle cx="11" cy="11" r={r} fill="none" stroke="rgb(255 255 255 / 0.18)" strokeWidth="3" />
      <circle cx="11" cy="11" r={r} fill="none" stroke="#f59e0b" strokeWidth="3" strokeLinecap="round"
        strokeDasharray={`${c * (total ? Math.max(0.08, done / total) : 0.08)} ${c}`} transform="rotate(-90 11 11)" />
    </motion.svg>
  );
}

/** Top right: refresh, light/dark, the bell (urgent items). */
export function ActionCluster({ onBell }: { onBell: () => void }) {
  const { dark, set } = useSettings();
  const { refresh, loading, items } = useData();
  const urgent = items.filter((i) => i.stage !== 'resolved' && i.urgent).length;
  const btn = 'grid h-10 w-10 place-items-center rounded-full text-ink-2 hover:text-ink hover:bg-[var(--card-hover)]';
  return (
    <div className="glass fixed top-4 right-4 z-30 flex items-center gap-1 !rounded-full p-1.5">
      <button className={btn} onClick={() => void refresh()} aria-label="Refresh" title="Refresh">
        <motion.span animate={loading ? { rotate: 360 } : { rotate: 0 }} transition={loading ? { repeat: Infinity, duration: 0.9, ease: 'linear' } : { duration: 0 }} className="grid">
          <RotateCw size={18} />
        </motion.span>
      </button>
      <button className={btn} onClick={() => set({ theme: dark ? 'light' : 'dark' })} aria-label={dark ? 'Light theme' : 'Dark theme'} title="Theme">
        {dark ? <Sun size={18} /> : <Moon size={18} />}
      </button>
      <button className={`${btn} relative`} onClick={onBell} aria-label={`Urgent items: ${urgent}`} title="Urgent">
        <Bell size={18} />
        {urgent > 0 && <span className="absolute top-2 right-2.5 h-2.5 w-2.5 rounded-full bg-[#ef4444]" style={{ boxShadow: '0 0 0 2px var(--panel-solid)' }} />}
      </button>
    </div>
  );
}
