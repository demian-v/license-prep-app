/**
 * IANA time zone for an instructor's ZIP code (instructors plan v2 §4.3).
 *
 * Lessons are booked in the instructor's local time, and several released
 * states span two zones, so the state alone is not enough. The table covers
 * only the 20 released states (StateData.releasedStateIds): each state's zone,
 * plus the ZIP-prefix exceptions where part of the state is in another zone.
 *
 * Known gaps, deliberately NOT guessed (fix before that state launches —
 * IL and TX, the first launch states, have no gap):
 *   - MI: the four Upper Peninsula counties on Central time (Gogebic, Iron,
 *     Dickinson, Menominee) share ZIP prefixes 498/499 with Eastern towns.
 *   - AZ: the Navajo Nation observes DST while the rest of Arizona does not.
 */
export const RELEASED_STATES = [
  'CA', 'TX', 'FL', 'NJ', 'PA', 'WA', 'MI', 'AZ', 'OH', 'NC',
  'MA', 'MD', 'IL', 'NY', 'GA', 'VA', 'CO', 'NV', 'OR', 'MN',
] as const;

const STATE_ZONE: Record<string, string> = {
  CA: 'America/Los_Angeles', WA: 'America/Los_Angeles', OR: 'America/Los_Angeles', NV: 'America/Los_Angeles',
  AZ: 'America/Phoenix', CO: 'America/Denver',
  TX: 'America/Chicago', IL: 'America/Chicago', MN: 'America/Chicago',
  MI: 'America/Detroit',
  FL: 'America/New_York', NJ: 'America/New_York', PA: 'America/New_York', OH: 'America/New_York',
  NC: 'America/New_York', MA: 'America/New_York', MD: 'America/New_York', NY: 'America/New_York',
  GA: 'America/New_York', VA: 'America/New_York',
};

/** [state, ZIP prefix, zone] — longest matching prefix wins. */
const EXCEPTIONS: Array<[string, string, string]> = [
  ['TX', '798', 'America/Denver'], // El Paso
  ['TX', '799', 'America/Denver'], // El Paso
  ['TX', '885', 'America/Denver'], // El Paso (PO boxes)
  ['FL', '324', 'America/Chicago'], // Panama City area
  ['FL', '325', 'America/Chicago'], // Pensacola area
  ['OR', '979', 'America/Boise'], // Malheur County (Ontario, Vale)
  ['NV', '89883', 'America/Denver'], // West Wendover
];

export function timezoneForZip(state: string, zip: string): string | null {
  const zone = STATE_ZONE[state];
  if (!zone || !/^\d{5}$/.test(zip)) return null;
  const match = EXCEPTIONS
    .filter(([s, prefix]) => s === state && zip.startsWith(prefix))
    .sort((a, b) => b[1].length - a[1].length)[0];
  return match ? match[2] : zone;
}
