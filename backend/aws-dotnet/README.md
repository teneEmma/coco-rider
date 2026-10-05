# Coco Rider API (.NET 10)

The AWS backend described in [docs/architecture.md](../../docs/architecture.md).

```
src/CocoRider.Domain          business rules (no dependencies on AWS or the database)
src/CocoRider.Infrastructure  EF Core + PostgreSQL/PostGIS, S3, Rekognition, migrations
src/CocoRider.Api             ASP.NET Core minimal APIs, Cognito auth
tests/CocoRider.Tests         unit tests + API tests against a real PostGIS container
```

## Run locally

Requirements: .NET 10 SDK, Docker.

```bash
docker compose up -d                        # PostgreSQL + PostGIS on localhost:5432
dotnet run --project src/CocoRider.Api      # http://localhost:5200, migrations run on startup
```

In Development there is no Cognito: authenticate with headers, and uploads/checks are faked.

```bash
curl -X PUT http://localhost:5200/v1/me \
  -H 'X-Dev-User: user-1' -H 'X-Dev-Phone: +237690000001' -H 'Content-Type: application/json' \
  -d '{"firstName":"Ama","lastName":"Tchoua","language":"French"}'
```

Add `-H 'X-Dev-Groups: admin'` to call `/v1/admin/*`.

## Tests

```bash
dotnet test        # Docker must be running (the API tests start a PostGIS container)
```

## Database changes

```bash
dotnet tool restore
dotnet ef migrations add <Name> -p src/CocoRider.Infrastructure -s src/CocoRider.Infrastructure -o Persistence/Migrations
```

## Configuration

| Key | Meaning |
|---|---|
| `Policy:*` | cancellation window, commission, strikes, face match threshold (see `PlatformPolicy`) |
| `Verification:Passenger`, `Verification:Driver` | required document types per role |
| `Auth:Mode` | `Cognito` (AWS) or `Development` (headers; refused in Production) |
| `Storage:Mode` | `S3` or `Fake` |
| `Database:Host/Port/Username/Password/SslMode` or `ConnectionStrings:Postgres` | database |

In AWS these are environment variables set by the CDK stack (`infra/`), e.g. `Policy__CommissionRateBasisPoints=1000`.
