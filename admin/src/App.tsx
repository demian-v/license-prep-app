import { useEffect, useState } from 'react';
import { AnimatePresence, MotionConfig, motion } from 'motion/react';
import { onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { auth } from './firebase';
import { useSettings } from './lib/settings';
import { IslandProvider } from './lib/island';
import { DataProvider, useData } from './lib/data';
import { pageVariants } from './lib/motion';
import { ActionCluster, Island, Rail, Wallpaper, type Page } from './components/Shell';
import { ItemSheetProvider } from './components/Items';
import Login from './pages/Login';
import Overview from './pages/Overview';
import Queue from './pages/Queue';
import Licences from './pages/Licences';
import Bookings from './pages/Bookings';
import Instructors from './pages/Instructors';
import Insights from './pages/Insights';
import Settings from './pages/Settings';

const PAGES: Page[] = ['overview', 'queue', 'licences', 'bookings', 'instructors', 'insights', 'settings'];
const pageFromHash = (): Page => (PAGES.find((p) => `#${p}` === location.hash) ?? 'overview');

export default function App() {
  const { reduced } = useSettings();
  const [user, setUser] = useState<User | null | undefined>(undefined);
  const [notice, setNotice] = useState<string | null>(null);
  useEffect(() => onAuthStateChanged(auth, setUser), []);

  return (
    <MotionConfig reducedMotion={reduced ? 'always' : 'never'}>
      <Wallpaper />
      {user === undefined ? null : user === null ? <Login notice={notice} /> : (
        <IslandProvider>
          <DataProvider>
            <AdminGate onDenied={() => { setNotice('This account is not an admin (no admins/{uid} document).'); void signOut(auth); }}>
              <ItemSheetProvider>
                <Shell email={user.email ?? ''} />
              </ItemSheetProvider>
            </AdminGate>
          </DataProvider>
        </IslandProvider>
      )}
    </MotionConfig>
  );
}

/** A signed-in account the callables refuse is signed out again, with the reason on the login card. */
function AdminGate({ children, onDenied }: { children: React.ReactNode; onDenied: () => void }) {
  const { error } = useData();
  useEffect(() => { if (error === 'This account is not an admin.') onDenied(); }, [error, onDenied]);
  return <>{children}</>;
}

function Shell({ email }: { email: string }) {
  const { reduced } = useSettings();
  const { error } = useData();
  const [page, setPage] = useState<Page>(pageFromHash);
  const [urgentOnly, setUrgentOnly] = useState(false);
  useEffect(() => {
    const f = () => { setPage(pageFromHash()); window.scrollTo({ top: 0 }); };
    window.addEventListener('hashchange', f);
    return () => window.removeEventListener('hashchange', f);
  }, []);
  const go = (p: Page, opts: { urgent?: boolean } = {}) => {
    setUrgentOnly(!!opts.urgent);
    if (location.hash !== `#${p}`) location.hash = p;
    setPage(p);
    window.scrollTo({ top: 0 });
  };

  return (
    <>
      <Rail page={page} onPage={go} email={email} />
      <Island />
      <ActionCluster onBell={() => go('queue', { urgent: true })} />
      <main className="min-h-full pt-[88px] pr-5 pb-10 pl-[104px]">
        <div className="mx-auto max-w-[1280px]">
          {error && error !== 'This account is not an admin.' && (
            <div role="alert" className="glass mb-4 !rounded-2xl px-4 py-3 text-[13.5px]" style={{ color: 'var(--bad)' }}>{error}</div>
          )}
          <AnimatePresence mode="wait" initial={false}>
            <motion.div key={`${page}-${urgentOnly}`} variants={pageVariants(reduced)} initial="initial" animate="enter" exit="exit">
              {page === 'overview' && <Overview onPage={go} />}
              {page === 'queue' && <Queue urgentOnly={urgentOnly} />}
              {page === 'licences' && <Licences />}
              {page === 'bookings' && <Bookings />}
              {page === 'instructors' && <Instructors />}
              {page === 'insights' && <Insights />}
              {page === 'settings' && <Settings email={email} />}
            </motion.div>
          </AnimatePresence>
        </div>
      </main>
    </>
  );
}
