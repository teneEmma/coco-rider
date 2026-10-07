#!/usr/bin/env node
import { App } from 'aws-cdk-lib';
import { CocoRiderStack } from '../lib/coco-rider-stack';

const app = new App();

new CocoRiderStack(app, 'CocoRider', {
  env: {
    // Pinned to the on-go account: CDK refuses to deploy with credentials for any other account.
    account: app.node.tryGetContext('account') ?? process.env.CDK_DEFAULT_ACCOUNT,
    region: app.node.tryGetContext('region') ?? 'us-east-1',
  },
  budgetEmail: app.node.tryGetContext('budgetEmail'),
  monthlyBudgetUsd: Number(app.node.tryGetContext('monthlyBudgetUsd') ?? 100),
  senderEmail: app.node.tryGetContext('senderEmail'),
  tags: { project: 'on-go' },
});
