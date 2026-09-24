# Coco Rider admin dashboard (React)

Review queue for identity documents, users (search, suspend), and key numbers. French/English.

```bash
npm ci
npm run dev     # http://localhost:5173 – proxies /api to the local .NET API on :5200
npm test
npm run build   # dist/ is deployed by the CDK stack (infra/)
```

Locally, sign-in has no SMS: any phone number logs you in as an admin (development mode of the API).
In AWS the stack writes `/config.json` (API URL, Cognito pool and client), and admins sign in with
their phone number and an SMS code. Only members of the Cognito `admin` group are let in.
