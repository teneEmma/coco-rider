import { useState } from 'react';
import { useApi } from '../api/client';
import type { ReviewQueueItem } from '../api/types';
import { ErrorMessage, Loading } from '../components/Feedback';
import { useAsync } from '../components/useAsync';
import { useI18n } from '../i18n';

/** The queue of documents the automatic checks could not accept. */
export function DocumentsPage() {
  const api = useApi();
  const { t } = useI18n();
  const { state, reload, setData } = useAsync(api.reviewQueue);

  if (state.status === 'loading') return <Loading />;
  if (state.status === 'error') return <ErrorMessage error={state.error} onRetry={reload} />;

  const remove = (id: string) => setData((items) => items.filter((i) => i.documentId !== id));

  return (
    <section>
      <h1>{t('nav.documents')} <span className="count">{state.data.length}</span></h1>
      {state.data.length === 0 ? (
        <p className="muted">{t('docs.empty')}</p>
      ) : (
        <div className="documents">
          {state.data.map((item) => <DocumentCard key={item.documentId} item={item} onDone={() => remove(item.documentId)} />)}
        </div>
      )}
    </section>
  );
}

function DocumentCard({ item, onDone }: { item: ReviewQueueItem; onDone: () => void }) {
  const api = useApi();
  const { t, formatDate } = useI18n();
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  async function run(action: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await action();
      onDone();
    } catch (e) {
      setError(e as Error);
      setBusy(false);
    }
  }

  return (
    <article className="card document" aria-label={`${t(`doc.${item.type}`)} – ${item.userName}`}>
      <a href={item.imageUrl} target="_blank" rel="noreferrer" className="document-image">
        <img src={item.imageUrl} alt={t(`doc.${item.type}`)} loading="lazy" />
      </a>
      <div className="document-body">
        <h2>{t(`doc.${item.type}`)}</h2>
        <dl>
          <dt>{t('users.name')}</dt><dd>{item.userName}</dd>
          <dt>{t('users.phone')}</dt><dd>{item.phoneNumber}</dd>
          <dt>{t('docs.submitted')}</dt><dd>{formatDate(item.submittedAt)}</dd>
          {item.expiresOn && <><dt>{t('docs.expires')}</dt><dd>{formatDate(item.expiresOn)}</dd></>}
          {item.reviewNote && <><dt>{t('docs.note')}</dt><dd><code>{item.reviewNote}</code></dd></>}
        </dl>

        {rejecting ? (
          <form
            className="stack"
            onSubmit={(e) => { e.preventDefault(); void run(() => api.rejectDocument(item.documentId, reason.trim())); }}
          >
            <label>
              {t('docs.reason')}
              <textarea value={reason} onChange={(e) => setReason(e.target.value)} required rows={2} autoFocus />
            </label>
            <div className="actions">
              <button type="submit" className="button danger" disabled={busy || !reason.trim()}>{t('docs.confirmReject')}</button>
              <button type="button" className="button secondary" onClick={() => setRejecting(false)}>{t('docs.cancel')}</button>
            </div>
          </form>
        ) : (
          <div className="actions">
            <button type="button" className="button" disabled={busy} onClick={() => void run(() => api.approveDocument(item.documentId))}>
              {t('docs.approve')}
            </button>
            <button type="button" className="button secondary" disabled={busy} onClick={() => setRejecting(true)}>
              {t('docs.reject')}
            </button>
          </div>
        )}
        {error && <ErrorMessage error={error} />}
      </div>
    </article>
  );
}
