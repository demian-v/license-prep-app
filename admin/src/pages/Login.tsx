import { useState, type FormEvent } from 'react';
import { motion } from 'motion/react';
import { CarFront } from 'lucide-react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../firebase';
import { spring } from '../lib/motion';

/** The admin signs in with their own account (plan v2 §18a); here, an Auth emulator account. */
export default function Login({ notice }: { notice?: string | null }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password);
    } catch (err) {
      const code = (err as { code?: string }).code ?? '';
      setError(code.includes('network') ? 'The Auth emulator is not reachable.' : 'Wrong email or password.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="grid min-h-full place-items-center p-6">
      <motion.form onSubmit={submit} className="glass w-full max-w-[380px] p-7" initial={{ opacity: 0, y: 16, filter: 'blur(8px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} transition={spring}>
        <div className="mb-5 grid h-12 w-12 place-items-center rounded-[15px] text-white" style={{ background: 'var(--accent)', boxShadow: '0 8px 22px -6px var(--accent-glow)' }}><CarFront size={24} aria-hidden /></div>
        <h1 className="text-[24px] font-bold tracking-[-0.02em]">DriveUSA Admin</h1>
        <p className="mt-1 text-[13.5px] text-ink-3">Local, against the emulators.</p>
        {notice && <p role="alert" className="mt-4 rounded-xl px-3 py-2 text-[13px]" style={{ background: 'hsl(0 80% 55% / 0.15)', color: 'var(--bad)' }}>{notice}</p>}
        <label className="mt-5 block text-[12.5px] font-medium text-ink-2">Email
          <input className="field mt-1.5 w-full" type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </label>
        <label className="mt-3 block text-[12.5px] font-medium text-ink-2">Password
          <input className="field mt-1.5 w-full" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </label>
        {error && <p role="alert" className="mt-3 text-[13px] text-[var(--bad)]">{error}</p>}
        <button className="btn primary mt-5 w-full" disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button>
      </motion.form>
    </main>
  );
}
