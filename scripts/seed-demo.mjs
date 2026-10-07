#!/usr/bin/env node
// Fills a LOCAL API (development mode) with demo data, so the app has something to show.
//
//   node scripts/seed-demo.mjs                  # API on http://localhost:5200
//   node scripts/seed-demo.mjs http://host:5200
//
// Then sign in to the app with one of these numbers (development mode: the code is always 123456):
//   690 00 00 01  Ama       – verified passenger, booked on Paul's trip leaving soon
//   670 00 00 01  Paul      – verified driver
//   670 00 00 03  Mireille  – verified driver
//
// Safe to run several times: existing users, vehicles and trips are reused.
// Refuses to run against anything that is not in development mode (it relies on X-Dev-* headers).

const API = (process.argv[2] ?? 'http://localhost:5200').replace(/\/$/, '');
const CAMEROON_OFFSET_MS = 60 * 60 * 1000;

const CITIES = {
  Douala: [4.0511, 9.7679],
  Yaoundé: [3.848, 11.5021],
  Bafoussam: [5.4781, 10.4176],
  Kribi: [2.9404, 9.9101],
  Buea: [4.1527, 9.241],
};

const DRIVER_DOCS = ['NationalId', 'Selfie', 'DriverLicence', 'Insurance', 'VehicleRegistration'];
const PASSENGER_DOCS = ['NationalId', 'Selfie'];

const users = {
  paul: { phone: '+237670000001', firstName: 'Paul', lastName: 'Ngono', docs: DRIVER_DOCS,
    vehicle: { make: 'Toyota', model: 'Corolla', color: 'Grise', plateNumber: 'DM 001 CR', passengerSeats: 4 } },
  brice: { phone: '+237670000002', firstName: 'Brice', lastName: 'Kamga', docs: DRIVER_DOCS,
    vehicle: { make: 'Hyundai', model: 'Elantra', color: 'Noire', plateNumber: 'DM 002 CR', passengerSeats: 4 } },
  mireille: { phone: '+237670000003', firstName: 'Mireille', lastName: 'Essomba', docs: DRIVER_DOCS,
    vehicle: { make: 'Kia', model: 'Picanto', color: 'Rouge', plateNumber: 'DM 003 CR', passengerSeats: 3 } },
  ama: { phone: '+237690000001', firstName: 'Ama', lastName: 'Tchoua', docs: PASSENGER_DOCS },
};

/** Same identity the app's development login uses for a phone number. */
const headers = (user) => ({
  'X-Dev-User': `dev-${user.phone.slice(1)}`,
  'X-Dev-Phone': user.phone,
  'Content-Type': 'application/json',
});

async function call(user, method, path, body) {
  const response = await fetch(API + path, {
    method,
    headers: headers(user),
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`${method} ${path} → ${response.status} ${text}`);
  return text ? JSON.parse(text) : null;
}

/** A departure on day +offsetDays at hh:mm Cameroon time, as UTC ISO. */
function departure(offsetDays, hour, minute = 0) {
  const now = new Date(Date.now() + CAMEROON_OFFSET_MS);
  const local = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + offsetDays, hour, minute);
  return new Date(local - CAMEROON_OFFSET_MS).toISOString();
}

const place = (city, landmark) => ({ city, landmark, latitude: CITIES[city][0], longitude: CITIES[city][1] });

async function ensureUser(user) {
  try {
    await call(user, 'PUT', '/v1/me', {
      firstName: user.firstName, lastName: user.lastName, language: 'French',
    });
  } catch (e) {
    if (!String(e.message).includes('conflict.duplicate')) throw e;
    throw new Error(`${user.phone} already belongs to another account in this database. `
      + 'Reset the local database (docker compose down -v, then up -d) or change the numbers at the top of this script.');
  }
  const existing = await call(user, 'GET', '/v1/me/documents');
  for (const type of user.docs) {
    if (existing.some((d) => d.type === type && d.status === 'Accepted')) continue;
    const slot = await call(user, 'POST', '/v1/me/documents', { type, contentType: 'image/jpeg' });
    const expiresOn = ['DriverLicence', 'Insurance'].includes(type) ? '2028-12-31' : null;
    await call(user, 'POST', `/v1/me/documents/${slot.documentId}/submit`, { expiresOn });
  }
  if (user.vehicle) {
    const vehicles = await call(user, 'GET', '/v1/me/vehicles');
    user.vehicleId = vehicles[0]?.id ?? (await call(user, 'POST', '/v1/me/vehicles', user.vehicle)).id;
  }
  const profile = await call(user, 'GET', '/v1/me');
  console.log(`✓ ${user.firstName.padEnd(9)} ${user.phone}  passenger: ${profile.passenger.status}, driver: ${profile.driver.status}`);
}

async function ensureTrip(driver, trip) {
  const mine = await call(driver, 'GET', '/v1/me/trips');
  const same = mine.find((t) => t.origin.city === trip.origin.city && t.destination.city === trip.destination.city
    && Math.abs(new Date(t.departureAt) - new Date(trip.departureAt)) < 60_000);
  if (same) return same;
  return call(driver, 'POST', '/v1/trips', {
    vehicleId: driver.vehicleId, kind: 'Intercity', luggageAllowed: true,
    smokingAllowed: false, instantBooking: true, notes: null, seats: 3, ...trip,
  });
}

try {
  const health = await fetch(`${API}/health`);
  if (!health.ok) throw new Error(`health ${health.status}`);
} catch (e) {
  console.error(`The API is not reachable at ${API} (${e.message}). Start it first: dotnet run --project src/CocoRider.Api`);
  process.exit(1);
}

try {
  for (const user of Object.values(users)) await ensureUser(user);
} catch (e) {
  console.error(`✗ ${e.message}`);
  process.exit(1);
}

const { paul, brice, mireille, ama } = users;
const soon = new Date(Date.now() + 50 * 60_000).toISOString();
const trips = [
  [paul, { origin: place('Douala', 'Carrefour Ndokoti'), destination: place('Yaoundé', 'Total Mvan'), departureAt: soon, pricePerSeatXaf: 5000, notes: 'Départ à l\'heure, climatisation.' }],
  [paul, { origin: place('Douala', 'Carrefour Ndokoti'), destination: place('Yaoundé', 'Total Mvan'), departureAt: departure(1, 7), pricePerSeatXaf: 5000 }],
  [brice, { origin: place('Douala', 'Akwa, Total Joss'), destination: place('Yaoundé', 'Poste Centrale'), departureAt: departure(1, 14), pricePerSeatXaf: 6000, instantBooking: false }],
  [brice, { origin: place('Yaoundé', 'Mvan'), destination: place('Bafoussam', 'Marché A'), departureAt: departure(2, 8, 30), pricePerSeatXaf: 5500 }],
  [mireille, { origin: place('Douala', 'Bonamoussadi'), destination: place('Kribi', 'Plage de la Lobé'), departureAt: departure(2, 9), pricePerSeatXaf: 4000, seats: 2 }],
  [mireille, { origin: place('Douala', 'Bonapriso'), destination: place('Buea', 'Molyko'), departureAt: departure(3, 16), pricePerSeatXaf: 3000, seats: 2 }],
];

const created = [];
for (const [driver, trip] of trips) created.push(await ensureTrip(driver, trip));
console.log(`✓ ${created.length} trips (tomorrow and the next days, plus one leaving in under an hour)`);

// Ama is booked on the trip leaving soon: sign in as Paul to share the position, as Ama to follow it.
const bookings = await call(ama, 'GET', '/v1/me/bookings');
if (!bookings.some((b) => b.trip.id === created[0].id && ['Confirmed', 'Pending'].includes(b.status))) {
  await call(ama, 'POST', `/v1/trips/${created[0].id}/bookings`, { seats: 1, paymentMethod: 'MtnMobileMoney' });
}
console.log('✓ Ama booked on Paul\'s trip leaving soon');
console.log('\nSign in with 690 00 00 01 (Ama) or 670 00 00 01 (Paul); the code is 123456.');
