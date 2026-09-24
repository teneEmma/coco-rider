# Coco Rider infrastructure (AWS CDK)

One stack (`CocoRider`) with everything the API needs: VPC without NAT, RDS PostgreSQL, S3 documents
bucket, Cognito user pool (phone + SMS), ECS Fargate service, API Gateway HTTP API, monthly budget.
Costs and design choices: [docs/architecture.md](../docs/architecture.md).

## First deployment

Requirements: Node 20+, Docker (the API image is built for ARM during `cdk deploy`), AWS credentials.

```bash
npm ci
# optional: set "budgetEmail" in cdk.json to receive cost alerts
npx cdk bootstrap aws://<ACCOUNT_ID>/eu-west-1   # once per account/region
npx cdk deploy
```

The outputs give the API URL, the Cognito user pool and client ids for the app and the dashboard.

After the first deployment:
1. **SMS**: in Amazon SNS, request to leave the SMS sandbox and set a monthly SMS spending limit, otherwise sign-in codes only reach verified numbers.
2. **Admins**: add dashboard users to the `admin` Cognito group.
3. **PostGIS** is enabled by the first database migration (the RDS master user is allowed to create it).

## Everyday commands

```bash
npm test          # checks the cost guardrails (no NAT, no load balancer, small instances…)
npx cdk diff      # what a deployment would change
npx cdk deploy    # also rebuilds and redeploys the API image
```

To use another region: `npx cdk deploy -c region=eu-west-3` (see the region table in the architecture doc first).
