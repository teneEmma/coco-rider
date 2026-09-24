import { Link } from 'react-router-dom';
import { useApi } from '../api/client';
import { ErrorMessage, Loading } from '../components/Feedback';
import { useAsync } from '../components/useAsync';
import { useI18n, type TranslationKey } from '../i18n';

export function StatsPage() {
  const api = useApi();
  const { t, formatXaf } = useI18n();
  const { state, reload } = useAsync(api.stats);

  if (state.status === 'loading') return <Loading />;
  if (state.status === 'error') return <ErrorMessage error={state.error} onRetry={reload} />;

  const s = state.data;
  const tiles: { label: TranslationKey; value: string; to?: string; attention?: boolean }[] = [
    { label: 'stats.documentsToReview', value: String(s.documentsToReview), to: '/documents', attention: s.documentsToReview > 0 },
    { label: 'stats.users', value: String(s.users), to: '/users' },
    { label: 'stats.verifiedDrivers', value: String(s.verifiedDrivers) },
    { label: 'stats.verifiedPassengers', value: String(s.verifiedPassengers) },
    { label: 'stats.upcomingTrips', value: String(s.upcomingTrips) },
    { label: 'stats.bookings30', value: String(s.bookingsLast30Days) },
    { label: 'stats.commission30', value: formatXaf(s.commissionOwedLast30DaysXaf) },
  ];

  return (
    <section>
      <h1>{t('nav.stats')}</h1>
      <div className="tiles">
        {tiles.map((tile) => {
          const body = (
            <>
              <span className="tile-label">
                {tile.attention && <span className="dot" aria-hidden="true" />}
                {t(tile.label)}
              </span>
              <span className="tile-value">{tile.value}</span>
            </>
          );
          return tile.to ? (
            <Link key={tile.label} to={tile.to} className={`card tile${tile.attention ? ' attention' : ''}`}>{body}</Link>
          ) : (
            <div key={tile.label} className="card tile">{body}</div>
          );
        })}
      </div>
    </section>
  );
}
