import { useCallback, useEffect, useState } from 'react';
import { useApi } from '../api/client';
import type { AdminUser, VerificationStatus } from '../api/types';
import { ErrorMessage, Loading } from '../components/Feedback';
import { useAsync } from '../components/useAsync';
import { useI18n } from '../i18n';

export function UsersPage() {
  const api = useApi();
  const { t } = useI18n();
  const [input, setInput] = useState('');
  const [query, setQuery] = useState('');

  // Search 300 ms after the admin stops typing.
  useEffect(() => {
    const timer = setTimeout(() => setQuery(input.trim()), 300);
    return () => clearTimeout(timer);
  }, [input]);

  const load = useCallback(() => api.searchUsers(query), [api, query]);
  const { state, reload, setData } = useAsync(load);

  const replace = (user: AdminUser) => setData((users) => users.map((u) => (u.id === user.id ? user : u)));

  return (
    <section>
      <h1>{t('nav.users')}</h1>
      <input
        type="search"
        className="search"
        placeholder={t('users.search')}
        aria-label={t('users.search')}
        value={input}
        onChange={(e) => setInput(e.target.value)}
      />
      {state.status === 'loading' && <Loading />}
      {state.status === 'error' && <ErrorMessage error={state.error} onRetry={reload} />}
      {state.status === 'ready' && (state.data.length === 0 ? (
        <p className="muted">{t('users.empty')}</p>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('users.name')}</th>
                <th>{t('users.phone')}</th>
                <th>{t('users.passenger')}</th>
                <th>{t('users.driver')}</th>
                <th className="numeric">{t('users.strikes')}</th>
                <th>{t('users.status')}</th>
                <th aria-label="actions" />
              </tr>
            </thead>
            <tbody>
              {state.data.map((user) => <UserRow key={user.id} user={user} onChange={replace} />)}
            </tbody>
          </table>
        </div>
      ))}
    </section>
  );
}

function StatusBadge({ status }: { status: VerificationStatus }) {
  const { t } = useI18n();
  return <span className={`badge ${status.toLowerCase()}`}>{t(`status.${status}`)}</span>;
}

function UserRow({ user, onChange }: { user: AdminUser; onChange: (user: AdminUser) => void }) {
  const api = useApi();
  const { t, formatDate } = useI18n();
  const [suspending, setSuspending] = useState(false);
  const [days, setDays] = useState(30);
  const [reason, setReason] = useState('');
  const [error, setError] = useState<Error | null>(null);

  const suspended = user.suspendedUntil !== null && new Date(user.suspendedUntil) > new Date();

  async function run(action: () => Promise<AdminUser>) {
    setError(null);
    try {
      onChange(await action());
      setSuspending(false);
    } catch (e) {
      setError(e as Error);
    }
  }

  return (
    <>
      <tr>
        <td>{user.firstName} {user.lastName}</td>
        <td className="nowrap">{user.phoneNumber}</td>
        <td><StatusBadge status={user.passengerStatus} /></td>
        <td><StatusBadge status={user.driverStatus} /></td>
        <td className="numeric">{user.strikes}</td>
        <td>
          {suspended
            ? <span title={user.suspensionReason ?? ''}>{t('users.suspendedUntil')} {formatDate(user.suspendedUntil!)}</span>
            : t('users.active')}
        </td>
        <td className="nowrap">
          {suspended ? (
            <button type="button" className="button secondary small" onClick={() => void run(() => api.unsuspendUser(user.id))}>
              {t('users.unsuspend')}
            </button>
          ) : (
            <button type="button" className="button secondary small" onClick={() => setSuspending((s) => !s)}>
              {t('users.suspend')}
            </button>
          )}
        </td>
      </tr>
      {(suspending || error) && (
        <tr className="subrow">
          <td colSpan={7}>
            {suspending && (
              <form
                className="inline-form"
                onSubmit={(e) => { e.preventDefault(); void run(() => api.suspendUser(user.id, days, reason.trim())); }}
              >
                <label>
                  {t('users.days')}
                  <input type="number" min={1} max={365} value={days} onChange={(e) => setDays(Number(e.target.value))} required />
                </label>
                <label className="grow">
                  {t('users.reason')}
                  <input value={reason} onChange={(e) => setReason(e.target.value)} required />
                </label>
                <button type="submit" className="button danger small" disabled={!reason.trim()}>{t('users.suspend')}</button>
              </form>
            )}
            {error && <ErrorMessage error={error} />}
          </td>
        </tr>
      )}
    </>
  );
}
