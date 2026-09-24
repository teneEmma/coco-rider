export type AuthMode = 'cognito' | 'development';

export interface AppConfig {
  /** Base URL of the Coco Rider API, without a trailing slash. */
  apiUrl: string;
  authMode: AuthMode;
  region?: string;
  userPoolId?: string;
  clientId?: string;
}

/** Local development: the Vite dev server proxies /api to the .NET API on :5200. */
const developmentConfig: AppConfig = { apiUrl: '/api', authMode: 'development' };

/**
 * In AWS, /config.json is written next to the app by the CDK stack, so the same build
 * works in every environment. It is absent in local development.
 */
export async function loadConfig(): Promise<AppConfig> {
  try {
    const response = await fetch('/config.json', { cache: 'no-store' });
    if (response.ok && response.headers.get('content-type')?.includes('json')) {
      const config = (await response.json()) as AppConfig;
      return { ...config, apiUrl: config.apiUrl.replace(/\/$/, '') };
    }
  } catch {
    // Fall through to the development defaults.
  }
  if (import.meta.env.DEV) return developmentConfig;
  throw new Error('config.json is missing');
}
