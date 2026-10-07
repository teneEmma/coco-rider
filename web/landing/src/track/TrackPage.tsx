import { useEffect, useState } from 'react';
import type { Locale } from '../content';
import { TrackMap } from './TrackMap';
import { trackContent } from './trackContent';

interface Location { city: string; landmark: string; latitude: number; longitude: number }

interface SharedTrip {
  origin: Location;
  destination: Location;
  departureAt: string;
  status: 'Scheduled' | 'Cancelled' | 'Completed';
  driverFirstName: string;
  vehicle: { make: string; model: string; color: string; plateNumber: string };
  position: {
    latitude: number;
    longitude: number;
    recordedAt: string;
    isLive: boolean;
    distanceToDestinationKm: number;
  } | null;
}

type State =
  | { kind: 'loading' }
  | { kind: 'expired' }
  | { kind: 'ready'; trip: SharedTrip; failing: boolean; loadedAt: number };

const REFRESH_MS = 10_000;

/** API base URL: /config.json written by the CDK stack in AWS, the local API otherwise. */
async function apiUrl(): Promise<string> {
  try {
    const response = await fetch('/config.json', { cache: 'no-store' });
    if (response.ok && response.headers.get('content-type')?.includes('json')) {
      return ((await response.json()) as { apiUrl: string }).apiUrl.replace(/\/$/, '');
    }
  } catch {
    // Local development.
  }
  return (import.meta.env.VITE_API_URL as string | undefined) ?? 'http://localhost:5200';
}

/** Public page opened from a link shared by a passenger: /suivi/{token}. */
export function TrackPage({ token, locale }: { token: string; locale: Locale }) {
  const t = trackContent[locale];
  const [state, setState] = useState<State>({ kind: 'loading' });

  useEffect(() => {
    let stopped = false;
    let timer: ReturnType<typeof setTimeout>;

    const load = async () => {
      try {
        const response = await fetch(`${await apiUrl()}/v1/shared/${encodeURIComponent(token)}`);
        if (stopped) return;
        if (response.status === 404) {
          setState({ kind: 'expired' });
          return;
        }
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const trip = (await response.json()) as SharedTrip;
        setState({ kind: 'ready', trip, failing: false, loadedAt: Date.now() });
        if (trip.status === 'Scheduled') timer = setTimeout(load, REFRESH_MS);
      } catch {
        if (stopped) return;
        setState((s) => (s.kind === 'ready' ? { ...s, failing: true } : s));
        timer = setTimeout(load, REFRESH_MS);
      }
    };

    void load();
    return () => {
      stopped = true;
      clearTimeout(timer);
    };
  }, [token]);

  if (state.kind === 'loading') return <main className="track"><p className="muted">{t.loading}</p></main>;
  if (state.kind === 'expired') {
    return (
      <main className="track">
        <p className="track-status">{t.expired}</p>
        <a href="/">{t.download}</a>
      </main>
    );
  }

  const { trip, failing, loadedAt } = state;
  const tag = locale === 'fr' ? 'fr-CM' : 'en-CM';
  const departure = new Date(trip.departureAt).toLocaleString(tag, {
    weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'Africa/Douala',
  });
  const position = trip.position;
  const minutesAgo = position ? Math.max(0, Math.round((loadedAt - new Date(position.recordedAt).getTime()) / 60_000)) : 0;
  const km = position ? new Intl.NumberFormat(tag, { maximumFractionDigits: 1 }).format(position.distanceToDestinationKm) : '';

  let status: string;
  if (trip.status === 'Completed') status = t.over;
  else if (trip.status === 'Cancelled') status = t.cancelled;
  else if (!position) status = t.waiting;
  else status = position.isLive ? t.live : t.lastSeen(minutesAgo);

  return (
    <main className="track">
      <h1>{t.title(trip.driverFirstName)}</h1>
      <p className="track-route">{trip.origin.city} – {trip.destination.city}</p>

      <p className={`track-status${position?.isLive ? ' live' : ''}`} role="status">
        {position?.isLive && <span className="pulse" aria-hidden="true" />}
        {status}
      </p>
      {position && trip.status === 'Scheduled' && <p className="track-distance">{t.distance(km, trip.destination.city)}</p>}
      {failing && <p className="muted small">{t.error}</p>}

      <TrackMap
        car={trip.status === 'Scheduled' ? position : null}
        destination={trip.destination}
        carLabel={trip.driverFirstName}
        destinationLabel={`${trip.destination.city} · ${trip.destination.landmark}`}
      />

      <dl className="track-details">
        <dt>{t.departure}</dt>
        <dd>{departure} · {trip.origin.city} ({trip.origin.landmark})</dd>
        <dt>{t.vehicle}</dt>
        <dd>{trip.vehicle.make} {trip.vehicle.model} · {trip.vehicle.color}</dd>
        <dt>{t.plate}</dt>
        <dd className="plate">{trip.vehicle.plateNumber}</dd>
      </dl>

      <p className="muted small">{t.safety}</p>
      <a href="/">{t.download}</a>
    </main>
  );
}
