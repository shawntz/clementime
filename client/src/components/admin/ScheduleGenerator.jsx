import { useState, useEffect } from 'react';
import api from '../../services/api';
import UnscheduledSlotsModal from './UnscheduledSlotsModal';

export default function ScheduleGenerator() {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [overview, setOverview] = useState(null);
  const [showUnscheduledModal, setShowUnscheduledModal] = useState(false);
  const [selectedExam, setSelectedExam] = useState(null);
  const [selectedWeek, setSelectedWeek] = useState(null);

  useEffect(() => {
    loadOverview();
  }, []);

  const loadOverview = async () => {
    try {
      const response = await api.get('/admin/schedules/overview');

      // Filter out section 01 and sort by section number
      const filteredOverview = response.data.overview.filter(item => {
        const parts = item.section.code.split('-');
        if (parts.length >= 4) {
          const sectionNum = parseInt(parts[3]);
          return sectionNum !== 1;
        }
        return true;
      });

      // Sort numerically by section number
      filteredOverview.sort((a, b) => {
        const aNum = parseInt(a.section.code.split('-')[3]);
        const bNum = parseInt(b.section.code.split('-')[3]);
        return aNum - bNum;
      });

      // Recalculate totals based on filtered sections
      const total_students = filteredOverview.reduce((sum, item) => sum + item.students_count, 0);
      const total_scheduled = filteredOverview.reduce((sum, item) => sum + item.scheduled_slots, 0);
      const total_unscheduled = filteredOverview.reduce((sum, item) => sum + item.unscheduled_slots, 0);

      setOverview({
        ...response.data,
        overview: filteredOverview,
        total_students,
        total_scheduled,
        total_unscheduled
      });
    } catch (err) {
      console.error('Failed to load overview', err);
    }
  };

  const generateSchedules = async () => {
    if (!confirm('Generate schedules for all sections? This will create exam slots for all active students.')) {
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await api.post('/admin/schedules/generate');
      setResult(response.data);
      loadOverview();
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Generation failed');
    } finally {
      setLoading(false);
    }
  };

  const clearSchedules = async () => {
    if (!confirm('Delete all exam schedules? This cannot be undone.')) {
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      await api.delete('/admin/schedules/clear');
      setResult({ message: 'All schedules cleared successfully' });
      loadOverview();
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Failed to clear schedules');
    } finally {
      setLoading(false);
    }
  };

  const exportToCSV = () => {
    // Create a temporary link and trigger download
    const link = document.createElement('a');
    link.href = '/api/admin/schedules/export_csv';
    link.download = `exam_schedules_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Helper function to generate cross-listed code pills
  const getCrossListedCodes = (code) => {
    const parts = code.split('-');
    if (parts.length < 4) return [code];

    const term = parts[0];
    const sectionNum = parts[3];

    // Return both PSYCH-10 and STATS-60 variants
    return [
      `${term}-PSYCH-10-${sectionNum}`,
      `${term}-STATS-60-${sectionNum}`
    ];
  };

  return (
    <div>
      <div className="card" style={{ marginBottom: '2rem' }}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Schedule Generator
        </h3>

        <p style={{ marginBottom: '1rem', color: 'var(--text-light)' }}>
          This will generate exam schedules for all active students across all sections.
          Students will be randomly assigned to odd/even weeks within their section.
        </p>

        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
          <button
            onClick={generateSchedules}
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Generating...' : '🗓️ Generate All Schedules'}
          </button>
          <button
            onClick={exportToCSV}
            className="btn btn-outline"
            disabled={loading}
          >
            📥 Export to CSV
          </button>
          <button
            onClick={clearSchedules}
            className="btn btn-outline"
            disabled={loading}
            style={{ color: 'var(--error)', borderColor: 'var(--error)' }}
          >
            🗑️ Clear All Schedules
          </button>
        </div>

        {result && (
          <div className="alert alert-success" style={{ marginTop: '1rem' }}>
            <strong>✅ Success!</strong>
            <br />
            Generated {result.generated_count} exam slots
          </div>
        )}

        {error && (
          <div className="alert alert-error" style={{ marginTop: '1rem' }}>
            <strong>❌ Error:</strong> {error}
          </div>
        )}
      </div>

      {overview && (
        <div className="card">
          <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
            Schedule Overview
          </h3>

          <div style={{ marginBottom: '1.5rem' }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1rem' }}>
              <div style={{ padding: '1rem', backgroundColor: 'var(--background)', borderRadius: '0.5rem' }}>
                <div style={{ fontSize: '0.875rem', color: 'var(--text-light)' }}>Total Students</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--primary)' }}>
                  {overview.total_students}
                </div>
              </div>
              <div style={{ padding: '1rem', backgroundColor: 'var(--background)', borderRadius: '0.5rem' }}>
                <div style={{ fontSize: '0.875rem', color: 'var(--text-light)' }}>Scheduled Slots</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--success)' }}>
                  {overview.total_scheduled}
                </div>
              </div>
              <div
                style={{
                  padding: '1rem',
                  backgroundColor: 'var(--background)',
                  borderRadius: '0.5rem',
                  cursor: overview.total_unscheduled > 0 ? 'pointer' : 'default',
                  transition: 'all 0.2s',
                  border: '2px solid transparent'
                }}
                onMouseEnter={(e) => {
                  if (overview.total_unscheduled > 0) {
                    e.currentTarget.style.borderColor = 'var(--error)';
                    e.currentTarget.style.transform = 'scale(1.02)';
                  }
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.borderColor = 'transparent';
                  e.currentTarget.style.transform = 'scale(1)';
                }}
                onClick={() => {
                  if (overview.total_unscheduled > 0) {
                    setShowUnscheduledModal(true);
                  }
                }}
              >
                <div style={{ fontSize: '0.875rem', color: 'var(--text-light)' }}>
                  Unscheduled Slots {overview.total_unscheduled > 0 && '(click to manage)'}
                </div>
                <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--error)' }}>
                  {overview.total_unscheduled}
                </div>
              </div>
            </div>
          </div>

          <table className="table">
            <thead>
              <tr>
                <th>Section</th>
                <th>TA</th>
                <th>Students</th>
                <th>Scheduled</th>
                <th>Unscheduled</th>
              </tr>
            </thead>
            <tbody>
              {overview.overview.map((item, index) => {
                const codes = getCrossListedCodes(item.section.code);
                return (
                  <tr key={index}>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                        {codes.map((code, idx) => (
                          <span key={idx} className="badge badge-primary">{code}</span>
                        ))}
                      </div>
                    </td>
                    <td>{item.ta ? item.ta.full_name : 'No TA'}</td>
                    <td>{item.students_count}</td>
                    <td>
                      <span className="badge badge-success">{item.scheduled_slots}</span>
                    </td>
                    <td>
                      <span className="badge badge-error">{item.unscheduled_slots_count || item.unscheduled_slots}</span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Unscheduled Slots Selection Modal */}
      {showUnscheduledModal && !selectedExam && (
        <div
          onClick={() => setShowUnscheduledModal(false)}
          style={{
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
          }}
        >
          <div
            className="card"
            onClick={(e) => e.stopPropagation()}
            style={{ maxWidth: '600px', width: '90%' }}
          >
            <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
              Select Exam & Week to Manage
            </h3>
            <p style={{ marginBottom: '1.5rem', color: 'var(--text-light)' }}>
              Choose which oral exam and week type to view unscheduled students for:
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '1rem' }}>
              {[1, 2, 3, 4, 5].map(examNum => (
                <div key={examNum} style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                  <h4 style={{ fontSize: '1rem', marginBottom: '0.5rem' }}>Oral Exam #{examNum}</h4>
                  <button
                    onClick={() => {
                      setSelectedExam(examNum);
                      setSelectedWeek('odd');
                    }}
                    className="btn btn-outline"
                    style={{ width: '100%' }}
                  >
                    Odd Week
                  </button>
                  <button
                    onClick={() => {
                      setSelectedExam(examNum);
                      setSelectedWeek('even');
                    }}
                    className="btn btn-outline"
                    style={{ width: '100%' }}
                  >
                    Even Week
                  </button>
                </div>
              ))}
            </div>

            <div style={{ marginTop: '1.5rem' }}>
              <button
                onClick={() => setShowUnscheduledModal(false)}
                className="btn btn-outline"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Actual Unscheduled Slots Modal */}
      {selectedExam && selectedWeek && (
        <UnscheduledSlotsModal
          examNumber={selectedExam}
          weekType={selectedWeek}
          onClose={() => {
            setSelectedExam(null);
            setSelectedWeek(null);
            setShowUnscheduledModal(false);
            loadOverview();
          }}
          onScheduled={() => {
            loadOverview();
          }}
        />
      )}
    </div>
  );
}
