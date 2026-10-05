#!/usr/bin/env node
import { App } from 'aws-cdk-lib';
import { CocoRiderStack } from '../lib/coco-rider-stack';

const app = new App();

new CocoRiderStack(app, 'CocoRider', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: app.node.tryGetContext('region') ?? 'eu-west-1',
  },
  budgetEmail: app.node.tryGetContext('budgetEmail'),
  monthlyBudgetUsd: Number(app.node.tryGetContext('monthlyBudgetUsd') ?? 100),
  senderEmail: app.node.tryGetContext('senderEmail'),
  tags: { project: 'coco-rider' },
});
