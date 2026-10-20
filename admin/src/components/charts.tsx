import { useEffect, useId, useRef, useState } from 'react';
import { motion } from 'motion/react';
import { useSettings } from '../lib/settings';

/**
 * Charts drawn in SVG and animated the way the reference does: rings and
 * the donut sweep in, bars grow from the baseline one after another, the
 * line draws left to right with its area fading in. Reduced motion draws
 * them at once.
 */

export interface Ring { label: string; value: number; total: number; color: string }

/** Concentric rings, outermost first (today's queue cleared). */
export function Rings({ rings, size = 150 }: { rings: Ring[]; size?: number }) {
  const { reduced } = useSettings();
  const stroke = 13;
  const gap = 4;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img"
      aria-label={rings.map((r) => `${r.label} ${r.value} of ${r.total}`).join(', ')}>
      {rings.map((r, i) => {
        const radius = size / 2 - stroke / 2 - i * (stroke + gap);
        const fraction = r.total > 0 ? Math.min(1, r.value / r.total) : 0;
        return (
          <g key={r.label} transform={`rotate(-90 ${size / 2} ${size / 2})`}>
            <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke={r.color} strokeOpacity={0.18} strokeWidth={stroke} />
            <motion.circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke={r.color} strokeWidth={stroke} strokeLinecap="round"
              style={{ filter: `drop-shadow(0 0 6px ${r.color}88)` }}
              initial={reduced ? false : { pathLength: 0 }} animate={{ pathLength: Math.max(fraction, 0.001), opacity: fraction > 0 ? 1 : 0 }}
              transition={{ duration: reduced ? 0 : 1.1, delay: reduced ? 0 : 0.15 + i * 0.12, ease: [0.16, 1, 0.3, 1] }} />
          </g>
        );
      })}
    </svg>
  );
}

export interface Slice { label: string; value: number; color: string }

/** A donut with the total in the centre. */
export function Donut({ slices, size = 150, centre, caption }: { slices: Slice[]; size?: number; centre: React.ReactNode; caption: string }) {
  const { reduced } = useSettings();
  const total = slices.reduce((a, s) => a + s.value, 0);
  const stroke = 16;
  const radius = size / 2 - stroke / 2 - 2;
  const gapFraction = slices.length > 1 ? 0.012 : 0;
  let offset = 0;
  return (
    <div className="relative" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img"
        aria-label={`${caption}: ${slices.map((s) => `${s.label} ${s.value}`).join(', ')}`}>
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--track)" strokeWidth={stroke} />
        {total > 0 && slices.map((s, i) => {
          const fraction = s.value / total;
          const start = offset;
          offset += fraction;
          return (
            <motion.circle key={s.label} cx={size / 2} cy={size / 2} r={radius} fill="none" stroke={s.color} strokeWidth={stroke}
              strokeLinecap="butt" transform={`rotate(${start * 360 - 90} ${size / 2} ${size / 2})`}
              initial={reduced ? false : { pathLength: 0 }} animate={{ pathLength: Math.max(0.0001, fraction - gapFraction) }}
              transition={{ duration: reduced ? 0 : 0.9, delay: reduced ? 0 : 0.1 + i * 0.08, ease: [0.16, 1, 0.3, 1] }} />
          );
        })}
      </svg>
      <div className="absolute inset-0 grid place-items-center text-center">
        <div>
          <div className="text-[24px] font-semibold leading-7">{centre}</div>
          <div className="text-[11.5px] text-ink-3">{caption}</div>
        </div>
      </div>
    </div>
  );
}

/**
 * Catmull-Rom through the points, as cubic Béziers: a smooth line that passes
 * through every value. Control points are kept between `top` and `bottom`, so
 * the curve never dips below zero between two points.
 */
function smooth(points: [number, number][], top: number, bottom: number): string {
  const clamp = (v: number) => Math.min(bottom, Math.max(top, v));
  if (points.length < 2) return points.length ? `M${points[0][0]},${points[0][1]}` : '';
  let d = `M${points[0][0]},${points[0][1]}`;
  for (let i = 0; i < points.length - 1; i++) {
    const [p0, p1, p2, p3] = [points[i - 1] ?? points[i], points[i], points[i + 1], points[i + 2] ?? points[i + 1]];
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, clamp(p1[1] + (p2[1] - p0[1]) / 6)];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, clamp(p2[1] - (p3[1] - p1[1]) / 6)];
    d += ` C${c1[0]},${c1[1]} ${c2[0]},${c2[1]} ${p2[0]},${p2[1]}`;
  }
  return d;
}

/** A smooth area line; `labels` under a few points. */
export function AreaChart({ values, labels, height = 190, caption }: { values: number[]; labels: string[]; height?: number; caption: string }) {
  const { reduced } = useSettings();
  const id = useId();
  // Drawn at the panel's real width, so the axis text stays 11 px at any size.
  const box = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(640);
  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => setWidth(Math.max(240, Math.round(e.contentRect.width))));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  const pad = { l: 30, r: 8, t: 12, b: 24 };
  const max = Math.max(4, ...values);
  const nice = Math.ceil(max / 4) * 4;
  const x = (i: number) => pad.l + (values.length > 1 ? (i / (values.length - 1)) * (width - pad.l - pad.r) : 0);
  const y = (v: number) => pad.t + (1 - v / nice) * (height - pad.t - pad.b);
  const pts = values.map((v, i) => [x(i), y(v)] as [number, number]);
  const line = smooth(pts, y(nice), y(0));
  const area = `${line} L${x(values.length - 1)},${y(0)} L${x(0)},${y(0)} Z`;
  const step = Math.max(1, Math.ceil(labels.length / 7));
  return (
    <div ref={box}>
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} className="block" role="img" aria-label={caption}>
      <defs>
        <linearGradient id={`${id}-fill`} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="var(--accent-ink)" stopOpacity="0.32" />
          <stop offset="100%" stopColor="var(--accent-ink)" stopOpacity="0" />
        </linearGradient>
      </defs>
      {[0, 0.5, 1].map((f) => (
        <g key={f}>
          <line x1={pad.l} x2={width - pad.r} y1={y(nice * f)} y2={y(nice * f)} stroke="var(--line)" />
          <text x={pad.l - 8} y={y(nice * f) + 4} textAnchor="end" fontSize="11" fill="var(--ink-3)">{nice * f}</text>
        </g>
      ))}
      <motion.path d={area} fill={`url(#${id}-fill)`} initial={reduced ? false : { opacity: 0 }} animate={{ opacity: 1 }}
        transition={{ duration: reduced ? 0 : 0.8, delay: reduced ? 0 : 0.5 }} />
      <motion.path d={line} fill="none" stroke="var(--accent-ink)" strokeWidth="2.5" strokeLinecap="round"
        initial={reduced ? false : { pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: reduced ? 0 : 1.2, ease: [0.4, 0, 0.2, 1] }} />
      {labels.map((l, i) => (i % step === 0 || i === labels.length - 1) && (
        <text key={i} x={x(i)} y={height - 6} textAnchor={i === 0 ? 'start' : i === labels.length - 1 ? 'end' : 'middle'} fontSize="11" fill="var(--ink-3)">{l}</text>
      ))}
    </svg>
    </div>
  );
}

/** Bars growing from the baseline, staggered; `highlight` marks one (today). */
export function Bars({ values, labels, height = 150, caption, format = String, highlight }: {
  values: number[]; labels: string[]; height?: number; caption: string; format?: (n: number) => string; highlight?: number;
}) {
  const { reduced } = useSettings();
  const max = Math.max(1, ...values);
  return (
    <div role="img" aria-label={`${caption}: ${values.map((v, i) => `${labels[i]} ${format(v)}`).join(', ')}`}>
      <div className="flex items-end gap-2" style={{ height }}>
        {values.map((v, i) => (
          <div key={i} className="relative flex h-full flex-1 items-end overflow-hidden rounded-[10px]" style={{ background: 'var(--card)' }} title={`${labels[i]}: ${format(v)}`}>
            <motion.div className="w-full rounded-[10px]"
              style={{ height: `${(v / max) * 100}%`, originY: 1, background: i === highlight ? 'var(--accent-ink)' : 'color-mix(in srgb, var(--accent-ink) 62%, transparent)' }}
              initial={reduced ? false : { scaleY: 0 }} animate={{ scaleY: 1 }}
              transition={{ type: 'spring', stiffness: 170, damping: 22, delay: reduced ? 0 : 0.12 + i * 0.045 }} />
          </div>
        ))}
      </div>
      <div className="mt-2 flex gap-2">
        {labels.map((l, i) => <div key={i} className="flex-1 truncate text-center text-[11px] text-ink-3">{l}</div>)}
      </div>
    </div>
  );
}

/** A split bar (on time vs late). */
export function Meter({ parts }: { parts: { value: number; color: string; label: string }[] }) {
  const { reduced } = useSettings();
  const total = parts.reduce((a, p) => a + p.value, 0) || 1;
  return (
    <div className="flex h-3 w-full gap-1 overflow-hidden rounded-full" role="img" aria-label={parts.map((p) => `${p.label} ${p.value}`).join(', ')}>
      {parts.map((p, i) => p.value > 0 && (
        <motion.div key={p.label} className="h-full rounded-full" style={{ background: p.color, originX: 0, width: `${(p.value / total) * 100}%` }}
          initial={reduced ? false : { scaleX: 0 }} animate={{ scaleX: 1 }} transition={{ duration: reduced ? 0 : 0.9, delay: reduced ? 0 : 0.2 + i * 0.1, ease: [0.16, 1, 0.3, 1] }} />
      ))}
    </div>
  );
}
