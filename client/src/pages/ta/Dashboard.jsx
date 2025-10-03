import { useState, useEffect } from 'react';
import { Routes, Route, Link, useLocation } from 'react-router-dom';
import Layout from '../../components/shared/Layout';
import WeeklySchedule from '../../components/ta/WeeklySchedule';
import TAProfile from '../../components/ta/TAProfile';
import RosterView from '../../components/ta/RosterView';
import api from '../../services/api';

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
          to="/ta/roster"
          className={`btn ${isActive('/ta/roster') ? 'btn-primary' : 'btn-outline'}`}
        >
          Roster
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
        <Route path="roster" element={<RosterView />} />
        <Route path="profile" element={<TAProfile />} />
      </Routes>
    </Layout>
  );
}

function ScheduleView() {
  const [weekNumber, setWeekNumber] = useState(1);
  const [examDates, setExamDates] = useState({});
  const [sortedWeeks, setSortedWeeks] = useState([]);

  useEffect(() => {
    const loadExamDates = async () => {
      try {
        const response = await api.get('/ta/config');
        const dates = response.data.exam_dates || {};
        setExamDates(dates);

        // Create array of weeks with their dates
        // Each exam spans 2 weeks: Exam 1 = Weeks 1-2, Exam 2 = Weeks 3-4, etc.
        const weeks = [];
        const totalExams = response.data.total_exams || 5;
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        for (let examNum = 1; examNum <= totalExams; examNum++) {
          const oddKey = `${examNum}_odd`;
          const evenKey = `${examNum}_even`;
          const oddDate = dates[oddKey] ? new Date(dates[oddKey]) : null;
          const evenDate = dates[evenKey] ? new Date(dates[evenKey]) : null;

          // Week numbers for this exam
          const oddWeekNum = (examNum - 1) * 2 + 1;
          const evenWeekNum = (examNum - 1) * 2 + 2;

          // Add odd week
          weeks.push({
            weekNumber: oddWeekNum,
            examNumber: examNum,
            date: oddDate,
            isPast: oddDate ? oddDate < today : false
          });

          // Add even week
          weeks.push({
            weekNumber: evenWeekNum,
            examNumber: examNum,
            date: evenDate,
            isPast: evenDate ? evenDate < today : false
          });
        }

        // Sort: current/future exams first (by date), then past exams (by date descending)
        const sorted = weeks.sort((a, b) => {
          // If one has no date, put it at the end
          if (!a.date && !b.date) return a.weekNumber - b.weekNumber;
          if (!a.date) return 1;
          if (!b.date) return 1;

          // Both past - sort by date descending (most recent first)
          if (a.isPast && b.isPast) return b.date - a.date;

          // Both future/current - sort by date ascending (earliest first)
          if (!a.isPast && !b.isPast) return a.date - b.date;

          // One past, one future - future comes first
          return a.isPast ? 1 : -1;
        });

        setSortedWeeks(sorted);

        // Set initial week to first non-past exam, or first exam if all are past
        const firstCurrentExam = sorted.find(w => !w.isPast);
        setWeekNumber(firstCurrentExam ? firstCurrentExam.weekNumber : sorted[0]?.weekNumber || 1);
      } catch (err) {
        console.error('Failed to load exam dates', err);
        // Fallback to default weeks 1-10
        setSortedWeeks([...Array(10)].map((_, i) => ({ weekNumber: i + 1, date: null, isPast: false })));
      }
    };

    loadExamDates();
  }, []);

  return (
    <>
      {/* Week Tabs */}
      <div className="card" style={{ marginBottom: '1.5rem', padding: '0' }}>
        <div style={{
          display: 'flex',
          gap: '0.5rem',
          padding: '1rem',
          overflowX: 'auto',
          borderBottom: '1px solid var(--border)'
        }}>
          {sortedWeeks.map((week) => (
            <button
              key={week.weekNumber}
              onClick={() => setWeekNumber(week.weekNumber)}
              className={`btn ${weekNumber === week.weekNumber ? 'btn-primary' : 'btn-outline'}`}
              style={{
                fontSize: '0.875rem',
                padding: '0.5rem 1rem',
                opacity: week.isPast ? 0.6 : 1,
                whiteSpace: 'nowrap'
              }}
            >
              Week {week.weekNumber} (Oral Exam {week.examNumber})
            </button>
          ))}
        </div>
      </div>

      <WeeklySchedule weekNumber={weekNumber} />
    </>
  );
}
