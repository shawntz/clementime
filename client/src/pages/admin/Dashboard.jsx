import { Routes, Route } from 'react-router-dom';
import Layout from '../../components/shared/Layout';
import RosterUpload from '../../components/admin/RosterUpload';
import TAManagement from '../../components/admin/TAManagement';
import SessionManager from '../../components/admin/SessionManager';
import RosterManager from '../../components/admin/RosterManager';
import UserManagement from '../../components/admin/UserManagement';
import SystemPreferences from '../../components/admin/SystemPreferences';
import AdminProfile from '../../components/admin/AdminProfile';

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
        <Route path="users" element={<UserManagement />} />
        <Route path="preferences" element={<SystemPreferences />} />
        <Route path="profile" element={<AdminProfile />} />
      </Routes>
    </Layout>
  );
}

function Overview() {
  return (
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
  );
}
