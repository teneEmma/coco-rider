import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { AuthProvider } from './auth/AuthContext';
import { loadConfig } from './config';
import { I18nProvider } from './i18n';
import './index.css';

const root = createRoot(document.getElementById('root')!);

loadConfig().then(
  (config) => root.render(
    <StrictMode>
      <I18nProvider>
        <AuthProvider config={config}>
          <App />
        </AuthProvider>
      </I18nProvider>
    </StrictMode>,
  ),
  (error: Error) => root.render(<p style={{ padding: 16 }}>Configuration error: {error.message}</p>),
);
