import { useI18n } from '../i18n';

export function Loading() {
  const { t } = useI18n();
  return <p className="muted" role="status">{t('common.loading')}</p>;
}

export function ErrorMessage({ error, onRetry }: { error: Error; onRetry?: () => void }) {
  const { t } = useI18n();
  return (
    <div className="alert" role="alert">
      <strong>{t('common.error')}</strong>
      <span>{error.message}</span>
      {onRetry && <button type="button" className="button secondary" onClick={onRetry}>{t('common.retry')}</button>}
    </div>
  );
}
