# Coco Rider

Carpooling app for Cameroon: private drivers and clandos share the cost of intercity trips and city commutes.

| Folder | What |
|---|---|
| `app/` | Flutter mobile app (Android, iOS) |
| `backend/aws-dotnet/` | New backend: C# / ASP.NET Core API, PostgreSQL + PostGIS |
| `web/admin/`, `web/landing/` | React admin dashboard and landing page |
| `infra/` | AWS infrastructure (CDK, TypeScript) |
| `docs/architecture.md` | Architecture, costs, business rules, API |

**Start here:** [docs/getting-started.md](docs/getting-started.md) – run everything locally, then deploy to AWS.
Demo data for local runs: `node scripts/seed-demo.mjs`.
