import { useEffect, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, animate, motion } from 'motion/react';
import { X } from 'lucide-react';
import { useSettings } from '../lib/settings';
import { riseVariants, spring } from '../lib/motion';
import { initials } from '../lib/format';

/** A frosted panel; rises into place with the page (staggered by the page). */
export function Panel({ children, className = '', title, subtitle, action, id }: {
  children?: ReactNode; className?: string; title?: ReactNode; subtitle?: ReactNode; action?: ReactNode; id?: string;
}) {
  const { reduced } = useSettings();
  return (
    <motion.section variants={riseVariants(reduced)} className={`glass p-5 ${className}`} aria-labelledby={id}>
      {(title || action) && (
        <header className="mb-4 flex items-start justify-between gap-3">
          <div>
            {title && <h2 id={id} className="text-[16px] font-semibold leading-6 text-ink">{title}</h2>}
            {subtitle && <p className="text-[13px] leading-5 text-ink-3">{subtitle}</p>}
          </div>
          {action}
        </header>
      )}
      {children}
    </motion.section>
  );
}

/** Rises with the page, without a panel of its own. */
export function Rise({ children, className = '' }: { children: ReactNode; className?: string }) {
  const { reduced } = useSettings();
  return <motion.div variants={riseVariants(reduced)} className={className}>{children}</motion.div>;
}

/** Numbers roll to their new value (1.0 h → 1.1 h); reduced motion just changes them. */
export function CountUp({ value, format = (n) => String(Math.round(n)) }: { value: number; format?: (n: number) => string }) {
  const { reduced } = useSettings();
  const [shown, setShown] = useState(reduced ? value : 0);
  const from = useRef(reduced ? value : 0);
  useEffect(() => {
    if (reduced) {
      setShown(value);
      from.current = value;
      return;
    }
    const controls = animate(from.current, value, {
      duration: 0.9, ease: [0.16, 1, 0.3, 1],
      onUpdate: (v) => setShown(v),
      onComplete: () => { from.current = value; },
    });
    return () => { from.current = value; controls.stop(); };
  }, [value, reduced]);
  return <span className="tabular-nums">{format(shown)}</span>;
}

export function StatTile({ label, value, format, suffix, tone }: {
  label: string; value: number; format?: (n: number) => string; suffix?: string; tone?: 'urgent';
}) {
  return (
    <Rise className="card min-w-[132px] flex-1 px-4 py-3">
      <div className="text-[12px] font-medium leading-4 text-ink-3">{label}</div>
      <div className={`mt-1 text-[24px] font-semibold leading-8 ${tone === 'urgent' && value > 0 ? 'text-[var(--bad)]' : 'text-ink'}`}>
        <CountUp value={value} format={format} />
        {suffix && <span className="ml-0.5 text-[14px] font-medium text-ink-3">{suffix}</span>}
      </div>
    </Rise>
  );
}

export function Tag({ hue, children }: { hue: number; children: ReactNode }) {
  return <span className="tag" style={{ ['--h' as string]: hue }}><span className="dot" />{children}</span>;
}

export function Priority({ level }: { level: 'urgent' | 'high' | null }) {
  if (!level) return null;
  return <span className="tag" style={{ ['--h' as string]: level === 'urgent' ? 0 : 28 }}>{level === 'urgent' ? 'Urgent' : 'High'}</span>;
}

export function Avatar({ name, size = 26 }: { name: string; size?: number }) {
  const hue = [...name].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 360, 7);
  return (
    <span aria-hidden className="inline-grid shrink-0 place-items-center rounded-full font-semibold text-white"
      style={{ width: size, height: size, fontSize: size * 0.38, background: `linear-gradient(140deg, hsl(${hue} 55% 48%), hsl(${(hue + 40) % 360} 55% 36%))`, boxShadow: 'inset 0 0 0 1px rgb(255 255 255 / 0.18)' }}>
      {initials(name)}
    </span>
  );
}

/** A segmented control; the selected pill slides between options. */
export function Segmented<T extends string>({ options, value, onChange, id, label }: {
  options: { value: T; label: ReactNode }[]; value: T; onChange: (v: T) => void; id: string; label: string;
}) {
  return (
    <div role="radiogroup" aria-label={label} className="seg inline-flex rounded-full p-1" style={{ background: 'var(--field)', boxShadow: 'inset 0 0 0 1px var(--line)' }}>
      {options.map((o) => (
        <button key={o.value} role="radio" aria-checked={o.value === value} onClick={() => onChange(o.value)}
          className={`relative h-8 rounded-full px-3.5 text-[13px] font-semibold ${o.value === value ? 'text-ink' : 'text-ink-3 hover:text-ink-2'}`}>
          {o.value === value && (
            <motion.span layoutId={`seg-${id}`} transition={spring} className="absolute inset-0 rounded-full"
              style={{ background: 'var(--card-hover)', boxShadow: 'inset 0 0 0 1px var(--edge), 0 2px 8px rgb(0 0 0 / 0.18)' }} />
          )}
          <span className="relative inline-flex items-center gap-1.5">{o.label}</span>
        </button>
      ))}
    </div>
  );
}

export function Toggle({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label: string }) {
  return (
    <button role="switch" aria-checked={on} aria-label={label} onClick={() => onChange(!on)}
      className="relative h-[30px] w-[52px] shrink-0 rounded-full transition-colors"
      style={{ background: on ? 'var(--accent)' : 'var(--field)', boxShadow: 'inset 0 0 0 1px var(--line)' }}>
      <motion.span transition={spring} animate={{ x: on ? 24 : 2 }} className="absolute top-[2px] left-0 h-[26px] w-[26px] rounded-full bg-white shadow" />
    </button>
  );
}

/** A centred glass dialog (confirmations for money actions), on top of everything (a portal: the sheet is transformed). */
export function Modal({ open, onClose, title, children, labelledBy = 'modal-title' }: {
  open: boolean; onClose: () => void; title: string; children: ReactNode; labelledBy?: string;
}) {
  useEscape(open, onClose);
  return createPortal(
    <AnimatePresence>
      {open && (
        <motion.div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose}>
          <motion.div role="dialog" aria-modal="true" aria-labelledby={labelledBy} className="glass w-full max-w-[440px] p-6"
            initial={{ scale: 0.94, y: 12, opacity: 0 }} animate={{ scale: 1, y: 0, opacity: 1 }} exit={{ scale: 0.96, opacity: 0 }} transition={spring}
            onClick={(e) => e.stopPropagation()}>
            <h2 id={labelledBy} className="text-[18px] font-semibold">{title}</h2>
            {children}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body,
  );
}

/** A glass sheet from the right (an item's details and actions). */
export function Sheet({ open, onClose, children, label }: { open: boolean; onClose: () => void; children: ReactNode; label: string }) {
  useEscape(open, onClose);
  return (
    <AnimatePresence>
      {open && (
        <motion.div className="fixed inset-0 z-40" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
          <div className="absolute inset-0 bg-black/30" onClick={onClose} />
          <motion.aside role="dialog" aria-modal="true" aria-label={label}
            className="glass absolute top-3 right-3 bottom-3 flex w-[min(520px,calc(100vw-24px))] flex-col overflow-hidden"
            initial={{ x: 60, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: 40, opacity: 0 }} transition={spring}>
            <button onClick={onClose} aria-label="Close" className="btn absolute top-4 right-4 z-10 !h-9 !w-9 !p-0"><X size={17} /></button>
            {children}
          </motion.aside>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function useEscape(open: boolean, onClose: () => void) {
  useEffect(() => {
    if (!open) return;
    const f = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', f);
    return () => window.removeEventListener('keydown', f);
  }, [open, onClose]);
}

export function PageHeader({ title, subtitle, children }: { title: string; subtitle?: ReactNode; children?: ReactNode }) {
  return (
    <Rise className="mb-5 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="text-[30px] font-bold leading-9 tracking-[-0.02em]">{title}</h1>
        {subtitle && <p className="mt-0.5 text-[14px] leading-5 text-ink-3">{subtitle}</p>}
      </div>
      {children && <div className="flex flex-wrap items-center gap-2">{children}</div>}
    </Rise>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <div className="grid place-items-center rounded-2xl px-4 py-10 text-center text-[13.5px] text-ink-3" style={{ boxShadow: 'inset 0 0 0 1px var(--line)' }}>{children}</div>;
}
