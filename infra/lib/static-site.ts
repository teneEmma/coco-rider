import * as fs from 'fs';
import {
  Annotations, Duration, RemovalPolicy,
  aws_cloudfront as cloudfront,
  aws_cloudfront_origins as origins,
  aws_s3 as s3,
  aws_s3_deployment as s3deploy,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';

export interface StaticSiteProps {
  /** Folder produced by "npm run build" (e.g. web/admin/dist). Skipped with a warning if missing. */
  readonly buildDir: string;
}

/**
 * A single-page app served by CloudFront from a private bucket.
 * CloudFront's always-free tier (1 TB/month) covers the MVP traffic.
 */
export class StaticSite extends Construct {
  readonly distribution: cloudfront.Distribution;
  private readonly bucket: s3.Bucket;
  private readonly buildDir: string;

  constructor(scope: Construct, id: string, props: StaticSiteProps) {
    super(scope, id);

    this.buildDir = props.buildDir;
    this.bucket = new s3.Bucket(this, 'Bucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      removalPolicy: RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    this.distribution = new cloudfront.Distribution(this, 'Distribution', {
      defaultRootObject: 'index.html',
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(this.bucket),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        responseHeadersPolicy: cloudfront.ResponseHeadersPolicy.SECURITY_HEADERS,
      },
      // Client-side routes (/documents, /users) are served by index.html.
      errorResponses: [403, 404].map((httpStatus) => ({
        httpStatus,
        responseHttpStatus: 200,
        responsePagePath: '/index.html',
        ttl: Duration.minutes(5),
      })),
      priceClass: cloudfront.PriceClass.PRICE_CLASS_100,
    });
  }

  /**
   * Uploads the build. `runtimeConfig` is written as /config.json next to the app, so one build
   * works in every environment (it may reference other resources, e.g. the API URL).
   */
  publish(runtimeConfig?: Record<string, unknown>): void {
    if (!fs.existsSync(this.buildDir)) {
      Annotations.of(this).addWarningV2('coco:site-not-built', `${this.buildDir} not found: run "npm run build" before deploying.`);
      return;
    }

    const sources = [s3deploy.Source.asset(this.buildDir)];
    if (runtimeConfig) sources.push(s3deploy.Source.jsonData('config.json', runtimeConfig));

    new s3deploy.BucketDeployment(this, 'Deploy', {
      sources,
      destinationBucket: this.bucket,
      distribution: this.distribution,
      distributionPaths: ['/index.html', '/config.json'],
    });
  }

  get url(): string {
    return `https://${this.distribution.distributionDomainName}`;
  }
}
