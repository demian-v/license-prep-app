import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';

export type ThemeSetting = 'light' | 'dark' | 'auto';
export type MotionSetting = 'auto' | 'reduced';

/** Accent fills keep white text AA (≥ 4.5:1); `ink` is the lighter tint for text on glass. */
export const ACCENTS = [
  { id: 'blue', name: 'Blue', fill: '#2563eb', ink: '#7ab4fb', inkLight: '#1d4ed8' },
  { id: 'violet', name: 'Violet', fill: '#7c3aed', ink: '#b8a5fc', inkLight: '#6d28d9' },
  { id: 'pink', name: 'Pink', fill: '#db2777', ink: '#f78fc8', inkLight: '#be185d' },
  { id: 'orange', name: 'Orange', fill: '#c2410c', ink: '#fcaa70', inkLight: '#c2410c' },
  { id: 'green', name: 'Green', fill: '#15803d', ink: '#6fe39b', inkLight: '#15803d' },
  { id: 'graphite', name: 'Graphite', fill: '#52525b', ink: '#d4d4d8', inkLight: '#3f3f46' },
] as const;

/** Our own wallpapers (CSS only); dark and light variants. */
export const WALLPAPERS = [
  { id: 'ash', name: 'Ash', dark: 'radial-gradient(120% 80% at 70% 0%, #2a2c31 0%, #17181b 55%, #121315 100%)', light: 'radial-gradient(120% 80% at 70% 0%, #f4f4f6 0%, #e4e5e9 60%, #d9dbe0 100%)' },
  { id: 'smoke', name: 'Smoke', dark: 'radial-gradient(90% 70% at 15% 10%, #3a3d44 0%, transparent 60%), radial-gradient(80% 60% at 90% 90%, #2b2e35 0%, transparent 60%), #141518', light: 'radial-gradient(90% 70% at 15% 10%, #ffffff 0%, transparent 60%), radial-gradient(80% 60% at 90% 90%, #cfd3da 0%, transparent 60%), #e3e5ea' },
  { id: 'tide', name: 'Tide', dark: 'radial-gradient(90% 70% at 10% 0%, #145286 0%, transparent 60%), radial-gradient(80% 70% at 100% 100%, #0f6d68 0%, transparent 60%), #0e1418', light: 'radial-gradient(90% 70% at 10% 0%, #bfe3ff 0%, transparent 60%), radial-gradient(80% 70% at 100% 100%, #b8efe8 0%, transparent 60%), #e6eef3' },
  { id: 'dusk', name: 'Dusk', dark: 'radial-gradient(90% 70% at 0% 0%, #562a82 0%, transparent 60%), radial-gradient(80% 70% at 100% 100%, #7e2b60 0%, transparent 60%), #141118', light: 'radial-gradient(90% 70% at 0% 0%, #e2d4ff 0%, transparent 60%), radial-gradient(80% 70% at 100% 100%, #ffd3ea 0%, transparent 60%), #efe9f3' },
  { id: 'grove', name: 'Grove', dark: 'radial-gradient(90% 70% at 0% 0%, #1e6642 0%, transparent 60%), radial-gradient(80% 70% at 100% 100%, #466c19 0%, transparent 60%), #0f1511', light: 'radial-gradient(90% 70% at 0% 0%, #c9f0d8 0%, transparent 60%), radial-gradient(80% 70% at 100% 100%, #e4f2c4 0%, transparent 60%), #e9efe9' },
  { id: 'ember', name: 'Ember', dark: 'radial-gradient(90% 70% at 0% 0%, #803c15 0%, transparent 60%), radial-gradient(80% 70% at 100% 100%, #7c1b2e 0%, transparent 60%), #171110', light: 'radial-gradient(90% 70% at 0% 0%, #ffdcc4 0%, transparent 60%), radial-gradient(80% 70% at 100% 100%, #ffd0d6 0%, transparent 60%), #f3ebe8' },
] as const;

export interface Settings {
  theme: ThemeSetting;
  accent: (typeof ACCENTS)[number]['id'];
  wallpaper: (typeof WALLPAPERS)[number]['id'];
  glass: 'clear' | 'tinted';
  reduceTransparency: boolean;
  motion: MotionSetting;
}

const DEFAULTS: Settings = { theme: 'dark', accent: 'blue', wallpaper: 'ash', glass: 'tinted', reduceTransparency: false, motion: 'auto' };
const KEY = 'driveusa-admin-settings';

function load(): Settings {
  try {
    return { ...DEFAULTS, ...JSON.parse(localStorage.getItem(KEY) ?? '{}') };
  } catch {
    return DEFAULTS;
  }
}

function useMedia(query: string): boolean {
  const [on, setOn] = useState(() => matchMedia(query).matches);
  useEffect(() => {
    const m = matchMedia(query);
    const f = () => setOn(m.matches);
    m.addEventListener('change', f);
    return () => m.removeEventListener('change', f);
  }, [query]);
  return on;
}

interface Ctx {
  settings: Settings;
  set: (patch: Partial<Settings>) => void;
  /** The theme in effect (Auto resolved). */
  dark: boolean;
  /** Reduced motion: the setting, or the system's prefers-reduced-motion. */
  reduced: boolean;
  wallpaper: string;
}

const SettingsContext = createContext<Ctx | null>(null);

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<Settings>(load);
  const systemDark = useMedia('(prefers-color-scheme: dark)');
  const systemReduced = useMedia('(prefers-reduced-motion: reduce)');
  const dark = settings.theme === 'auto' ? systemDark : settings.theme === 'dark';
  const reduced = settings.motion === 'reduced' || systemReduced;

  useEffect(() => {
    const root = document.documentElement;
    const accent = ACCENTS.find((a) => a.id === settings.accent) ?? ACCENTS[0];
    root.dataset.theme = dark ? 'dark' : 'light';
    root.dataset.glass = settings.glass;
    root.dataset.solid = String(settings.reduceTransparency);
    root.style.setProperty('--accent', accent.fill);
    root.style.setProperty('--accent-ink', dark ? accent.ink : accent.inkLight);
    root.style.setProperty('--accent-glow', `${accent.fill}73`);
    try {
      localStorage.setItem(KEY, JSON.stringify(settings));
    } catch { /* private mode: settings last for the session */ }
  }, [settings, dark]);

  const value = useMemo<Ctx>(() => {
    const wp = WALLPAPERS.find((w) => w.id === settings.wallpaper) ?? WALLPAPERS[0];
    return { settings, set: (patch) => setSettings((s) => ({ ...s, ...patch })), dark, reduced, wallpaper: dark ? wp.dark : wp.light };
  }, [settings, dark, reduced]);
  return <SettingsContext.Provider value={value}>{children}</SettingsContext.Provider>;
}

export function useSettings(): Ctx {
  const c = useContext(SettingsContext);
  if (!c) throw new Error('useSettings outside SettingsProvider');
  return c;
}
