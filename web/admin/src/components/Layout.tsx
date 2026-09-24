import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { useI18n } from '../i18n';

export function Layout() {
  const { session, signOut } = useAuth();
  const { t, locale, setLocale } = useI18n();

  return (
    <div className="shell">
      <header className="topbar">
        <span className="brand">{t('appName')}</span>
        <nav>
          <NavLink to="/" end>{t('nav.stats')}</NavLink>
          <NavLink to="/documents">{t('nav.documents')}</NavLink>
          <NavLink to="/users">{t('nav.users')}</NavLink>
        </nav>
        <div className="topbar-end">
          <button
            type="button"
            className="link"
            onClick={() => setLocale(locale === 'fr' ? 'en' : 'fr')}
            aria-label={locale === 'fr' ? 'Switch to English' : 'Passer en français'}
          >
            {locale === 'fr' ? 'EN' : 'FR'}
          </button>
          <span className="muted small">{session?.phoneNumber}</span>
          <button type="button" className="link" onClick={signOut}>{t('nav.signOut')}</button>
        </div>
      </header>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
