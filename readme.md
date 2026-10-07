# on-go (code name: Coco Rider)

Carpooling app for Cameroon: private drivers and clandos share the cost of intercity trips and city commutes.

> **Brand:** the app is called **on-go** (logo, colors and Inter font from the Figma "on-go brand
> essentials"). "Coco Rider" remains the code name: folders, packages (`coco_rider`, `CocoRider.*`),
> the AWS stack and the database keep it. The on-go name has not been legally cleared yet.

| Folder | What |
|---|---|
| `app/` | Flutter mobile app (Android, iOS) |
| `backend/aws-dotnet/` | New backend: C# / ASP.NET Core API, PostgreSQL + PostGIS |
| `web/admin/`, `web/landing/` | React admin dashboard and landing page |
| `infra/` | AWS infrastructure (CDK, TypeScript) |
| `docs/architecture.md` | Architecture, costs, business rules, API |

**Start here:** [docs/getting-started.md](docs/getting-started.md) – run everything locally, then deploy to AWS.
Demo data for local runs: `node scripts/seed-demo.mjs`.
