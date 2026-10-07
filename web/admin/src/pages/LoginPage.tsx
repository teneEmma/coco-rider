import { useState, type FormEvent } from 'react';
import { NotAdminError, useAuth } from '../auth/AuthContext';
import { CognitoError } from '../auth/cognito';
import { useI18n } from '../i18n';

/** Accepts "6 90 00 00 00", "690000000" or "+237690000000" and returns E.164. */
export function normalizeCameroonPhone(input: string): string {
  const digits = input.replace(/[^\d+]/g, '');
  if (digits.startsWith('+')) return digits;
  if (digits.startsWith('237') && digits.length === 12) return `+${digits}`;
  return `+237${digits}`;
}

export function LoginPage() {
  const { cognito, config, signInWithTokens, signInForDevelopment } = useAuth();
  const { t } = useI18n();
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [session, setSession] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const development = config.authMode === 'development';

  async function run(action: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (e) {
      if (e instanceof NotAdminError) setError(t('login.notAdmin'));
      else if (e instanceof CognitoError) setError(`${t('login.failed')} (${e.type})`);
      else setError(t('login.failed'));
    } finally {
      setBusy(false);
    }
  }

  function onSendCode(event: FormEvent) {
    event.preventDefault();
    const phoneNumber = normalizeCameroonPhone(phone);
    if (development) {
      signInForDevelopment(phoneNumber);
      return;
    }
    void run(async () => setSession(await cognito!.sendCode(phoneNumber)));
  }

  function onConfirm(event: FormEvent) {
    event.preventDefault();
    const phoneNumber = normalizeCameroonPhone(phone);
    void run(async () => signInWithTokens(phoneNumber, await cognito!.confirmCode(phoneNumber, session!, code.trim())));
  }

  return (
    <main className="login">
      <div className="card login-card">
        <h1>{t('appName')}</h1>
        <h2>{t('login.title')}</h2>
        {session === null ? (
          <form onSubmit={onSendCode}>
            <label>
              {t('login.phone')}
              <input
                type="tel"
                inputMode="tel"
                autoComplete="tel"
                placeholder="+237 6XX XX XX XX"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                required
              />
            </label>
            <button className="button" type="submit" disabled={busy}>{t('login.sendCode')}</button>
            {development && <p className="muted small">{t('login.devHint')}</p>}
          </form>
        ) : (
          <form onSubmit={onConfirm}>
            <label>
              {t('login.code')}
              <input
                inputMode="numeric"
                autoComplete="one-time-code"
                pattern="\d{6,8}"
                value={code}
                onChange={(e) => setCode(e.target.value)}
                required
                autoFocus
              />
            </label>
            <button className="button" type="submit" disabled={busy}>{t('login.confirm')}</button>
          </form>
        )}
        {error && <p className="alert" role="alert">{error}</p>}
      </div>
    </main>
  );
}
