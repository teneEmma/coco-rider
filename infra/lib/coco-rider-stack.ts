import * as path from 'path';
import {
  CfnOutput, Duration, RemovalPolicy, SecretValue, Stack, StackProps,
  aws_apigatewayv2 as apigw,
  aws_apigatewayv2_integrations as integrations,
  aws_budgets as budgets,
  aws_cognito as cognito,
  aws_ec2 as ec2,
  aws_ecr_assets as ecrAssets,
  aws_ecs as ecs,
  aws_iam as iam,
  aws_logs as logs,
  aws_rds as rds,
  aws_s3 as s3,
  aws_secretsmanager as secretsmanager,
  aws_servicediscovery as sd,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { StaticSite } from './static-site';

export interface CocoRiderStackProps extends StackProps {
  /** Receives the budget alerts at 80% and 100% of the monthly budget. Empty = no budget. */
  readonly budgetEmail?: string;
  readonly monthlyBudgetUsd: number;
}

const API_PORT = 8080;

/**
 * The whole MVP backend, sized for a budget under $100/month:
 * - no NAT Gateway: the API task runs in a public subnet with a public IP, but only accepts
 *   traffic from the API Gateway VPC link; the database lives in isolated subnets;
 * - no load balancer: API Gateway (HTTP API) reaches the container through Cloud Map;
 * - one small ARM (Graviton) Fargate task and one db.t4g.micro PostgreSQL instance.
 */
export class CocoRiderStack extends Stack {
  constructor(scope: Construct, id: string, props: CocoRiderStackProps) {
    super(scope, id, props);

    // ---------- Network ----------
    const vpc = new ec2.Vpc(this, 'Vpc', {
      maxAzs: 2,
      natGateways: 0,
      subnetConfiguration: [
        { name: 'public', subnetType: ec2.SubnetType.PUBLIC, cidrMask: 24 },
        { name: 'data', subnetType: ec2.SubnetType.PRIVATE_ISOLATED, cidrMask: 24 },
      ],
      // Free: S3 traffic (document photos) stays inside AWS.
      gatewayEndpoints: { S3: { service: ec2.GatewayVpcEndpointAwsService.S3 } },
    });

    // ---------- Database: PostgreSQL 16 + PostGIS ----------
    const dbSecurityGroup = new ec2.SecurityGroup(this, 'DatabaseSg', { vpc, description: 'PostgreSQL' });
    const database = new rds.DatabaseInstance(this, 'Database', {
      engine: rds.DatabaseInstanceEngine.postgres({ version: rds.PostgresEngineVersion.VER_16 }),
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T4G, ec2.InstanceSize.MICRO),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [dbSecurityGroup],
      databaseName: 'cocorider',
      credentials: rds.Credentials.fromGeneratedSecret('cocorider'),
      allocatedStorage: 20,
      maxAllocatedStorage: 50,
      storageType: rds.StorageType.GP3,
      storageEncrypted: true,
      // Single-AZ keeps the cost at ~$15/month. Switch to multiAz when the business depends on uptime (x2 cost).
      multiAz: false,
      backupRetention: Duration.days(7),
      deletionProtection: true,
      removalPolicy: RemovalPolicy.SNAPSHOT,
      publiclyAccessible: false,
      parameters: { 'rds.force_ssl': '1' },
    });

    // ---------- Identity documents (private) ----------
    const documents = new s3.Bucket(this, 'Documents', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      versioned: false,
      removalPolicy: RemovalPolicy.RETAIN,
      lifecycleRules: [
        // Uploads that were started but never submitted.
        { abortIncompleteMultipartUploadAfter: Duration.days(1) },
      ],
    });

    // ---------- Authentication: phone number + SMS code ----------
    const userPool = new cognito.UserPool(this, 'Users', {
      userPoolName: 'coco-rider-users',
      featurePlan: cognito.FeaturePlan.ESSENTIALS,
      selfSignUpEnabled: true,
      signInAliases: { phone: true },
      autoVerify: { phone: true },
      signInPolicy: { allowedFirstAuthFactors: { password: true, smsOtp: true } },
      standardAttributes: { phoneNumber: { required: true, mutable: false } },
      accountRecovery: cognito.AccountRecovery.PHONE_ONLY_WITHOUT_MFA,
      mfa: cognito.Mfa.OFF,
      removalPolicy: RemovalPolicy.RETAIN,
    });

    new cognito.CfnUserPoolGroup(this, 'AdminGroup', {
      userPoolId: userPool.userPoolId,
      groupName: 'admin',
      description: 'Access to the admin dashboard and /v1/admin endpoints',
    });

    const clientDefaults: cognito.UserPoolClientOptions = {
      generateSecret: false,
      authFlows: { user: true, userSrp: true },
      preventUserExistenceErrors: true,
      idTokenValidity: Duration.hours(1),
      accessTokenValidity: Duration.hours(1),
      refreshTokenValidity: Duration.days(90),
    };
    const mobileClient = userPool.addClient('MobileApp', { ...clientDefaults, userPoolClientName: 'mobile-app' });
    const adminClient = userPool.addClient('AdminDashboard', {
      ...clientDefaults,
      userPoolClientName: 'admin-dashboard',
      refreshTokenValidity: Duration.days(1),
    });

    // ---------- Push notifications (Firebase Cloud Messaging) ----------
    // Paste the Firebase service account key (JSON) into this secret, then restart the service.
    // Until then the API only logs notifications.
    const fcmServiceAccount = new secretsmanager.Secret(this, 'FcmServiceAccount', {
      secretName: 'coco-rider/fcm-service-account',
      description: 'Firebase service account key (JSON) used by the API to send push notifications',
      secretStringValue: SecretValue.unsafePlainText('{}'),
      removalPolicy: RemovalPolicy.RETAIN,
    });

    // ---------- Websites: admin dashboard and landing page (also shows shared trips at /suivi/{token}) ----------
    const webDir = path.join(__dirname, '../../web');
    const landing = new StaticSite(this, 'Landing', { buildDir: path.join(webDir, 'landing/dist') });
    const admin = new StaticSite(this, 'Admin', { buildDir: path.join(webDir, 'admin/dist') });

    // ---------- API container ----------
    const cluster = new ecs.Cluster(this, 'Cluster', {
      vpc,
      defaultCloudMapNamespace: { name: 'coco-rider.internal', vpc },
    });

    const taskDefinition = new ecs.FargateTaskDefinition(this, 'ApiTask', {
      cpu: 256,
      memoryLimitMiB: 512,
      runtimePlatform: {
        cpuArchitecture: ecs.CpuArchitecture.ARM64,
        operatingSystemFamily: ecs.OperatingSystemFamily.LINUX,
      },
    });

    const dbSecret = database.secret!;
    taskDefinition.addContainer('api', {
      // Built from backend/aws-dotnet and pushed to ECR by "cdk deploy".
      image: ecs.ContainerImage.fromAsset(path.join(__dirname, '../../backend/aws-dotnet'), {
        platform: ecrAssets.Platform.LINUX_ARM64,
      }),
      portMappings: [{ containerPort: API_PORT, name: 'http' }],
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: 'api',
        logRetention: logs.RetentionDays.TWO_WEEKS,
      }),
      environment: {
        ASPNETCORE_ENVIRONMENT: 'Production',
        Auth__Mode: 'Cognito',
        Auth__Region: this.region,
        Auth__UserPoolId: userPool.userPoolId,
        Auth__ClientIds__0: mobileClient.userPoolClientId,
        Auth__ClientIds__1: adminClient.userPoolClientId,
        Storage__Mode: 'S3',
        Storage__DocumentsBucket: documents.bucketName,
        Database__Name: 'cocorider',
        Database__MigrateOnStartup: 'true',
        Tracking__PublicBaseUrl: landing.url,
      },
      secrets: {
        Database__Host: ecs.Secret.fromSecretsManager(dbSecret, 'host'),
        Database__Port: ecs.Secret.fromSecretsManager(dbSecret, 'port'),
        Database__Username: ecs.Secret.fromSecretsManager(dbSecret, 'username'),
        Database__Password: ecs.Secret.fromSecretsManager(dbSecret, 'password'),
        Notifications__FcmServiceAccountJson: ecs.Secret.fromSecretsManager(fcmServiceAccount),
      },
    });

    documents.grantReadWrite(taskDefinition.taskRole);
    taskDefinition.taskRole.addToPrincipalPolicy(new iam.PolicyStatement({
      actions: ['rekognition:DetectText', 'rekognition:CompareFaces'],
      resources: ['*'],
    }));

    const vpcLinkSecurityGroup = new ec2.SecurityGroup(this, 'VpcLinkSg', { vpc, description: 'API Gateway VPC link' });
    const serviceSecurityGroup = new ec2.SecurityGroup(this, 'ApiSg', { vpc, description: 'API container' });
    serviceSecurityGroup.addIngressRule(vpcLinkSecurityGroup, ec2.Port.tcp(API_PORT), 'Only API Gateway');
    dbSecurityGroup.addIngressRule(serviceSecurityGroup, ec2.Port.tcp(5432), 'API container');

    const service = new ecs.FargateService(this, 'ApiService', {
      cluster,
      taskDefinition,
      desiredCount: 1,
      // Public IP instead of a NAT Gateway (~$35/month) to reach ECR, Secrets Manager, Cognito and Rekognition.
      assignPublicIp: true,
      vpcSubnets: { subnetType: ec2.SubnetType.PUBLIC },
      securityGroups: [serviceSecurityGroup],
      circuitBreaker: { rollback: true },
      // With a single task, allow a short gap during deployments instead of paying for a second one.
      minHealthyPercent: 0,
      maxHealthyPercent: 100,
      cloudMapOptions: {
        name: 'api',
        dnsRecordType: sd.DnsRecordType.SRV,
        containerPort: API_PORT,
      },
    });

    // ---------- Public entry point: API Gateway HTTP API ----------
    const vpcLink = new apigw.VpcLink(this, 'VpcLink', {
      vpc,
      subnets: { subnetType: ec2.SubnetType.PUBLIC },
      securityGroups: [vpcLinkSecurityGroup],
    });

    const httpApi = new apigw.HttpApi(this, 'HttpApi', {
      apiName: 'coco-rider-api',
      createDefaultStage: false,
      defaultIntegration: new integrations.HttpServiceDiscoveryIntegration('Api', service.cloudMapService!, { vpcLink }),
      // The mobile app is not a browser; only the websites need CORS
      // (admin dashboard, and the landing page for shared trips).
      corsPreflight: {
        allowOrigins: [admin.url, landing.url],
        allowMethods: [apigw.CorsHttpMethod.ANY],
        allowHeaders: ['authorization', 'content-type'],
        maxAge: Duration.hours(1),
      },
    });
    new apigw.HttpStage(this, 'DefaultStage', {
      httpApi,
      stageName: '$default',
      autoDeploy: true,
      // Caps abuse (and the bill) until real traffic numbers are known.
      throttle: { rateLimit: 50, burstLimit: 100 },
    });

    // ---------- Cost guardrail ----------
    if (props.budgetEmail) {
      const subscribers = [{ subscriptionType: 'EMAIL', address: props.budgetEmail }];
      new budgets.CfnBudget(this, 'MonthlyBudget', {
        budget: {
          budgetName: 'coco-rider-monthly',
          budgetType: 'COST',
          timeUnit: 'MONTHLY',
          budgetLimit: { amount: props.monthlyBudgetUsd, unit: 'USD' },
        },
        notificationsWithSubscribers: [80, 100].map((threshold) => ({
          notification: {
            notificationType: threshold === 100 ? 'FORECASTED' : 'ACTUAL',
            comparisonOperator: 'GREATER_THAN',
            threshold,
            thresholdType: 'PERCENTAGE',
          },
          subscribers,
        })),
      });
    }

    landing.publish({ apiUrl: httpApi.apiEndpoint });
    admin.publish({
      apiUrl: httpApi.apiEndpoint,
      authMode: 'cognito',
      region: this.region,
      userPoolId: userPool.userPoolId,
      clientId: adminClient.userPoolClientId,
    });

    new CfnOutput(this, 'ApiUrl', { value: httpApi.apiEndpoint });
    new CfnOutput(this, 'UserPoolId', { value: userPool.userPoolId });
    new CfnOutput(this, 'MobileClientId', { value: mobileClient.userPoolClientId });
    new CfnOutput(this, 'AdminClientId', { value: adminClient.userPoolClientId });
    new CfnOutput(this, 'DocumentsBucket', { value: documents.bucketName });
    new CfnOutput(this, 'FcmSecretName', { value: fcmServiceAccount.secretName });
    new CfnOutput(this, 'AdminUrl', { value: admin.url });
    new CfnOutput(this, 'LandingUrl', { value: landing.url });
  }
}
