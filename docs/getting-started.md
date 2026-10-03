# Getting started: run Coco Rider on your computer, then deploy it to AWS

This guide has three parts:

1. [Get the code and install the tools](#1-get-the-code-and-install-the-tools)
2. [Run everything locally](#2-run-everything-locally) – no AWS account, no SMS, no cost
3. [Configure AWS and deploy](#3-configure-aws-and-deploy)

What runs where:

| Part | Folder | Local address |
|---|---|---|
| Database (PostgreSQL + PostGIS, in Docker) | `backend/aws-dotnet` | `localhost:5432` |
| API (.NET) | `backend/aws-dotnet` | http://localhost:5200 |
| Admin dashboard (React) | `web/admin` | http://localhost:5173 |
| Landing page + shared trips (React) | `web/landing` | http://localhost:5174 |
| Mobile app (Flutter) | `app` | Android emulator, iOS simulator, phone or Chrome |

---

## 1. Get the code and install the tools

### The code

The work is on the branch `claude/cameroun-carpooling-app-arjs50`.

- **If it is on GitHub:** `git fetch origin && git checkout claude/cameroun-carpooling-app-arjs50`
- **From the backup file** (`coco-rider-aws.bundle`), inside your existing clone of the repository:

  ```bash
  git fetch /path/to/coco-rider-aws.bundle claude/cameroun-carpooling-app-arjs50:claude/cameroun-carpooling-app-arjs50
  git checkout claude/cameroun-carpooling-app-arjs50
  git push -u origin claude/cameroun-carpooling-app-arjs50   # optional: publish it to GitHub
  ```

### Tools

| Tool | Version | Used for |
|---|---|---|
| Git | any recent | |
| Docker Desktop | recent, **running** | the local database; building the API image when deploying |
| .NET SDK | **10** | the API and its tests |
| Node.js | **22 LTS** (20+ works) | admin dashboard, landing page, demo data, AWS CDK |
| Flutter | **3.47 or newer** (stable) | the mobile app |
| Android Studio | with an Android emulator | running the app on Android |
| Xcode (Mac only) | latest | running the app on iOS |
| AWS CLI v2 | | part 3 only |

Check: `docker info`, `dotnet --list-sdks`, `node -v`, `flutter doctor`.

---

## 2. Run everything locally

Locally the API runs in **development mode**: sign-in has no SMS (any phone number, code
**123456**), photos are stored in memory, document checks always pass, and push notifications are
only written in the API logs. Nothing calls AWS.

Open one terminal per step.

### 2.1 Database and API

```bash
cd backend/aws-dotnet
docker compose up -d                       # PostgreSQL + PostGIS
dotnet run --project src/CocoRider.Api     # http://localhost:5200 – creates the tables on start
```

Check http://localhost:5200/health → `Healthy`.

### 2.2 Demo data (optional but recommended)

```bash
node scripts/seed-demo.mjs        # from the repository root, while the API is running
```

It creates verified users, vehicles and trips (one leaves in under an hour, the others in the next
days) and books Ama on Paul's trip. Sign in with:

| Phone (type without +237) | Who | What to try |
|---|---|---|
| `690000001` | Ama, verified passenger | search Douala → Yaoundé tomorrow, book, chat, follow Paul live |
| `670000001` | Paul, verified driver | his trips, accept passengers, share his position |
| `670000003` | Mireille, verified driver | women-only trip |
| any other number | a new user | full sign-up: profile, documents, then search/publish |

Running it again does not duplicate anything. To start from an empty database:
`docker compose down -v && docker compose up -d` (in `backend/aws-dotnet`).

### 2.3 Admin dashboard

```bash
cd web/admin
npm ci
npm run dev        # http://localhost:5173
```

Any phone number signs you in as an admin locally. You will see the statistics, the users
(search, suspend) and the review queue. The queue is empty locally because development mode accepts
every document automatically; in AWS, documents Rekognition is unsure about land there.

### 2.4 Landing page and shared trips

```bash
cd web/landing
npm ci
npm run dev        # http://localhost:5174
```

Links created with "Share with a relative" in the app open here: http://localhost:5174/suivi/…
(the map background needs internet access for the OpenStreetMap tiles).

### 2.5 Mobile app

```bash
cd app
flutter pub get
```

Then, depending on the device:

| Device | Command |
|---|---|
| Android emulator | `flutter run` (the emulator reaches your computer at `10.0.2.2`, the default) |
| iOS simulator (Mac) | `flutter run --dart-define=COCO_API_URL=http://localhost:5200` |
| Chrome | `flutter run -d chrome --dart-define=COCO_API_URL=http://localhost:5200` |
| A real phone | see below |

**On a real phone** (same Wi-Fi as the computer), the API must listen on the network and give the
phone upload links it can reach. Replace `192.168.1.20` by your computer's IP address:

```bash
# backend/aws-dotnet
Storage__FakeBaseUrl=http://192.168.1.20:5200 dotnet run --project src/CocoRider.Api --urls http://0.0.0.0:5200
# app
flutter run --dart-define=COCO_API_URL=http://192.168.1.20:5200
```

On Windows (PowerShell): `$env:Storage__FakeBaseUrl="http://192.168.1.20:5200"` before `dotnet run`,
and allow port 5200 in the Windows firewall.

To try live tracking: sign in as Paul on one device and as Ama on another (for example the emulator
and Chrome). Paul opens his trip leaving soon → **Partager ma position**; Ama opens **Coco trajets** →
**Suivre en direct**. The emulator's position can be changed in its *Extended controls → Location*.

### 2.6 Tests

```bash
cd backend/aws-dotnet && dotnet test     # needs Docker (starts a throw-away database)
cd infra && npm ci && npm test
cd web/admin && npm test
cd web/landing && npm test
cd app && flutter test
```

### Troubleshooting

- **`Cannot connect to the Docker daemon`** – start Docker Desktop.
- **Port already in use** – another copy is running; stop it, or change the port
  (`--urls http://localhost:5300` for the API, then `COCO_API_URL` accordingly).
- **Android build errors about Gradle / Android Gradle Plugin / Kotlin versions** – the Android build
  files were updated to the Flutter 3.47 template but could not be built in the environment where they
  were written. Run `flutter upgrade`, then `flutter clean && flutter pub get`; if it still fails,
  `flutter analyze` and the Gradle error usually name the version to change in
  `app/android/settings.gradle.kts`.
- **`flutter analyze` shows errors in `lib/teste.dart`** – an old scratch file not used by the app;
  it can be deleted.
- **The app shows "profile not found" after reset** – the database was emptied; sign in again.

---

## 3. Configure AWS and deploy

Expected cost: about **$30–45 per month** plus SMS (see `docs/architecture.md`). The stack creates a
budget alert at $100/month if you set your e-mail (step 3.2).

### 3.1 AWS account and credentials

1. Secure the root user of the account with **MFA**, and do not use it day to day.
2. Create a user for deployments: in **IAM Identity Center**, a user with the
   `AdministratorAccess` permission set (simplest), or an IAM user with that policy.
3. Install the **AWS CLI v2**, then sign in:

   ```bash
   aws configure sso          # Identity Center (recommended), or: aws configure (access keys)
   aws sts get-caller-identity   # shows the account id you are deploying to
   ```

   With SSO profiles, add `--profile <name>` to the commands below or `export AWS_PROFILE=<name>`.

### 3.2 Settings

In `infra/cdk.json`:

- `"budgetEmail": "you@example.com"` – receives the cost alerts.
- `"region": "eu-west-1"` (Ireland, recommended – see the region table in `docs/architecture.md`).

### 3.3 First deployment

Docker must be running (the API image is built for ARM during the deployment; on an Intel/AMD
computer Docker emulates ARM, which makes this step slower).

```bash
(cd web/admin && npm ci && npm run build)
(cd web/landing && npm ci && npm run build)
cd infra
npm ci
npx cdk bootstrap aws://<ACCOUNT_ID>/eu-west-1    # once per account and region
npx cdk diff                                      # what will be created
npx cdk deploy                                    # 20–30 minutes the first time
```

Write down the outputs: `ApiUrl`, `AdminUrl`, `LandingUrl`, `UserPoolId`, `MobileClientId`,
`AdminClientId`, `FcmSecretName`, `ApiClusterName`, `ApiServiceName`.
Check `<ApiUrl>/health` → `Healthy`.

### 3.4 After the first deployment

1. **SMS (sign-in codes).** New AWS accounts are in the SNS SMS *sandbox*: codes only reach phone
   numbers you verify first. In the console: **Amazon SNS → Text messaging (SMS)**:
   - add your own number under *Sandbox destination phone numbers* to test right away;
   - then *Exit SMS sandbox* (a support request, usually approved within a day or two) and set a
     monthly SMS **spending limit**.
2. **First admin.** Sign up once in the mobile app with your phone number (step 3.5), then:

   ```bash
   aws cognito-idp list-users --user-pool-id <UserPoolId> --filter 'phone_number = "+2376XXXXXXXX"'
   aws cognito-idp admin-add-user-to-group --user-pool-id <UserPoolId> --username <Username from above> --group-name admin
   ```

   Then sign in at `AdminUrl` with the same number.
3. **Push notifications.** Firebase console (project `coco-rider-dev`) → Project settings →
   Service accounts → *Generate new private key*. Then:

   ```bash
   aws secretsmanager put-secret-value --secret-id coco-rider/fcm-service-account --secret-string file://service-account.json
   aws ecs update-service --cluster <ApiClusterName> --service <ApiServiceName> --force-new-deployment
   rm service-account.json      # do not keep the key on disk or commit it
   ```

   For iOS, also upload an APNs key in Firebase → Project settings → Cloud Messaging.

### 3.5 Run the app against AWS

```bash
cd app
flutter run \
  --dart-define=COCO_API_URL=<ApiUrl> \
  --dart-define=COCO_COGNITO_REGION=eu-west-1 \
  --dart-define=COCO_COGNITO_CLIENT_ID=<MobileClientId>
```

Sign-in now sends a real SMS, document photos go to S3 and are checked by Rekognition, and doubtful
ones appear in the admin dashboard.

### 3.6 Updating and removing

- After code changes: rebuild the two websites if they changed, then `npx cdk deploy` again.
- `npx cdk destroy` removes the stack. To protect your data, the database is kept as a final
  **snapshot**, and the user pool, documents bucket and Firebase secret are **kept**: delete them by
  hand in the console if you really want everything gone (the database also has deletion protection,
  to be turned off first).
