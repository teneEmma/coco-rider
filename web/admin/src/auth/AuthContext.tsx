import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import type { AppConfig } from '../config';
import { CognitoClient, isAdmin, type Tokens } from './cognito';

type Session =
  | { kind: 'cognito'; phoneNumber: string; tokens: Tokens }
  | { kind: 'development'; phoneNumber: string; sub: string };

interface AuthContextValue {
  config: AppConfig;
  session: Session | null;
  cognito: CognitoClient | null;
  signInWithTokens: (phoneNumber: string, tokens: Tokens) => void;
  signInForDevelopment: (phoneNumber: string) => void;
  signOut: () => void;
  /** Headers for an API call, refreshing the token when it is about to expire. */
  authHeaders: () => Promise<Record<string, string>>;
}

const STORAGE_KEY = 'coco-admin-session';
const AuthContext = createContext<AuthContextValue | null>(null);

function readStoredSession(): Session | null {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Session) : null;
  } catch {
    return null;
  }
}

function storeSession(session: Session | null) {
  try {
    if (session) sessionStorage.setItem(STORAGE_KEY, JSON.stringify(session));
    else sessionStorage.removeItem(STORAGE_KEY);
  } catch {
    // Private mode: the session simply does not survive a reload.
  }
}

export class NotAdminError extends Error {}

export function AuthProvider({ config, children }: { config: AppConfig; children: ReactNode }) {
  const [session, setSessionState] = useState<Session | null>(readStoredSession);

  const cognito = useMemo(
    () => (config.authMode === 'cognito' && config.region && config.clientId
      ? new CognitoClient(config.region, config.clientId)
      : null),
    [config],
  );

  const setSession = useCallback((next: Session | null) => {
    storeSession(next);
    setSessionState(next);
  }, []);

  const signInWithTokens = useCallback((phoneNumber: string, tokens: Tokens) => {
    if (!isAdmin(tokens.idToken)) throw new NotAdminError();
    setSession({ kind: 'cognito', phoneNumber, tokens });
  }, [setSession]);

  const signInForDevelopment = useCallback((phoneNumber: string) => {
    setSession({ kind: 'development', phoneNumber, sub: `admin-${phoneNumber}` });
  }, [setSession]);

  const signOut = useCallback(() => setSession(null), [setSession]);

  const authHeaders = useCallback(async (): Promise<Record<string, string>> => {
    if (!session) return {};
    if (session.kind === 'development') {
      return { 'X-Dev-User': session.sub, 'X-Dev-Phone': session.phoneNumber, 'X-Dev-Groups': 'admin' };
    }

    let tokens = session.tokens;
    if (cognito && tokens.expiresAt - Date.now() < 60_000) {
      try {
        tokens = await cognito.refresh(tokens.refreshToken);
        setSession({ ...session, tokens });
      } catch {
        setSession(null);
        return {};
      }
    }
    return { Authorization: `Bearer ${tokens.idToken}` };
  }, [session, cognito, setSession]);

  const value = useMemo(
    () => ({ config, session, cognito, signInWithTokens, signInForDevelopment, signOut, authHeaders }),
    [config, session, cognito, signInWithTokens, signInForDevelopment, signOut, authHeaders],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside AuthProvider');
  return context;
}
