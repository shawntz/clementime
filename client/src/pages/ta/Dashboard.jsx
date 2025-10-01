import { useState } from 'react';
import { Routes, Route, Link, useLocation } from 'react-router-dom';
import Layout from '../../components/shared/Layout';
import WeeklySchedule from '../../components/ta/WeeklySchedule';
import TAProfile from '../../components/ta/TAProfile';

export default function TADashboard() {
  const location = useLocation();
  const isActive = (path) => location.pathname === path;

  return (
    <Layout title="TA Dashboard">
      {/* Navigation Tabs */}
      <div style={{
        backgroundColor: 'var(--surface)',
        borderRadius: '0.5rem',
        padding: '1rem',
        marginBottom: '2rem',
        display: 'flex',
        gap: '1rem',
        flexWrap: 'wrap'
      }}>
        <Link
          to="/ta"
          className={`btn ${isActive('/ta') ? 'btn-primary' : 'btn-outline'}`}
        >
          Schedule
        </Link>
        <Link
          to="/ta/profile"
          className={`btn ${isActive('/ta/profile') ? 'btn-primary' : 'btn-outline'}`}
        >
          Profile & Settings
        </Link>
      </div>

      {/* Routes */}
      <Routes>
        <Route index element={<ScheduleView />} />
        <Route path="profile" element={<TAProfile />} />
      </Routes>
    </Layout>
  );
}

function ScheduleView() {
  const [weekNumber, setWeekNumber] = useState(1);

  return (
    <>
      <div className="card" style={{ marginBottom: '1.5rem' }}>
        <label className="form-label">Select Week</label>
        <select
          className="form-input"
          value={weekNumber}
          onChange={(e) => setWeekNumber(parseInt(e.target.value))}
          style={{ maxWidth: '300px' }}
        >
          {[...Array(10)].map((_, i) => (
            <option key={i + 1} value={i + 1}>
              Week {i + 1} (Oral Exam {i + 1})
            </option>
          ))}
        </select>
      </div>

      <WeeklySchedule weekNumber={weekNumber} />
    </>
  );
}
