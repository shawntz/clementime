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
  const [showStorageWarning, setShowStorageWarning] = useState(false);
  const [r2Configured, setR2Configured] = useState(false);

  useEffect(() => {
    const loadExamDates = async () => {
      try {
        const response = await api.get('/ta/config');
        const dates = response.data.exam_dates || {};
        const r2Status = response.data.cloudflare_r2_configured || false;

        setExamDates(dates);
        setR2Configured(r2Status);

        // Show warning if R2 is not configured
        if (!r2Status) {
          setShowStorageWarning(true);
        }

        // Create array of weeks with their dates
        // Each exam spans 2 weeks: Exam 1 = Weeks 1-2, Exam 2 = Weeks 3-4, etc.
        const weeks = [];
        const totalExams = response.data.total_exams || 5;
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        console.log('=== DEBUG: Today date ===', today);

        for (let examNum = 1; examNum <= totalExams; examNum++) {
          const oddKey = `${examNum}_odd`;
          const evenKey = `${examNum}_even`;
          const oddDate = dates[oddKey] ? new Date(dates[oddKey]) : null;
          const evenDate = dates[evenKey] ? new Date(dates[evenKey]) : null;

          // Week numbers for this exam
          const oddWeekNum = (examNum - 1) * 2 + 1;
          const evenWeekNum = (examNum - 1) * 2 + 2;

          // Add odd week
          const oddDayAfter = oddDate ? new Date(oddDate) : null;
          if (oddDayAfter) {
            oddDayAfter.setHours(0, 0, 0, 0);
            // Use 3 days buffer to avoid timezone edge cases
            oddDayAfter.setDate(oddDayAfter.getDate() + 3);
          }
          const oddIsPast = oddDayAfter ? today > oddDayAfter : false;
          console.log(`Week ${oddWeekNum}: examDate=${oddDate}, dayAfter=${oddDayAfter}, today>dayAfter=${oddIsPast}`);
          weeks.push({
            weekNumber: oddWeekNum,
            examNumber: examNum,
            date: oddDate,
            isPast: oddIsPast
          });

          // Add even week
          const evenDayAfter = evenDate ? new Date(evenDate) : null;
          if (evenDayAfter) {
            evenDayAfter.setHours(0, 0, 0, 0);
            // Use 3 days buffer to avoid timezone edge cases
            evenDayAfter.setDate(evenDayAfter.getDate() + 3);
          }
          const evenIsPast = evenDayAfter ? today > evenDayAfter : false;
          console.log(`Week ${evenWeekNum}: examDate=${evenDate}, dayAfter=${evenDayAfter}, today>dayAfter=${evenIsPast}`);
          weeks.push({
            weekNumber: evenWeekNum,
            examNumber: examNum,
            date: evenDate,
            isPast: evenIsPast
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
      {/* Cloud Storage Warning Modal */}
      {showStorageWarning && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div className="card" style={{ maxWidth: '500px', width: '90%' }}>
            <h3 style={{ color: 'var(--error)', marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span style={{ fontSize: '2rem' }}>⚠️</span>
              Cloud Storage Not Configured
            </h3>

            <p style={{ marginBottom: '1rem', lineHeight: '1.6' }}>
              Recording uploads to cloud storage are not currently available. Recordings will be saved locally to your computer instead.
            </p>

            <div style={{
              background: '#fef3c7',
              border: '1px solid #f59e0b',
              borderRadius: '8px',
              padding: '1rem',
              marginBottom: '1rem'
            }}>
              <p style={{ margin: 0, fontSize: '0.875rem', color: '#92400e' }}>
                <strong>Note for Instructor/Admin:</strong> Please configure Cloudflare R2 in System Preferences → Integrations to enable automatic uploads.
              </p>
            </div>

            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end' }}>
              <button
                onClick={() => setShowStorageWarning(false)}
                className="btn btn-primary"
              >
                Got it, Continue
              </button>
            </div>
          </div>
        </div>
      )}

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
