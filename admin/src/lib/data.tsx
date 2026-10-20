import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { api, errorText, type BookingRow, type InstructorRow, type QueueItem } from './api';
import { useIsland } from './island';
import type { Action } from './actions';

interface Ctx {
  items: QueueItem[];
  instructors: InstructorRow[];
  bookings: Record<7 | 30 | 90, BookingRow[] | undefined>;
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  loadBookings: (days: 7 | 30 | 90) => Promise<void>;
  /** Runs an action: the card moves at once, the island says what happened (with Undo when there is one). */
  perform: (item: QueueItem, action: Action, opts?: { expiresAtMs?: number }) => Promise<boolean>;
  setInstructorStatus: (row: InstructorRow, status: 'active' | 'suspended') => Promise<void>;
}

const DataContext = createContext<Ctx | null>(null);

export function DataProvider({ children }: { children: ReactNode }) {
  const island = useIsland();
  const [items, setItems] = useState<QueueItem[]>([]);
  const [instructors, setInstructors] = useState<InstructorRow[]>([]);
  const [bookings, setBookings] = useState<Ctx['bookings']>({ 7: undefined, 30: undefined, 90: undefined });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const [q, i, b] = await Promise.all([api.queue({}), api.instructors({}), api.bookings({ days: 30 })]);
      setItems(q.items);
      setInstructors(i.instructors);
      setBookings((prev) => ({ ...prev, 30: b.bookings }));
      setError(null);
    } catch (e) {
      setError(errorText(e));
    } finally {
      setLoading(false);
    }
  }, []);

  const loadBookings = useCallback(async (days: 7 | 30 | 90) => {
    try {
      const b = await api.bookings({ days });
      setBookings((prev) => ({ ...prev, [days]: b.bookings }));
    } catch (e) {
      island.show({ text: errorText(e), tone: 'error' });
    }
  }, [island]);

  useEffect(() => { void refresh(); }, [refresh]);

  const perform = useCallback<Ctx['perform']>(async (item, action, opts = {}) => {
    const before = items.find((i) => i.key === item.key) ?? item;
    setItems((list) => list.map((i) => (i.key === item.key ? { ...i, ...action.optimistic } : i)));
    try {
      await action.run(opts);
    } catch (e) {
      setItems((list) => list.map((i) => (i.key === item.key ? before : i)));
      island.show({ text: errorText(e), tone: 'error' });
      return false;
    }
    island.show({
      text: action.toast,
      tone: 'done',
      undo: action.undo ? async () => {
        setItems((list) => list.map((i) => (i.key === item.key ? before : i)));
        try {
          await action.undo!();
          island.show({ text: 'Undone', tone: 'info' }, 2500);
        } catch (e) {
          island.show({ text: errorText(e), tone: 'error' });
        }
        void refresh();
      } : undefined,
    });
    void refresh();
    return true;
  }, [items, island, refresh]);

  const setInstructorStatus = useCallback<Ctx['setInstructorStatus']>(async (row, status) => {
    const prev = row.status;
    setInstructors((list) => list.map((r) => (r.uid === row.uid ? { ...r, status, listed: status === 'active' && r.listed } : r)));
    try {
      await api.setInstructorStatus({ uid: row.uid, status });
      island.show({
        text: `${status === 'suspended' ? 'Suspended' : 'Suspension lifted'}: ${row.name}`,
        tone: 'done',
        undo: async () => {
          await api.setInstructorStatus({ uid: row.uid, status: status === 'suspended' ? 'active' : 'suspended' });
          island.show({ text: 'Undone', tone: 'info' }, 2500);
          void refresh();
        },
      });
    } catch (e) {
      setInstructors((list) => list.map((r) => (r.uid === row.uid ? { ...r, status: prev } : r)));
      island.show({ text: errorText(e), tone: 'error' });
    }
    void refresh();
  }, [island, refresh]);

  const value = useMemo(() => ({ items, instructors, bookings, loading, error, refresh, loadBookings, perform, setInstructorStatus }),
    [items, instructors, bookings, loading, error, refresh, loadBookings, perform, setInstructorStatus]);
  return <DataContext.Provider value={value}>{children}</DataContext.Provider>;
}

export function useData(): Ctx {
  const c = useContext(DataContext);
  if (!c) throw new Error('useData outside DataProvider');
  return c;
}
