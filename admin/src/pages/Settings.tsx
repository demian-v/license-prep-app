import { useState, type ReactNode } from 'react';
import { motion } from 'motion/react';
import { Check, ChevronRight, Eye, Layers, LogOut, Monitor, Moon, Palette, Sparkles, Sun, UserRound, Wallpaper as WallpaperIcon } from 'lucide-react';
import { signOut } from 'firebase/auth';
import { auth } from '../firebase';
import { ACCENTS, WALLPAPERS, useSettings } from '../lib/settings';
import { spring } from '../lib/motion';
import { PageHeader, Panel, Segmented, Toggle } from '../components/ui';

type Section = 'appearance' | 'motion' | 'account';

function Row({ icon, hue, title, hint, children }: { icon: ReactNode; hue: number; title: string; hint?: string; children?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-center gap-3 border-b py-3.5 last:border-0" style={{ borderColor: 'var(--line)' }}>
      <span className="grid h-8 w-8 place-items-center rounded-[10px] text-white" style={{ background: `hsl(${hue} 70% 52%)` }}>{icon}</span>
      <div className="min-w-[160px] flex-1">
        <div className="text-[14px] font-semibold">{title}</div>
        {hint && <div className="text-[12.5px] text-ink-3">{hint}</div>}
      </div>
      {children}
    </div>
  );
}

export default function Settings({ email }: { email: string }) {
  const { settings, set, reduced } = useSettings();
  const [section, setSection] = useState<Section>('appearance');
  const sections: { id: Section; label: string; icon: ReactNode; hue: number }[] = [
    { id: 'appearance', label: 'Appearance', icon: <Palette size={16} />, hue: 268 },
    { id: 'motion', label: 'Motion', icon: <Sparkles size={16} />, hue: 24 },
    { id: 'account', label: 'Account', icon: <UserRound size={16} />, hue: 210 },
  ];

  return (
    <>
      <PageHeader title="Settings" subtitle="The whole panel re-tints through its glass" />
      <div className="grid gap-4 lg:grid-cols-[280px_1fr]">
        <Panel className="h-fit !p-2.5">
          <nav aria-label="Settings sections" className="space-y-1">
            {sections.map((s) => (
              <button key={s.id} onClick={() => setSection(s.id)} aria-current={section === s.id ? 'true' : undefined}
                className="relative flex w-full items-center gap-3 rounded-[14px] px-3 py-2.5 text-left text-[14px] font-medium">
                {section === s.id && <motion.span layoutId="settings-section" transition={spring} className="absolute inset-0 rounded-[14px]" style={{ background: 'var(--card-hover)', boxShadow: 'inset 0 0 0 1px var(--edge)' }} />}
                <span className="relative grid h-7 w-7 place-items-center rounded-[9px] text-white" style={{ background: `hsl(${s.hue} 70% 52%)` }}>{s.icon}</span>
                <span className="relative flex-1">{s.label}</span>
                <ChevronRight size={15} className="relative text-ink-3" aria-hidden />
              </button>
            ))}
          </nav>
        </Panel>

        {section === 'appearance' && (
          <Panel title="Appearance" subtitle="Saved in this browser">
            <Row icon={<Moon size={16} />} hue={250} title="Theme" hint="Auto follows the system">
              <Segmented id="theme" label="Theme" value={settings.theme} onChange={(theme) => set({ theme })}
                options={[{ value: 'light', label: <><Sun size={14} /> Light</> }, { value: 'dark', label: <><Moon size={14} /> Dark</> }, { value: 'auto', label: <><Monitor size={14} /> Auto</> }]} />
            </Row>
            <Row icon={<WallpaperIcon size={16} />} hue={330} title="Wallpaper" hint={WALLPAPERS.find((w) => w.id === settings.wallpaper)?.name} />
            <div className="grid grid-cols-3 gap-3 pb-4 pl-11 sm:grid-cols-6" role="radiogroup" aria-label="Wallpaper">
              {WALLPAPERS.map((w) => (
                <button key={w.id} role="radio" aria-checked={settings.wallpaper === w.id} onClick={() => set({ wallpaper: w.id })} className="text-center">
                  <span className="relative block aspect-[4/3] rounded-[14px]" style={{ background: w.dark, boxShadow: settings.wallpaper === w.id ? '0 0 0 2px var(--accent-ink)' : 'inset 0 0 0 1px var(--line)' }}>
                    {settings.wallpaper === w.id && <span className="absolute right-1.5 bottom-1.5 grid h-5 w-5 place-items-center rounded-full text-white" style={{ background: 'var(--accent)' }}><Check size={12} /></span>}
                  </span>
                  <span className="mt-1.5 block text-[12px] text-ink-2">{w.name}</span>
                </button>
              ))}
            </div>
            <Row icon={<Palette size={16} />} hue={24} title="Accent" hint={ACCENTS.find((a) => a.id === settings.accent)?.name}>
              <div className="flex gap-2.5" role="radiogroup" aria-label="Accent colour">
                {ACCENTS.map((a) => (
                  <button key={a.id} role="radio" aria-checked={settings.accent === a.id} aria-label={a.name} onClick={() => set({ accent: a.id })}
                    className="grid h-8 w-8 place-items-center rounded-full text-white"
                    style={{ background: a.fill, boxShadow: settings.accent === a.id ? `0 0 0 2px var(--panel-solid), 0 0 0 4px ${a.fill}` : 'none' }}>
                    {settings.accent === a.id && <Check size={15} />}
                  </button>
                ))}
              </div>
            </Row>
            <Row icon={<Layers size={16} />} hue={210} title="Glass" hint="Clear shows more of the wallpaper">
              <Segmented id="glass" label="Glass" value={settings.glass} onChange={(glass) => set({ glass })} options={[{ value: 'clear', label: 'Clear' }, { value: 'tinted', label: 'Tinted' }]} />
            </Row>
            <Row icon={<Eye size={16} />} hue={142} title="Reduce transparency" hint="Solid surfaces, no frost">
              <Toggle on={settings.reduceTransparency} onChange={(reduceTransparency) => set({ reduceTransparency })} label="Reduce transparency" />
            </Row>
          </Panel>
        )}

        {section === 'motion' && (
          <Panel title="Motion" subtitle={reduced ? 'Reduced: no blur or movement, numbers just change' : 'Full: blur transitions, rolling numbers, drawn charts'}>
            <Row icon={<Sparkles size={16} />} hue={24} title="Animations" hint="Auto follows the system's Reduce motion">
              <Segmented id="motion" label="Animations" value={settings.motion} onChange={(motion) => set({ motion })} options={[{ value: 'auto', label: 'Auto' }, { value: 'reduced', label: 'Reduced' }]} />
            </Row>
          </Panel>
        )}

        {section === 'account' && (
          <Panel title="Account" subtitle="Every action is an admin callable checking admins/{uid}">
            <Row icon={<UserRound size={16} />} hue={210} title={email} hint="Signed in on the Auth emulator">
              <button className="btn" onClick={() => void signOut(auth)}><LogOut size={15} /> Sign out</button>
            </Row>
            <Row icon={<Monitor size={16} />} hue={160} title="Emulators" hint="Auth 127.0.0.1:9099 · Functions 127.0.0.1:5001 · project licenseprepapp" />
          </Panel>
        )}
      </div>
    </>
  );
}
