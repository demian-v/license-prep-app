import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react';

/**
 * The pill at the top: live status, and the toast after an action («Review
 * hidden · Undo»), as in the reference's island. Moderation can be undone
 * (hide, never delete); money actions show no Undo.
 */
export interface Toast {
  id: number;
  text: string;
  tone: 'done' | 'error' | 'info';
  undo?: () => Promise<void> | void;
}

interface Ctx {
  toast: Toast | null;
  show: (t: Omit<Toast, 'id'>, ms?: number) => void;
  dismiss: () => void;
}

const IslandContext = createContext<Ctx | null>(null);

export function IslandProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<Toast | null>(null);
  const timer = useRef<number | undefined>(undefined);
  const dismiss = useCallback(() => {
    window.clearTimeout(timer.current);
    setToast(null);
  }, []);
  const show = useCallback((t: Omit<Toast, 'id'>, ms = 6000) => {
    window.clearTimeout(timer.current);
    setToast({ ...t, id: Date.now() });
    timer.current = window.setTimeout(() => setToast(null), ms);
  }, []);
  return <IslandContext.Provider value={{ toast, show, dismiss }}>{children}</IslandContext.Provider>;
}

export function useIsland(): Ctx {
  const c = useContext(IslandContext);
  if (!c) throw new Error('useIsland outside IslandProvider');
  return c;
}
