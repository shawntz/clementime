import { Routes, Route } from 'react-router-dom';
import Layout from '../../components/shared/Layout';
import RosterUpload from '../../components/admin/RosterUpload';
import TAManagement from '../../components/admin/TAManagement';
import SessionManager from '../../components/admin/SessionManager';
import RosterManager from '../../components/admin/RosterManager';
import UserManagement from '../../components/admin/UserManagement';
import SystemPreferences from '../../components/admin/SystemPreferences';
import AdminProfile from '../../components/admin/AdminProfile';
import SlackControlCenter from '../../components/admin/SlackControlCenter';

export default function AdminDashboard() {
  return (
    <Layout title="Admin Dashboard" showAdminTabs={true}>
      {/* Routes */}
      <Routes>
        <Route index element={<Overview />} />
        <Route path="upload" element={<RosterUpload />} />
        <Route path="roster" element={<RosterManager />} />
        <Route path="tas" element={<TAManagement />} />
        <Route path="sessions" element={<SessionManager />} />
        <Route path="slack" element={<SlackControlCenter />} />
        <Route path="users" element={<UserManagement />} />
        <Route path="preferences" element={<SystemPreferences />} />
        <Route path="profile" element={<AdminProfile />} />
      </Routes>
    </Layout>
  );
}

function Overview() {
  return (
    <div className="space-y-6">
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h3 className="text-2xl font-bold text-orange-600 mb-4 flex items-center gap-2">
          <span>🍊</span>
          Welcome to Clementime Admin
        </h3>
        <p className="mb-4 text-gray-700">
          Use the tabs above to manage your oral exam scheduling:
        </p>
        <ul className="space-y-2 text-gray-600">
          <li className="flex items-center gap-2">
            <span className="text-lg">📤</span>
            <span>Upload Canvas roster CSV</span>
          </li>
          <li className="flex items-center gap-2">
            <span className="text-lg">💬</span>
            <span>Match students with Slack users</span>
          </li>
          <li className="flex items-center gap-2">
            <span className="text-lg">📋</span>
            <span>Manage student roster and scheduling constraints</span>
          </li>
          <li className="flex items-center gap-2">
            <span className="text-lg">👨‍🏫</span>
            <span>Create and manage TAs</span>
          </li>
          <li className="flex items-center gap-2">
            <span className="text-lg">👥</span>
            <span>Assign TAs to sections</span>
          </li>
          <li className="flex items-center gap-2">
            <span className="text-lg">📅</span>
            <span>Generate exam schedules</span>
          </li>
        </ul>
      </div>

      {/* Need Help Section */}
      <div className="bg-gradient-to-br from-orange-50 to-orange-100 rounded-lg shadow-sm border-2 border-orange-300 p-6">
        <h4 className="text-xl font-bold text-orange-700 mb-3 flex items-center gap-2">
          <span className="text-2xl">❓</span>
          Need Help?
        </h4>
        <p className="text-gray-700 mb-4">
          Found a bug or have a question? Report issues or request features on our GitHub
          repository.
        </p>
        <a
          href="https://github.com/shawntz/clementime/issues"
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 bg-orange-600 hover:bg-orange-700 text-white font-semibold px-6 py-3 rounded-lg transition-colors shadow-md hover:shadow-lg"
        >
          <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
            <path
              fillRule="evenodd"
              d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
              clipRule="evenodd"
            />
          </svg>
          <span>Report an Issue on GitHub</span>
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
            />
          </svg>
        </a>
      </div>
    </div>
  );
}
