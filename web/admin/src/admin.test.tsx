import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ReviewQueueItem } from './api/types';
import { AuthProvider } from './auth/AuthContext';
import { decodeClaims, isAdmin } from './auth/cognito';
import { I18nProvider } from './i18n';
import { DocumentsPage } from './pages/DocumentsPage';
import { normalizeCameroonPhone } from './pages/LoginPage';

function jwt(claims: object): string {
  const encode = (value: object) => btoa(JSON.stringify(value)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
  return `${encode({ alg: 'none' })}.${encode(claims)}.sig`;
}

describe('phone numbers', () => {
  it.each([
    ['6 90 00 00 00', '+237690000000'],
    ['690000000', '+237690000000'],
    ['237690000000', '+237690000000'],
    ['+237 690-000-000', '+237690000000'],
  ])('%s → %s', (input, expected) => expect(normalizeCameroonPhone(input)).toBe(expected));
});

describe('tokens', () => {
  it('reads the admin group from the ID token', () => {
    expect(isAdmin(jwt({ 'cognito:groups': ['admin'] }))).toBe(true);
    expect(isAdmin(jwt({ 'cognito:groups': ['drivers'] }))).toBe(false);
    expect(isAdmin(jwt({}))).toBe(false);
  });

  it('decodes non-ASCII claims', () => {
    const payload = btoa(String.fromCharCode(...new TextEncoder().encode(JSON.stringify({ name: 'Yaoundé' }))));
    expect(decodeClaims(`x.${payload}.y`).name).toBe('Yaoundé');
  });
});

describe('document review', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    sessionStorage.clear();
  });

  const item: ReviewQueueItem = {
    documentId: 'doc-1',
    userId: 'user-1',
    userName: 'Ama Tchoua',
    phoneNumber: '+237690000001',
    type: 'Selfie',
    status: 'NeedsReview',
    expiresOn: null,
    reviewNote: 'face_match_below_threshold:72',
    imageUrl: 'https://example.com/selfie.jpg',
    submittedAt: '2026-09-20T10:00:00Z',
  };

  it('approves a document and removes it from the queue', async () => {
    sessionStorage.setItem('coco-admin-session', JSON.stringify({ kind: 'development', phoneNumber: '+237690000000', sub: 'admin-1' }));
    localStorage.setItem('coco-admin-locale', 'en');
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
      const url = String(input);
      if (url.endsWith('/v1/admin/documents') && !init?.method?.startsWith('POST')) {
        return Response.json([item]);
      }
      return Response.json({});
    });

    render(
      <I18nProvider>
        <AuthProvider config={{ apiUrl: '/api', authMode: 'development' }}>
          <DocumentsPage />
        </AuthProvider>
      </I18nProvider>,
    );

    expect(await screen.findByText('Ama Tchoua')).toBeInTheDocument();
    expect(screen.getByText('face_match_below_threshold:72')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Approve' }));

    await waitFor(() => expect(screen.getByText('No documents to review.')).toBeInTheDocument());
    const approveCall = fetchMock.mock.calls.find(([url]) => String(url).endsWith('/doc-1/approve'))!;
    expect(approveCall[1]?.method).toBe('POST');
    expect((approveCall[1]?.headers as Record<string, string>)['X-Dev-Groups']).toBe('admin');
  });
});
