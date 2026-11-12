"use client";

// Asks the backend again every `everyMs` milliseconds, ONLY while the page
// is visible (another tab or a minimised window: no request). When the page
// comes back, it asks at once. The data changes once a minute (one batch of
// Node-RED), so 15 s is plenty.
import { useCallback, useEffect, useRef, useState } from "react";

export type Polled<T> = {
  data: T | null;
  error: unknown;
  /** When the last answer arrived (this computer's clock). */
  receivedAt: number | null;
  /** Ask now (e.g. a "Réessayer" button). */
  reload: () => void;
};

export function usePolling<T>(load: () => Promise<T>, everyMs: number): Polled<T> {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [receivedAt, setReceivedAt] = useState<number | null>(null);
  const [round, setRound] = useState(0);
  const loadRef = useRef(load);

  useEffect(() => {
    loadRef.current = load;
  }, [load]);

  useEffect(() => {
    let stopped = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let busy = false;

    async function tick() {
      clearTimeout(timer);
      if (document.visibilityState === "visible" && !busy) {
        busy = true;
        try {
          const value = await loadRef.current();
          if (!stopped) {
            setData(value);
            setError(null);
            setReceivedAt(Date.now());
          }
        } catch (e) {
          if (!stopped) setError(e);
        } finally {
          busy = false;
        }
      }
      if (!stopped) timer = setTimeout(tick, everyMs);
    }

    function onVisible() {
      if (document.visibilityState === "visible") tick();
    }

    tick();
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      stopped = true;
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [everyMs, round]);

  const reload = useCallback(() => setRound((n) => n + 1), []);
  return { data, error, receivedAt, reload };
}

/** A clock that moves every `everyMs` (to keep "il y a 40 s" right). */
export function useNow(everyMs = 5000): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), everyMs);
    return () => clearInterval(id);
  }, [everyMs]);
  return now;
}
