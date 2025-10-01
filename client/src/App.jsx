import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Landing from './pages/Landing';
import Login from './pages/Login';
import AdminDashboard from './pages/admin/Dashboard';
import TADashboard from './pages/ta/Dashboard';
import './index.css';

function PrivateRoute({ children, role }) {
  const { user, loading } = useAuth();

  if (loading) {
    return <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh' }}>
      <div className="spinner"></div>
    </div>;
  }

  if (!user) {
    return <Navigate to="/login" />;
  }

  if (role && user.role !== role) {
    return <Navigate to="/app" />;
  }

  return children;
}

function AppHome() {
  const { user } = useAuth();

  if (!user) return <Navigate to="/login" />;

  return user.role === 'admin' ?
    <Navigate to="/admin" /> :
    <Navigate to="/ta" />;
}

function App() {
  // Show landing page only on main instance (clementime.app)
  const showLandingPage = import.meta.env.VITE_SHOW_LANDING === 'true';

  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Public landing page (only on main instance) */}
          <Route path="/" element={showLandingPage ? <Landing /> : <Navigate to="/login" />} />

          {/* Auth routes */}
          <Route path="/login" element={<Login />} />
          <Route path="/app" element={<AppHome />} />

          {/* Admin routes */}
          <Route
            path="/admin/*"
            element={
              <PrivateRoute role="admin">
                <AdminDashboard />
              </PrivateRoute>
            }
          />

          {/* TA routes */}
          <Route
            path="/ta/*"
            element={
              <PrivateRoute role="ta">
                <TADashboard />
              </PrivateRoute>
            }
          />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
