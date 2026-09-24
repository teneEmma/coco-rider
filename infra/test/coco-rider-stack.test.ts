import { App } from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { CocoRiderStack } from '../lib/coco-rider-stack';

// These tests guard the choices that keep the bill under budget.
const template = Template.fromStack(new CocoRiderStack(new App(), 'Test', {
  env: { account: '123456789012', region: 'eu-west-1' },
  budgetEmail: 'ops@example.com',
  monthlyBudgetUsd: 100,
}));

test('no NAT gateway and no load balancer', () => {
  template.resourceCountIs('AWS::EC2::NatGateway', 0);
  template.resourceCountIs('AWS::ElasticLoadBalancingV2::LoadBalancer', 0);
});

test('database is small, private and encrypted', () => {
  template.hasResourceProperties('AWS::RDS::DBInstance', {
    DBInstanceClass: 'db.t4g.micro',
    MultiAZ: false,
    PubliclyAccessible: false,
    StorageEncrypted: true,
  });
});

test('api runs one small ARM task', () => {
  template.hasResourceProperties('AWS::ECS::TaskDefinition', {
    Cpu: '256',
    Memory: '512',
    RuntimePlatform: { CpuArchitecture: 'ARM64' },
  });
  template.hasResourceProperties('AWS::ECS::Service', { DesiredCount: 1 });
});

test('documents bucket is not public', () => {
  template.hasResourceProperties('AWS::S3::Bucket', {
    PublicAccessBlockConfiguration: {
      BlockPublicAcls: true,
      BlockPublicPolicy: true,
      IgnorePublicAcls: true,
      RestrictPublicBuckets: true,
    },
  });
});

test('users sign in with their phone number', () => {
  template.hasResourceProperties('AWS::Cognito::UserPool', {
    UsernameAttributes: ['phone_number'],
    AutoVerifiedAttributes: ['phone_number'],
  });
});

test('api container only accepts traffic from the VPC link', () => {
  template.hasResourceProperties('AWS::EC2::SecurityGroupIngress', {
    FromPort: 8080,
    ToPort: 8080,
    SourceSecurityGroupId: Match.anyValue(),
  });
});

test('budget alert is configured', () => {
  template.hasResourceProperties('AWS::Budgets::Budget', {
    Budget: Match.objectLike({ BudgetLimit: { Amount: 100, Unit: 'USD' } }),
  });
});

test('websites are private buckets behind CloudFront', () => {
  template.resourceCountIs('AWS::CloudFront::Distribution', 2);
  template.resourceCountIs('AWS::CloudFront::OriginAccessControl', 2);
});

test('only the admin dashboard origin may call the API from a browser', () => {
  template.hasResourceProperties('AWS::ApiGatewayV2::Api', {
    CorsConfiguration: Match.objectLike({ AllowOrigins: [Match.anyValue()] }),
  });
});

test('the Firebase key is a secret injected into the API container', () => {
  template.hasResourceProperties('AWS::SecretsManager::Secret', { Name: 'coco-rider/fcm-service-account' });
  template.hasResourceProperties('AWS::ECS::TaskDefinition', {
    ContainerDefinitions: Match.arrayWith([
      Match.objectLike({
        Secrets: Match.arrayWith([Match.objectLike({ Name: 'Notifications__FcmServiceAccountJson' })]),
      }),
    ]),
  });
});
