import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import { Layout } from './components/Layout';
import { DocumentsPage } from './pages/DocumentsPage';
import { LoginPage } from './pages/LoginPage';
import { StatsPage } from './pages/StatsPage';
import { UsersPage } from './pages/UsersPage';

export default function App() {
  const { session } = useAuth();

  if (!session) return <LoginPage />;

  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<StatsPage />} />
          <Route path="documents" element={<DocumentsPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
