# Coco Rider infrastructure (AWS CDK)

One stack (`CocoRider`) with everything the API needs: VPC without NAT, RDS PostgreSQL, S3 documents
bucket, Cognito user pool (phone + SMS code, or email + emailed code when `senderEmail` is set), ECS Fargate service, API Gateway HTTP API, monthly budget.
Costs and design choices: [docs/architecture.md](../docs/architecture.md).
Step-by-step guide (AWS account, credentials, first admin, SMS sandbox): [docs/getting-started.md](../docs/getting-started.md).

## First deployment

Requirements: Node 20+, Docker (the API image is built for ARM during `cdk deploy`), AWS credentials.

```bash
(cd ../web/admin && npm ci && npm run build)
(cd ../web/landing && npm ci && npm run build)
npm ci
# optional: set "budgetEmail" in cdk.json to receive cost alerts
npx cdk bootstrap aws://<ACCOUNT_ID>/eu-west-1   # once per account/region
npx cdk deploy
```

The outputs give the API URL, the admin dashboard and landing page URLs, and the Cognito ids for the app.

After the first deployment:
1. **SMS**: in Amazon SNS, request to leave the SMS sandbox and set a monthly SMS spending limit, otherwise sign-in codes only reach verified numbers.
2. **Admins**: add dashboard users to the `admin` Cognito group.
3. **PostGIS** is enabled by the first database migration (the RDS master user is allowed to create it).
4. **Push notifications**: in the Firebase console (project `coco-rider-dev`) → Project settings → Service
   accounts → *Generate new private key*. Paste the whole JSON file into the Secrets Manager secret
   `coco-rider/fcm-service-account` (output `FcmSecretName`), then restart the API:
   `aws ecs update-service --cluster <ApiClusterName> --service <ApiServiceName> --force-new-deployment`
   (both names are stack outputs).
   For iOS, also upload an APNs key in Firebase → Project settings → Cloud Messaging.

## Everyday commands

```bash
npm test          # checks the cost guardrails (no NAT, no load balancer, small instances…)
npx cdk diff      # what a deployment would change
npx cdk deploy    # rebuilds the API image and re-uploads web/*/dist (build them first)
```

To use another region: `npx cdk deploy -c region=eu-west-3` (see the region table in the architecture doc first).
