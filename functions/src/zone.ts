/**
 * Wall-clock time in an IANA zone, with the platform's own ICU data (owner,
 * 2026-10-05: Intl rather than a date library — Node 22 ships full ICU).
 *
 * Bookings are stored as UTC instants (plan v2 §5); only an instructor's
 * weekly `availability` is wall-clock, in their `timezone`. These two
 * conversions are all the booking code needs. Availability runs 06:00–22:00,
 * so the 02:00 DST gap and overlap never fall inside a lesson.
 */

// The same keys as an instructor's `availability` (instructors.ts WEEK_DAYS).
const DAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] as const;
export type WeekDay = typeof DAYS[number];

const formatters = new Map<string, Intl.DateTimeFormat>();
function formatter(tz: string): Intl.DateTimeFormat {
  let f = formatters.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone: tz, hourCycle: 'h23',
      year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit',
    });
    formatters.set(tz, f);
  }
  return f;
}

/** The local date ('YYYY-MM-DD') and minutes after midnight of an instant. */
export function wallClock(ms: number, tz: string): { date: string; minutes: number } {
  const p: Record<string, string> = {};
  for (const part of formatter(tz).formatToParts(new Date(ms))) p[part.type] = part.value;
  return { date: `${p.year}-${p.month}-${p.day}`, minutes: Number(p.hour) * 60 + Number(p.minute) };
}

/** 'mon'…'sun' of a 'YYYY-MM-DD' date. */
export function weekDay(date: string): WeekDay {
  const [y, m, d] = date.split('-').map(Number);
  return DAYS[(new Date(Date.UTC(y, m - 1, d)).getUTCDay() + 6) % 7];
}

/** 'YYYY-MM-DD' plus n days. */
export function addDays(date: string, n: number): string {
  const [y, m, d] = date.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}

/** How far the zone's wall clock is ahead of UTC at an instant, in ms. */
function offsetMs(ms: number, tz: string): number {
  const { date, minutes } = wallClock(ms, tz);
  const [y, m, d] = date.split('-').map(Number);
  return Date.UTC(y, m - 1, d, 0, minutes) - (ms - (ms % 60000));
}

/**
 * The UTC instant of a wall-clock time in a zone, or null when that time
 * does not exist there (the hour skipped by a spring-forward).
 */
export function wallToUtc(date: string, minutes: number, tz: string): number | null {
  const [y, m, d] = date.split('-').map(Number);
  const guess = Date.UTC(y, m - 1, d, 0, minutes);
  const first = guess - offsetMs(guess, tz);
  const ms = guess - offsetMs(first, tz);
  const back = wallClock(ms, tz);
  return back.date === date && back.minutes === minutes ? ms : null;
}

/** "HH:MM" → minutes after midnight. */
export function minutesOf(hhmm: string): number {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

/** Minutes after midnight → "HH:MM". */
export function hhmm(minutes: number): string {
  return `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;
}
