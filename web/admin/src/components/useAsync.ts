import { useCallback, useEffect, useState } from 'react';

type State<T> =
  | { status: 'loading' }
  | { status: 'error'; error: Error }
  | { status: 'ready'; data: T };

/** Runs `load` on mount and whenever it changes; `reload` runs it again on demand. */
export function useAsync<T>(load: () => Promise<T>) {
  const [state, setState] = useState<State<T>>({ status: 'loading' });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    load().then(
      (data) => { if (!cancelled) setState({ status: 'ready', data }); },
      (error: Error) => { if (!cancelled) setState({ status: 'error', error }); },
    );
    return () => { cancelled = true; };
  }, [load, attempt]);

  const reload = useCallback(() => setAttempt((a) => a + 1), []);
  const setData = useCallback((update: (data: T) => T) => {
    setState((s) => (s.status === 'ready' ? { status: 'ready', data: update(s.data) } : s));
  }, []);

  return { state, reload, setData };
}
