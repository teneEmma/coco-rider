/**
 * Minimal Cognito client for passwordless sign-in with an SMS code (USER_AUTH flow).
 * Public app clients need no request signing, so plain fetch is enough.
 */

export interface Tokens {
  idToken: string;
  refreshToken: string;
  /** Epoch milliseconds. */
  expiresAt: number;
}

export class CognitoError extends Error {
  readonly type: string;

  constructor(type: string, message: string) {
    super(message);
    this.type = type;
  }
}

interface AuthenticationResult {
  IdToken: string;
  RefreshToken?: string;
  ExpiresIn: number;
}

export class CognitoClient {
  private readonly endpoint: string;
  private readonly clientId: string;

  constructor(region: string, clientId: string) {
    this.endpoint = `https://cognito-idp.${region}.amazonaws.com/`;
    this.clientId = clientId;
  }

  /** Sends the SMS code. Returns the session to pass to {@link confirmCode}. */
  async sendCode(phoneNumber: string): Promise<string> {
    const response = await this.call<{ ChallengeName?: string; Session: string }>('InitiateAuth', {
      AuthFlow: 'USER_AUTH',
      ClientId: this.clientId,
      AuthParameters: { USERNAME: phoneNumber, PREFERRED_CHALLENGE: 'SMS_OTP' },
    });
    if (response.ChallengeName !== 'SMS_OTP') {
      throw new CognitoError('UnexpectedChallenge', `Unexpected challenge ${response.ChallengeName}`);
    }
    return response.Session;
  }

  async confirmCode(phoneNumber: string, session: string, code: string): Promise<Tokens> {
    const response = await this.call<{ AuthenticationResult: AuthenticationResult }>('RespondToAuthChallenge', {
      ChallengeName: 'SMS_OTP',
      ClientId: this.clientId,
      Session: session,
      ChallengeResponses: { USERNAME: phoneNumber, SMS_OTP_CODE: code },
    });
    return toTokens(response.AuthenticationResult, undefined);
  }

  async refresh(refreshToken: string): Promise<Tokens> {
    const response = await this.call<{ AuthenticationResult: AuthenticationResult }>('InitiateAuth', {
      AuthFlow: 'REFRESH_TOKEN_AUTH',
      ClientId: this.clientId,
      AuthParameters: { REFRESH_TOKEN: refreshToken },
    });
    return toTokens(response.AuthenticationResult, refreshToken);
  }

  private async call<T>(action: string, body: unknown): Promise<T> {
    const response = await fetch(this.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': `AWSCognitoIdentityProviderService.${action}`,
      },
      body: JSON.stringify(body),
    });
    const json = await response.json();
    if (!response.ok) {
      const type = String(json.__type ?? 'Unknown').split('#').pop()!;
      throw new CognitoError(type, json.message ?? type);
    }
    return json as T;
  }
}

function toTokens(result: AuthenticationResult, previousRefreshToken: string | undefined): Tokens {
  return {
    idToken: result.IdToken,
    refreshToken: result.RefreshToken ?? previousRefreshToken ?? '',
    expiresAt: Date.now() + result.ExpiresIn * 1000,
  };
}

/** Reads the claims of a JWT without verifying it (the API verifies it). */
export function decodeClaims(jwt: string): Record<string, unknown> {
  const payload = jwt.split('.')[1] ?? '';
  const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
  const json = decodeURIComponent(
    atob(base64)
      .split('')
      .map((c) => '%' + c.charCodeAt(0).toString(16).padStart(2, '0'))
      .join(''),
  );
  return JSON.parse(json);
}

export function isAdmin(idToken: string): boolean {
  const groups = decodeClaims(idToken)['cognito:groups'];
  return Array.isArray(groups) && groups.includes('admin');
}
