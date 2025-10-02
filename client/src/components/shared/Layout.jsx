import { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { Link, useLocation } from 'react-router-dom';
import api from '../../services/api';

export default function Layout({ children, title, showAdminTabs = false }) {
  const { user, logout } = useAuth();
  const location = useLocation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [navbarTitle, setNavbarTitle] = useState('');
  const [version, setVersion] = useState('');
  const [releaseDate, setReleaseDate] = useState('');

  useEffect(() => {
    const loadNavbarTitle = async () => {
      try {
        const response = await api.get('/admin/config');
        setNavbarTitle(response.data.navbar_title || '');
      } catch (err) {
        console.error('Failed to load navbar title', err);
      }
    };

    if (user) {
      loadNavbarTitle();
    }
  }, [user]);

  useEffect(() => {
    const loadVersion = async () => {
      try {
        const response = await api.get('/version');
        setVersion(response.data.version || '');
        setReleaseDate(response.data.release_date || '');
      } catch (err) {
        console.error('Failed to load version', err);
      }
    };

    loadVersion();
  }, []);

  const formatReleaseDate = (dateStr) => {
    if (!dateStr) return '';
    try {
      const date = new Date(dateStr);
      return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      });
    } catch {
      return '';
    }
  };

  const getHomeLink = () => {
    if (!user) return '/';
    return user.role === 'admin' ? '/admin' : '/ta';
  };

  const isActive = (path) => location.pathname === path;

  const getDisplayTitle = () => {
    if (navbarTitle) return navbarTitle;
    return title?.replace(' Dashboard', '') || 'Clementime';
  };

  return (
    <div className="min-h-screen bg-orange-50">
      {/* Orange Header */}
      <nav className="bg-gradient-to-r from-orange-500 to-orange-600 shadow-lg">
        <div className="px-6 py-3">
          <div className="flex justify-between items-center gap-4">
            {/* Left side - Logo and Title */}
            <div className="flex items-center gap-2 flex-shrink-0">
              <Link to={getHomeLink()} className="flex items-center gap-1.5 hover:opacity-90 transition-opacity">
                <span className="text-2xl">🍊</span>
                <div className="text-white">
                  <h1 className="text-base font-bold leading-tight">
                    {getDisplayTitle()}
                  </h1>
                  <a
                    href="https://clementime.app"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-xs text-orange-100 hover:text-white transition-colors"
                    onClick={(e) => e.stopPropagation()}
                  >
                    Powered by Clementime
                  </a>
                </div>
              </Link>
            </div>

            {/* Hamburger Menu Button (Mobile) */}
            {user?.role === 'admin' && showAdminTabs && (
              <button
                onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                className="lg:hidden text-white p-2 hover:bg-white/20 rounded-lg transition-colors"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              </button>
            )}

            {/* Center - Admin Navigation Tabs (Desktop) */}
            {user?.role === 'admin' && showAdminTabs && (
              <div className="hidden lg:flex flex-1 justify-center">
                <div className="flex gap-2 items-center overflow-x-auto">
              <Link
                to="/admin"
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                  isActive('/admin')
                    ? 'bg-white text-orange-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
              >
                Overview
              </Link>
              <Link
                to="/admin/upload"
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                  isActive('/admin/upload')
                    ? 'bg-white text-orange-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
              >
                Roster Upload
              </Link>
              <Link
                to="/admin/roster"
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                  isActive('/admin/roster')
                    ? 'bg-white text-orange-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
              >
                Roster Management
              </Link>
              <Link
                to="/admin/tas"
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                  isActive('/admin/tas')
                    ? 'bg-white text-orange-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
              >
                TA Management
              </Link>
              <Link
                to="/admin/sessions"
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                  isActive('/admin/sessions')
                    ? 'bg-white text-orange-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
              >
                Session Manager
              </Link>
              <Link
                to="/admin/slack"
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                  isActive('/admin/slack')
                    ? 'bg-white text-orange-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
              >
                🚀 Slack Control
              </Link>
              <Link
                to="/admin/users"
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                  isActive('/admin/users')
                    ? 'bg-white text-orange-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
              >
                User Management
              </Link>
              <Link
                to="/admin/preferences"
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                  isActive('/admin/preferences')
                    ? 'bg-white text-orange-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
              >
                Preferences
              </Link>
              <Link
                to="/admin/profile"
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                  isActive('/admin/profile')
                    ? 'bg-white text-orange-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
              >
                Profile
              </Link>
                </div>
              </div>
            )}

            {/* Right side - User Info */}
            {user && (
              <div className="flex items-center gap-2 flex-shrink-0">
                <div className="flex items-center gap-2 bg-white/10 px-2 py-1.5 rounded-lg backdrop-blur-sm">
                  <div className="text-right">
                    <div className="text-white text-xs font-medium">{user.full_name}</div>
                    <div className="text-orange-100 text-xs">{user.role === 'admin' ? 'Admin' : 'TA'}</div>
                  </div>
                  <div className="w-7 h-7 bg-white/20 rounded-full flex items-center justify-center text-white text-xs font-semibold">
                    {user.full_name?.charAt(0) || '?'}
                  </div>
                </div>
                <button
                  onClick={logout}
                  className="text-white hover:bg-white/20 px-3 py-1.5 rounded-lg transition-colors text-xs font-medium"
                >
                  Logout
                </button>
              </div>
            )}
          </div>
        </div>
      </nav>

      {/* Mobile Menu Drawer */}
      {mobileMenuOpen && user?.role === 'admin' && showAdminTabs && (
        <>
          {/* Backdrop */}
          <div
            className="fixed inset-0 bg-black/50 z-40 lg:hidden"
            onClick={() => setMobileMenuOpen(false)}
          />

          {/* Drawer */}
          <div className="fixed top-0 left-0 bottom-0 w-64 bg-white shadow-xl z-50 lg:hidden overflow-y-auto">
            <div className="p-4">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-lg font-bold text-gray-800">Navigation</h2>
                <button
                  onClick={() => setMobileMenuOpen(false)}
                  className="text-gray-400 hover:text-gray-600 p-2"
                >
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <nav className="space-y-2">
                <Link
                  to="/admin"
                  onClick={() => setMobileMenuOpen(false)}
                  className={`block px-4 py-3 rounded-lg font-medium transition-colors ${
                    isActive('/admin')
                      ? 'bg-orange-100 text-orange-600'
                      : 'text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  Overview
                </Link>
                <Link
                  to="/admin/upload"
                  onClick={() => setMobileMenuOpen(false)}
                  className={`block px-4 py-3 rounded-lg font-medium transition-colors ${
                    isActive('/admin/upload')
                      ? 'bg-orange-100 text-orange-600'
                      : 'text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  Roster Upload
                </Link>
                <Link
                  to="/admin/roster"
                  onClick={() => setMobileMenuOpen(false)}
                  className={`block px-4 py-3 rounded-lg font-medium transition-colors ${
                    isActive('/admin/roster')
                      ? 'bg-orange-100 text-orange-600'
                      : 'text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  Roster Management
                </Link>
                <Link
                  to="/admin/tas"
                  onClick={() => setMobileMenuOpen(false)}
                  className={`block px-4 py-3 rounded-lg font-medium transition-colors ${
                    isActive('/admin/tas')
                      ? 'bg-orange-100 text-orange-600'
                      : 'text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  TA Management
                </Link>
                <Link
                  to="/admin/sessions"
                  onClick={() => setMobileMenuOpen(false)}
                  className={`block px-4 py-3 rounded-lg font-medium transition-colors ${
                    isActive('/admin/sessions')
                      ? 'bg-orange-100 text-orange-600'
                      : 'text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  Session Manager
                </Link>
                <Link
                  to="/admin/users"
                  onClick={() => setMobileMenuOpen(false)}
                  className={`block px-4 py-3 rounded-lg font-medium transition-colors ${
                    isActive('/admin/users')
                      ? 'bg-orange-100 text-orange-600'
                      : 'text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  User Management
                </Link>
                <Link
                  to="/admin/preferences"
                  onClick={() => setMobileMenuOpen(false)}
                  className={`block px-4 py-3 rounded-lg font-medium transition-colors ${
                    isActive('/admin/preferences')
                      ? 'bg-orange-100 text-orange-600'
                      : 'text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  Preferences
                </Link>
                <Link
                  to="/admin/profile"
                  onClick={() => setMobileMenuOpen(false)}
                  className={`block px-4 py-3 rounded-lg font-medium transition-colors ${
                    isActive('/admin/profile')
                      ? 'bg-orange-100 text-orange-600'
                      : 'text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  Profile
                </Link>
              </nav>
            </div>
          </div>
        </>
      )}

      {/* Main Content */}
      <main className="p-6 max-w-7xl mx-auto pb-20">
        {children}
      </main>

      {/* Footer */}
      <footer className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 py-3 px-6 z-10">
        <div className="max-w-7xl mx-auto">
          <div className="flex justify-between items-center text-sm text-gray-600">
            <div className="flex flex-col gap-0.5">
              <div className="flex items-center gap-4">
                <span>© {new Date().getFullYear()} Clementime</span>
                {version && (
                  <>
                    <span className="text-gray-300">•</span>
                    <a
                      href={`https://github.com/shawntz/clementime/releases/tag/${version}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="hover:text-orange-600 transition-colors flex items-center gap-1"
                    >
                      <span>{version}</span>
                      <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </a>
                  </>
                )}
              </div>
              {releaseDate && (
                <span className="text-xs text-gray-400">
                  Last updated on {formatReleaseDate(releaseDate)}
                </span>
              )}
            </div>
            <a
              href="https://github.com/shawntz/clementime"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-orange-600 transition-colors flex items-center gap-1"
            >
              <span>View on GitHub</span>
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                <path fillRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clipRule="evenodd" />
              </svg>
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
