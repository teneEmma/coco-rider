import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './index.css';
import { TrackPage } from './track/TrackPage';

/** Links shared by passengers: /suivi/{token}. Everything else is the landing page. */
const shared = window.location.pathname.match(/^\/suivi\/([A-Za-z0-9_-]+)\/?$/);
const locale = navigator.language.startsWith('en') ? 'en' : 'fr';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {shared ? <TrackPage token={shared[1]} locale={locale} /> : <App />}
  </StrictMode>,
);
