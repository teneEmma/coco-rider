# Coco Rider – architecture (MVP)

Carpooling for Cameroon: private drivers (and clandos) share the cost of intercity trips
(Douala ⇄ Yaoundé, Bafoussam, Buea…) and daily commutes inside a city.

## Decisions

| Topic | Decision |
|---|---|
| Mobile app | Flutter (Android + iOS), French and English |
| Websites | React: landing page in `web/landing`, admin dashboard in `web/admin`, both on S3 + CloudFront |
| Backend | C# / ASP.NET Core (.NET 10), one container on ECS Fargate (ARM) – `backend/aws-dotnet` |
| Database | PostgreSQL 16 + PostGIS on RDS (db.t4g.micro) |
| Auth | Amazon Cognito, sign-in with phone number + SMS code, or email + emailed code (sent through Amazon SES) |
| Documents | Private S3 bucket, automatic checks with Amazon Rekognition, admin review queue for doubtful cases |
| Infrastructure as code | AWS CDK (TypeScript) – `infra/` |
| Region | `eu-west-1` (Ireland) – see [Region](#region) |
| Payments | No money goes through the app yet: the passenger pays the driver (cash, MTN MoMo, Orange Money). The commission owed is recorded on each booking (0% while free) |
| Firebase | Only Cloud Messaging (push notifications); the old Firebase backend was removed |

## Architecture

```
 Flutter app ──┐                        ┌──────────── AWS (eu-west-1) ─────────────────────────────┐
 Admin (React) ┼─ HTTPS ─► API Gateway ─┼─► VPC link ─► ECS Fargate: CocoRider.Api (.NET, ARM)      │
               │           (HTTP API)   │                   │        │            │                │
               │                        │                   ▼        ▼            ▼                │
               └─ sign-in ─► Cognito ───┤         RDS PostgreSQL   S3 (documents)  Rekognition     │
                   (SMS code)           │         + PostGIS        ▲                               │
                                        │                          │ direct upload (pre-signed URL)│
                                        └──────────────────────────┼───────────────────────────────┘
                                                        Flutter app ┘
```

* The app signs in with Cognito and sends the **ID token** (it holds the verified phone number or email) as `Authorization: Bearer …`.
* Users who sign in by email type their phone number in their profile: it is stored as **not verified by SMS**
  (`phoneVerified: false`) and can be corrected later; an SMS-verified number cannot be changed. The API only
  trusts a token's phone number when `phone_number_verified` is true.
* Photos of documents never go through the API: the API returns a pre-signed S3 URL, the app uploads, then calls `submit`.
* Everything runs in public/isolated subnets **without a NAT Gateway or load balancer** (the two most common budget killers).

## Monthly cost estimate (eu-west-1, on-demand, MVP traffic)

| Item | ~USD/month |
|---|---|
| RDS PostgreSQL db.t4g.micro, 20 GB gp3, single-AZ, 7-day backups | 15 – 17 |
| Fargate ARM task, 0.25 vCPU / 0.5 GB, 24/7 | 7 – 8 |
| Public IPv4 address of the task | 3.65 |
| API Gateway HTTP API (first millions of requests) | 1 – 3 |
| CloudWatch logs (14 days), Secrets Manager, ECR, Cloud Map, S3 | 3 – 6 |
| CloudFront for the two websites (always-free tier: 1 TB/month) | 0 |
| Cognito (Essentials, free up to 10,000 monthly active users) | 0 |
| Rekognition (≈ 5 images per driver at $0.001) | < 5 |
| **Total without SMS** | **≈ 30 – 45** |

**SMS is the variable cost.** Every sign-in sends an SMS through Amazon SNS, billed per message at the
Cameroon rate (check the SNS pricing page; it is several US cents per message). Before launch:
leave the SNS SMS sandbox, set a monthly SMS spending limit, and compare with a local SMS provider
or WhatsApp OTP.

The stack creates an AWS Budget that emails you at 80% of $100 (actual) and 100% (forecast) –
set `budgetEmail` in `infra/cdk.json`.

Things **not** to turn on without checking the budget: NAT Gateway (~$35), Application Load Balancer
(~$18), Multi-AZ database (×2), Aurora, RDS Proxy, interface VPC endpoints (~$7 each).

## Region

The region does change the price, by roughly 5–25% for the same resources:

| Region | Price vs Ireland | Notes |
|---|---|---|
| `us-east-1` N. Virginia | ≈ 5–10% cheaper | Much further from Cameroon (higher latency) |
| **`eu-west-1` Ireland** | reference | Among the cheapest in Europe; Rekognition and Cognito available |
| `eu-west-3` Paris | ≈ 5–10% more | Rekognition is not offered there (as far as we know; check AWS's regional services list) |
| `af-south-1` Cape Town | ≈ 20–30% more | Opt-in region, fewer services (Rekognition missing as far as we know) |

Internet traffic from Cameroon mostly reaches the world through submarine cables landing in Europe,
so European regions are usually as fast as Cape Town. At this size the difference between Ireland and
Paris is only a few dollars; **Ireland wins because of the price and Rekognition**.

⚠️ Cameroon's personal data protection law (2024) regulates transfers of personal data abroad.
Ask a lawyer whether storing ID documents in Ireland requires a declaration or authorization.

## Business rules (implemented)

| Rule | Where | Setting |
|---|---|---|
| Free cancellation until 24 h before departure, then the passenger cannot cancel | `Booking.CancelByPassenger` | `Policy:CancellationWindowHours` |
| A pending request (not yet accepted by the driver) can always be withdrawn | `Booking.CancelByPassenger` | – |
| Driver cancelling inside the 24 h window with passengers booked → 1 strike | `TripEndpoints.CancelAsync` | – |
| Driver reports a passenger no-show after departure → 1 strike for the passenger | `BookingEndpoints.NoShowAsync` | – |
| 3 strikes within 90 days → suspended for 30 days | `User.AddStrike` | `Policy:MaxStrikes`, `StrikeWindowDays`, `SuspensionDays` |
| Commission recorded on each booking | `PlatformPolicy.CommissionFor` | `Policy:CommissionRateBasisPoints` (0 now; 1000 = 10%) |
| Seats are held while a request is pending; no overbooking even with simultaneous bookings | `Trip.ReserveSeats` + PostgreSQL `xmin` concurrency token | – |
| A request the driver has not answered by departure expires and frees its seats | `TripLifecycle` (every 5 min) | `Lifecycle:IntervalMinutes` |
| A trip the driver forgot to complete is closed 12 h after departure, so passengers can review | `Trip.AutoComplete` | `Policy:AutoCompleteAfterHours` |
| Phone numbers are revealed only once a booking is confirmed | trip/booking responses | – |
| Trip published at least 30 min before departure, max 100,000 FCFA per seat | `Trip.Publish` | `Policy:MinimumMinutesBeforeDeparture` |

## Verification

Each user has two statuses: **passenger** and **driver**. Required documents are configuration
(`Verification:Passenger`, `Verification:Driver`):

| Role | Default documents |
|---|---|
| Passenger | CNI + selfie |
| Driver | CNI + selfie + driving licence + insurance + carte grise |

Automatic checks when a document is submitted:
* **CNI, licence, insurance, carte grise** – Rekognition reads the text; the photo must contain the
  expected French/English words ("CARTE NATIONALE D'IDENTITÉ", "PERMIS DE CONDUIRE", "ASSURANCE",
  "CARTE GRISE"…). This filters out wrong or blurry photos; it does not prove authenticity.
* **Selfie** – Rekognition compares the face with the CNI photo (≥ 90% similarity, `Policy:FaceMatchThreshold`).
* Expiry dates (licence, insurance) are typed by the user; an expired document removes the verified status automatically.

Anything not accepted automatically goes to the admin queue (`GET /v1/admin/documents`), never rejected
by a machine. Reviews and strikes then adjust who stays on the platform.

## API (v1)

All endpoints require a Cognito ID token except `/health`. Errors are RFC 7807 JSON with a stable
`code` (e.g. `booking.cancellation_window_closed`) that the app translates.

| Method | Path | Who |
|---|---|---|
| GET/PUT | `/v1/me` | profile (PUT creates it after sign-up) + verification status per role |
| GET/POST | `/v1/me/documents` | list / get an upload URL |
| POST | `/v1/me/documents/{id}/submit` | run the automatic checks |
| GET/POST/DELETE | `/v1/me/vehicles[/{id}]` | driver's vehicles |
| POST | `/v1/trips` | publish (verified drivers) |
| GET | `/v1/trips/search?fromCity=&toCity=` or `?fromLat=&fromLng=&toLat=&toLng=&radiusKm=`, optional `&date=&seats=` | search (upcoming trips; no date = all, soonest first) |
| GET | `/v1/trips/{id}` | details (+ bookings for the driver) |
| POST | `/v1/trips/{id}/cancel`, `/complete` | driver |
| GET | `/v1/me/trips?past=` | driver's trips |
| POST | `/v1/trips/{id}/bookings` | book (verified passengers) |
| GET | `/v1/me/bookings` | passenger's bookings |
| POST | `/v1/bookings/{id}/accept`, `/reject`, `/no-show` | driver |
| POST | `/v1/bookings/{id}/cancel` | passenger |
| POST | `/v1/bookings/{id}/reviews` | driver or passenger, after the trip |
| GET | `/v1/users/{id}`, `/v1/users/{id}/reviews` | public profile and reviews |
| GET | `/v1/admin/stats`, `/v1/admin/documents`, `/v1/admin/users?query=` | admin group |
| POST | `/v1/admin/documents/{id}/approve`, `/reject` | admin group |
| POST | `/v1/admin/users/{id}/suspend`, `/unsuspend` | admin group |

## Push notifications (Firebase Cloud Messaging)

The app registers its FCM token after sign-in (`PUT /v1/me/devices`) and removes it on sign-out.
The API queues notifications in memory and a background service sends them, in the user's language,
to all their phones; tokens Firebase reports as invalid are deleted.

| Event | Who is notified |
|---|---|
| New booking / new booking request | Driver |
| Passenger cancelled | Driver |
| Request accepted / declined / expired | Passenger |
| Trip cancelled by the driver | Passengers |
| Trip completed ("rate your trip") | Passengers |
| Document approved / refused by an admin | The user |
| New chat message | The other participant |

Tapping a notification opens the trip. FCM is free; without a service account key the API only
logs the notifications.

## Chat

One conversation per booking, between the passenger and the driver (`/v1/bookings/{id}/messages`,
inbox at `/v1/me/conversations`). Messages up to 1,000 characters; writing is allowed while the
booking is pending or confirmed and after the trip, read-only once declined, cancelled or expired.
The app polls for new messages every 5 s while a chat is open; otherwise a push notification
announces them. Received messages are marked as read when the conversation is opened.

## Live trip tracking and trip sharing

- **Driver:** from 1 h before departure to 12 h after, "Share my position" sends the GPS position
  every 15 s while the app is open (`PUT /v1/trips/{id}/position`). The first position notifies the
  confirmed passengers ("Paul est en route"). Sharing with the screen off is planned later.
- **Passengers** (confirmed bookings only) see a map refreshed every 10 s (`GET /v1/trips/{id}/position`):
  live or "last position at…" after 2 min without update, and the distance to the destination as the crow flies.
- **Relatives:** a passenger creates a link (`POST /v1/trips/{id}/shares`) and sends it by WhatsApp/SMS.
  It opens `https://<landing>/suivi/{token}` without an account: driver's first name, car, plate, live map.
  Links are unguessable (256-bit tokens) and expire 24 h after departure.
- **Privacy:** only the latest position is stored, never a history; it is deleted when the trip ends.
- **Maps:** OpenStreetMap tiles (free, no API key). OSM's tile usage policy suits the MVP; with real
  traffic, switch to a paid tile provider (e.g. MapTiler, Stadia) by changing one URL.

## Data model

`users` (phone, email, name, language, passenger/driver status, suspension) · `strikes` ·
`documents` (type, S3 key, status, expiry, review note) · `vehicles` · `trips` (origin/destination
city + landmark + PostGIS point, departure, seats, price, preferences) · `bookings` (seats, status,
payment method, total, commission) · `reviews` (1–5, one per author per booking) · `device_tokens` (FCM token per phone) · `messages` (booking chat, read receipts) ·
`trip_positions` (latest driver position per running trip, no history) · `trip_shares` (links for relatives).

## Roadmap

1. ~~Flutter app → new backend~~ – done: Cognito sign-in/sign-up by SMS code, profile, documents, search, booking, publishing, my rides, reviews.
2. ~~Admin dashboard~~ (`web/admin`) and ~~landing page~~ (`web/landing`) – done.
3. Custom domain (e.g. cocorider.cm) for the websites and the API.
4. ~~Push notifications~~ – done with Firebase Cloud Messaging (see below).
5. ~~In-app chat~~ and ~~live trip tracking / trip sharing~~ – done (see above). Next for tracking:
   sharing with the screen off (background location permission, needs store review), road distance and ETA.
6. **Payments**: pick a Mobile Money aggregator; collect the commission (driver prepaid credit or passenger fee); yearly subscriptions.
7. CI/CD (GitHub Actions: tests + `cdk deploy`).
