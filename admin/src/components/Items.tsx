import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import { motion } from 'motion/react';
import { Calendar, Clock, MessageSquare, Star } from 'lucide-react';
import type { QueueItem } from '../lib/api';
import { actionsFor, type Action } from '../lib/actions';
import { describe, priority, reasonLabel, resolutionLabel, TYPE_META } from '../lib/queue';
import { age, date, money } from '../lib/format';
import { useData } from '../lib/data';
import { useSettings } from '../lib/settings';
import { spring } from '../lib/motion';
import { Avatar, Modal, Priority, Sheet, Tag } from './ui';

// ── Opening an item ──────────────────────────────────────────────────────────

const OpenContext = createContext<(item: QueueItem) => void>(() => undefined);
export const useOpenItem = () => useContext(OpenContext);

/** Holds the open item's sheet; any page opens one with useOpenItem(). */
export function ItemSheetProvider({ children }: { children: ReactNode }) {
  const { items } = useData();
  const [key, setKey] = useState<string | null>(null);
  const item = useMemo(() => items.find((i) => i.key === key) ?? null, [items, key]);
  const open = useCallback((i: QueueItem) => setKey(i.key), []);
  const close = useCallback(() => setKey(null), []);
  return (
    <OpenContext.Provider value={open}>
      {children}
      <Sheet open={item !== null} onClose={close} label={item ? describe(item).title : ''}>
        {item && <ItemDetail item={item} onDone={close} />}
      </Sheet>
    </OpenContext.Provider>
  );
}

// ── The board's card ─────────────────────────────────────────────────────────

/**
 * One item on the board. `layoutId` lets an action slide it into its new
 * column (the reference's card moving to Done); hover lifts it a little.
 */
export function QueueCard({ item }: { item: QueueItem }) {
  const open = useOpenItem();
  const { reduced } = useSettings();
  const meta = TYPE_META[item.type];
  const d = describe(item);
  const done = item.stage === 'resolved';
  return (
    <motion.button layout={!reduced} layoutId={reduced ? undefined : item.key} transition={spring}
      initial={reduced ? false : { opacity: 0, scale: 0.96 }} animate={{ opacity: 1, scale: 1 }}
      whileHover={reduced ? undefined : { y: -2 }} onClick={() => open(item)}
      className="card interactive block w-full p-3.5 text-left" aria-label={`${meta.label}: ${d.title}`}>
      <div className="flex flex-wrap items-center gap-1.5">
        <Tag hue={meta.hue}>{meta.label}</Tag>
        <Priority level={priority(item)} />
      </div>
      <div className={`mt-2 text-[14px] font-semibold leading-5 ${done ? 'text-ink-2' : 'text-ink'}`}>{d.title}</div>
      <div className="mt-0.5 line-clamp-2 text-[12.5px] leading-[18px] text-ink-3">{d.subtitle}</div>
      <div className="mt-3 flex items-center gap-3 text-[12px] text-ink-3">
        {done ? (
          <span className="inline-flex items-center gap-1.5 font-medium" style={{ color: 'var(--accent-ink)' }}>
            <CheckDot /> {resolutionLabel(item)}
          </span>
        ) : (
          <span className="inline-flex items-center gap-1"><Clock size={13} aria-hidden /> {age(item.createdAtMs)}</span>
        )}
        {item.type === 'no_show' && item.startAtMs && <span className="inline-flex items-center gap-1"><Calendar size={13} aria-hidden /> {date(item.startAtMs)}</span>}
        {d.person && <span className="ml-auto"><Avatar name={d.person} size={22} /></span>}
      </div>
    </motion.button>
  );
}

function CheckDot() {
  const { reduced } = useSettings();
  return (
    <svg width="15" height="15" viewBox="0 0 16 16" aria-hidden>
      <circle cx="8" cy="8" r="8" fill="var(--accent)" />
      <motion.path d="M4.5 8.2 7 10.6l4.6-5" fill="none" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
        initial={reduced ? false : { pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.35, delay: 0.15 }} />
    </svg>
  );
}

// ── The sheet ────────────────────────────────────────────────────────────────

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 border-b py-2.5 text-[13.5px]" style={{ borderColor: 'var(--line)' }}>
      <span className="shrink-0 text-ink-3">{label}</span>
      <span className="text-right font-medium text-ink">{children}</span>
    </div>
  );
}

function Stars({ n }: { n: number }) {
  return (
    <span className="inline-flex gap-0.5" aria-label={`${n} of 5 stars`}>
      {[1, 2, 3, 4, 5].map((i) => <Star key={i} size={14} aria-hidden fill={i <= n ? '#fbbf24' : 'none'} stroke={i <= n ? '#fbbf24' : 'var(--ink-3)'} />)}
    </span>
  );
}

function Quote({ label, children, muted }: { label: string; children: ReactNode; muted?: boolean }) {
  return (
    <div className="card p-3.5">
      <div className="mb-1.5 text-[11.5px] font-semibold tracking-wide text-ink-3 uppercase">{label}</div>
      <div className={`text-[14px] leading-5 ${muted ? 'text-ink-3' : 'text-ink'}`}>{children}</div>
    </div>
  );
}

function ItemDetail({ item, onDone }: { item: QueueItem; onDone: () => void }) {
  const { perform } = useData();
  const meta = TYPE_META[item.type];
  const d = describe(item);
  const actions = actionsFor(item);
  const [confirm, setConfirm] = useState<Action | null>(null);
  const [busy, setBusy] = useState(false);
  const [expiry, setExpiry] = useState(() => new Date(Date.now() + 365 * 864e5).toISOString().slice(0, 10));
  const expiresAtMs = Date.parse(`${expiry}T23:59:59`);
  const expiryOk = Number.isFinite(expiresAtMs) && expiresAtMs > Date.now();

  async function go(a: Action) {
    // A resolving action closes the sheet first, so the card is seen sliding into Resolved.
    const closes = a.optimistic.stage === 'resolved';
    setBusy(true);
    setConfirm(null);
    if (closes) onDone();
    await perform(item, a, a.needsDate ? { expiresAtMs } : {});
    setBusy(false);
  }

  return (
    <>
      <div className="flex-1 overflow-y-auto p-6 pt-6">
        <div className="flex flex-wrap items-center gap-1.5 pr-12">
          <Tag hue={meta.hue}>{meta.label}</Tag>
          <Priority level={priority(item)} />
          {item.stage === 'resolved' && <span className="text-[12px] font-medium text-ink-3">· {resolutionLabel(item)} {date(item.resolvedAtMs, true)}</span>}
        </div>
        <h2 className="mt-3 text-[21px] leading-7 font-semibold">{d.title}</h2>
        <p className="mt-1 text-[13px] text-ink-3">{item.type === 'licence' ? 'Updated' : 'Reported'} {age(item.createdAtMs)} ago · {date(item.createdAtMs, true)}</p>

        <div className="mt-5 space-y-3">
          {item.type === 'review' && (
            <>
              <Quote label="As reported"><Stars n={item.reported?.rating ?? 0} /><div className="mt-1">“{item.reported?.comment}”</div></Quote>
              {item.current ? (
                <Quote label={`Now${item.current.hidden ? ' · hidden' : ''}${item.current.comment !== item.reported?.comment ? ' · edited since' : ''}`} muted={item.current.hidden}>
                  <Stars n={item.current.rating ?? 0} /><div className="mt-1">“{item.current.comment}”</div>
                  <div className="mt-1.5 text-[12px] text-ink-3">by {item.current.author}</div>
                </Quote>
              ) : <Quote label="Now" muted>The review was deleted by its author.</Quote>}
            </>
          )}
          {item.type === 'message' && (
            <Quote label={`Message · from the ${item.sender ?? 'unknown'}`} muted={!item.current}>
              {item.current ? <><MessageSquare size={14} className="mr-1.5 inline" aria-hidden />“{item.current.text}”{item.current.masked && <span className="text-ink-3"> (masked)</span>}</> : 'The message no longer exists.'}
            </Quote>
          )}
          {item.message && <Quote label="Reporter's note">{item.message}</Quote>}
        </div>

        <div className="mt-4">
          {item.reason && <Field label="Reason">{reasonLabel(item.reason)}</Field>}
          {item.instructor && <Field label="Instructor">{item.instructor.name} · {item.instructor.state} · {item.instructor.status}</Field>}
          {item.type === 'content' && Object.entries(item.entity ?? {}).map(([k, v]) => <Field key={k} label={k}>{String(v)}</Field>)}
          {item.language && <Field label="App language">{item.language.toUpperCase()}</Field>}
          {item.type === 'licence' && (
            <>
              <Field label="Kind">{item.kind === 'school' ? 'Driving school' : 'Private instructor'}</Field>
              {item.schoolName && <Field label="School">{item.schoolName}</Field>}
              <Field label="School licence">{item.schoolLicenseNumber ?? '—'}</Field>
              {item.kind !== 'school' && <Field label="Instructor licence">{item.instructorLicenseNumber ?? '—'}</Field>}
              <Field label="State">{item.licenseState}</Field>
              {item.licenseExpiresAtMs && <Field label="Expires">{date(item.licenseExpiresAtMs)}</Field>}
            </>
          )}
          {(item.type === 'no_show' || item.type === 'card_dispute') && (
            <>
              <Field label="School">{item.instructorName}</Field>
              <Field label="Student">{item.studentName}</Field>
              <Field label="Lesson">{item.localDate} {item.localTime} · {item.durationMinutes} min</Field>
              <Field label="Paid">{money(item.totalCents ?? 0)} (lesson {money(item.lessonCents ?? 0)} + fee {money(item.platformFeeCents ?? 0)})</Field>
              <Field label="Payment">{item.paymentProvider === 'stripe' ? 'Stripe' : 'Emulator (no money)'}</Field>
              {item.noShowReason && <Field label="Student says">{reasonLabel(item.noShowReason)}</Field>}
              {item.disputeStatus && <Field label="Card dispute">{item.disputeStatus} · {reasonLabel(item.disputeReason)} · {money(item.disputeAmountCents ?? 0)}</Field>}
            </>
          )}
        </div>
        {item.type === 'card_dispute' && !item.actionable && item.stage !== 'resolved' && (
          <p className="mt-4 text-[13px] leading-5 text-ink-3">Stripe runs an open dispute; the school's payout is held until it closes. Won → paid out by the hourly job; lost → it comes back here.</p>
        )}
      </div>

      {actions.length > 0 && (
        <div className="border-t p-4" style={{ borderColor: 'var(--line)' }}>
          {actions.some((a) => a.needsDate) && (
            <label className="mb-3 flex items-center justify-between gap-3 text-[13px] text-ink-2">
              Licence valid until
              <input type="date" className="field" value={expiry} min={new Date(Date.now() + 864e5).toISOString().slice(0, 10)} onChange={(e) => setExpiry(e.target.value)} />
            </label>
          )}
          <div className="flex flex-wrap gap-2">
            {actions.map((a) => (
              <button key={a.id} disabled={busy || (a.needsDate && !expiryOk)} onClick={() => (a.confirm ? setConfirm(a) : void go(a))}
                className={`btn ${a.tone === 'primary' ? 'primary' : a.tone === 'danger' ? 'danger' : ''}`}>
                {a.label}
              </button>
            ))}
          </div>
        </div>
      )}

      <Modal open={confirm !== null} onClose={() => setConfirm(null)} title={confirm?.confirm?.title ?? ''}>
        <p className="mt-2 text-[14px] leading-5 text-ink-2">{confirm?.confirm?.body}</p>
        <p className="mt-3 text-[13px] text-ink-3">{d.title} · lesson {money(item.lessonCents ?? 0)} · paid {money(item.totalCents ?? 0)}</p>
        <div className="mt-5 flex justify-end gap-2">
          <button className="btn" onClick={() => setConfirm(null)}>Cancel</button>
          <button className="btn primary" disabled={busy} onClick={() => confirm && void go(confirm)}>{confirm?.confirm?.cta}</button>
        </div>
      </Modal>
    </>
  );
}
