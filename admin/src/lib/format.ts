/** Money is integer cents everywhere (plan v2 §5). */
export function money(cents: number, opts: { whole?: boolean } = {}): string {
  const whole = opts.whole ?? Math.abs(cents) >= 100000;
  return new Intl.NumberFormat('en-US', {
    style: 'currency', currency: 'USD', minimumFractionDigits: whole ? 0 : 2, maximumFractionDigits: whole ? 0 : 2,
  }).format(cents / 100);
}

/** "3 min", "5 h", "2 d" — how long something has been waiting. */
export function age(fromMs: number | null | undefined, nowMs = Date.now()): string {
  if (fromMs == null) return '—';
  const min = Math.max(0, Math.round((nowMs - fromMs) / 60000));
  if (min < 60) return `${min} min`;
  const h = Math.round(min / 60);
  if (h < 48) return `${h} h`;
  return `${Math.round(h / 24)} d`;
}

/** "Oct 19", with the year when it isn't this year ("Oct 20, 2027"). */
export function date(ms: number | null | undefined, withTime = false): string {
  if (ms == null) return '—';
  const otherYear = new Date(ms).getFullYear() !== new Date().getFullYear();
  return new Intl.DateTimeFormat('en-US', {
    month: 'short', day: 'numeric', ...(otherYear ? { year: 'numeric' } : {}), ...(withTime ? { hour: 'numeric', minute: '2-digit' } : {}),
  }).format(ms);
}

/** "Lakeview Driving School" → "LD". */
export function initials(name: string | null | undefined): string {
  const words = (name ?? '').trim().split(/\s+/).filter(Boolean);
  return (words.slice(0, 2).map((w) => w[0]).join('') || '?').toUpperCase();
}

export function greeting(hour: number): string {
  return hour < 5 ? 'Good night' : hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
}
