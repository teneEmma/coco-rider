import { useCallback, useMemo } from 'react';
import { useAuth } from '../auth/AuthContext';
import type { AdminUser, ReviewQueueItem, Stats } from './types';

/** An error returned by the API; `code` is the stable identifier (e.g. "document.not_found"). */
export class ApiError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function useApi() {
  const { config, authHeaders, signOut } = useAuth();

  const request = useCallback(async <T,>(method: string, path: string, body?: unknown): Promise<T> => {
    const response = await fetch(`${config.apiUrl}${path}`, {
      method,
      headers: {
        ...(await authHeaders()),
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

    if (response.status === 401) {
      signOut();
      throw new ApiError(401, 'auth.expired', 'Session expired');
    }
    if (!response.ok) {
      const problem = await response.json().catch(() => ({}));
      throw new ApiError(response.status, problem.code ?? `http.${response.status}`, problem.detail ?? response.statusText);
    }
    return (response.status === 204 ? undefined : await response.json()) as T;
  }, [config.apiUrl, authHeaders, signOut]);

  return useMemo(() => ({
    stats: () => request<Stats>('GET', '/v1/admin/stats'),
    reviewQueue: () => request<ReviewQueueItem[]>('GET', '/v1/admin/documents'),
    approveDocument: (id: string) => request('POST', `/v1/admin/documents/${id}/approve`),
    rejectDocument: (id: string, reason: string) => request('POST', `/v1/admin/documents/${id}/reject`, { reason }),
    searchUsers: (query: string) => request<AdminUser[]>('GET', `/v1/admin/users?query=${encodeURIComponent(query)}`),
    suspendUser: (id: string, days: number, reason: string) =>
      request<AdminUser>('POST', `/v1/admin/users/${id}/suspend`, { days, reason }),
    unsuspendUser: (id: string) => request<AdminUser>('POST', `/v1/admin/users/${id}/unsuspend`),
  }), [request]);
}
