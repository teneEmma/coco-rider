import { cleanup, render, screen } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { TrackPage } from './TrackPage';

// Leaflet needs a real browser layout; the map itself is covered by the browser test.
vi.mock('./TrackMap', () => ({ TrackMap: () => <div data-testid="map" /> }));

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

const trip = {
  origin: { city: 'Douala', landmark: 'Carrefour Ndokoti', latitude: 4.05, longitude: 9.77 },
  destination: { city: 'Yaoundé', landmark: 'Total Mvan', latitude: 3.85, longitude: 11.5 },
  departureAt: '2026-10-05T06:30:00Z',
  status: 'Scheduled',
  driverFirstName: 'Paul',
  vehicle: { make: 'Toyota', model: 'Corolla', color: 'Grise', plateNumber: 'LT482CE' },
  position: { latitude: 3.8, longitude: 10.13, recordedAt: new Date().toISOString(), isLive: true, distanceToDestinationKm: 152.4 },
};

function mockApi(response: Response) {
  return vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) =>
    String(input).endsWith('/config.json') ? new Response('', { status: 404 }) : response.clone());
}

it('shows the driver, the car and the live distance', async () => {
  const fetchMock = mockApi(Response.json(trip));

  render(<TrackPage token="abc_123" locale="fr" />);

  expect(await screen.findByRole('heading', { name: 'Trajet avec Paul' })).toBeInTheDocument();
  expect(screen.getByRole('status')).toHaveTextContent('Position en direct');
  expect(screen.getByText("À 152,4 km de Yaoundé (à vol d'oiseau)")).toBeInTheDocument();
  expect(screen.getByText('LT482CE')).toBeInTheDocument();
  expect(fetchMock.mock.calls.some(([url]) => String(url) === 'http://localhost:5200/v1/shared/abc_123')).toBe(true);
});

it('says when the driver has not started yet', async () => {
  mockApi(Response.json({ ...trip, position: null }));

  render(<TrackPage token="abc" locale="en" />);

  expect(await screen.findByRole('status')).toHaveTextContent('The driver has not started sharing their position yet.');
});

it('explains an expired link', async () => {
  mockApi(new Response('{}', { status: 404 }));

  render(<TrackPage token="old" locale="fr" />);

  expect(await screen.findByText("Ce lien de suivi a expiré ou n'existe pas.")).toBeInTheDocument();
});
