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
  const [showRegenerateModal, setShowRegenerateModal] = useState(false);
  const [startExam, setStartExam] = useState(1);

  useEffect(() => {
    loadOverview();
  }, []);

  const loadOverview = async () => {
    try {
      const response = await api.get('/admin/schedules/overview');

      // Filter out section 01 and sort by section number
      const filteredOverview = response.data.overview.filter((item) => {
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
      const total_unscheduled = filteredOverview.reduce(
        (sum, item) => sum + item.unscheduled_slots_count,
        0
      );

      setOverview({
        ...response.data,
        overview: filteredOverview,
        total_students,
        total_scheduled,
        total_unscheduled,
      });
    } catch (err) {
      console.error('Failed to load overview', err);
    }
  };

  const generateSchedules = async () => {
    if (
      !confirm(
        'Generate schedules for all sections? This will create exam slots for all active students.'
      )
    ) {
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

  const regenerateFromExam = async () => {
    if (startExam < 1) {
      alert('Please enter a valid exam number (1 or greater)');
      return;
    }

    if (
      !confirm(
        `Regenerate schedules from Exam ${startExam} onwards? This will preserve all exam schedules before Exam ${startExam} and regenerate the rest.`
      )
    ) {
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);
    setShowRegenerateModal(false);

    try {
      const response = await api.post('/admin/schedules/generate', {
        start_exam: startExam,
      });
      setResult(response.data);
      loadOverview();
      alert(response.data.message);
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Regeneration failed');
    } finally {
      setLoading(false);
    }
  };

  const scheduleNewStudents = async () => {
    if (
      !confirm(
        'Schedule new students only? This will add new/unscheduled students to the END of existing schedules without affecting anyone else.'
      )
    ) {
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await api.post('/admin/schedules/schedule_new_students');
      const data = response.data;

      let message = `✅ ${data.scheduled_count} slots scheduled`;
      if (data.unscheduled_count > 0) {
        message += `\n⚠️ ${data.unscheduled_count} slots couldn't fit (exceeded exam time)`;
      }
      if (data.students_processed.length > 0) {
        message += `\n\nStudents processed:\n${data.students_processed
          .map((s) => `• ${s.full_name}: ${s.scheduled} scheduled, ${s.unscheduled} unscheduled`)
          .join('\n')}`;
      }

      alert(message);
      setResult(data);
      loadOverview();
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Failed to schedule new students');
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

  const exportToCSV = async () => {
    try {
      const response = await api.get('/admin/schedules/export_csv', {
        responseType: 'blob',
      });

      // Create a blob from the response
      const blob = new Blob([response.data], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);

      // Create a temporary link and trigger download
      const link = document.createElement('a');
      link.href = url;
      link.download = `exam_schedules_${new Date().toISOString().split('T')[0]}.csv`;
      document.body.appendChild(link);
      link.click();

      // Cleanup
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Failed to export CSV', err);
      let errorMessage = 'Failed to export CSV';
      if (err.response?.data instanceof Blob) {
        // If error response is a blob (JSON), parse it
        try {
          const text = await err.response.data.text();
          const errorData = JSON.parse(text);
          errorMessage = errorData.error || errorMessage;
        } catch {
          errorMessage = err.message;
        }
      } else {
        errorMessage = err.response?.data?.error || err.message;
      }
      alert(errorMessage);
    }
  };

  // Helper function to generate cross-listed code pills
  const getCrossListedCodes = (code) => {
    const parts = code.split('-');
    if (parts.length < 4) return [code];

    const term = parts[0];
    const sectionNum = parts[3];

    // Return both PSYCH-10 and STATS-60 variants
    return [`${term}-PSYCH-10-${sectionNum}`, `${term}-STATS-60-${sectionNum}`];
  };

  return (
    <div>
      <div className="card" style={{ marginBottom: '2rem' }}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>Schedule Generator</h3>

        <p style={{ marginBottom: '1rem', color: 'var(--text-light)' }}>
          This will generate exam schedules for all active students across all sections. Students
          will be randomly assigned to odd/even weeks within their section.
        </p>

        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
          <button onClick={generateSchedules} className="btn btn-primary" disabled={loading}>
            {loading ? 'Generating...' : '🗓️ Generate All Schedules'}
          </button>
          <button
            onClick={() => setShowRegenerateModal(true)}
            className="btn btn-primary"
            disabled={loading}
            style={{ backgroundColor: '#8b5cf6', borderColor: '#8b5cf6' }}
            title="Regenerate schedules starting from a specific exam number"
          >
            🔄 Regenerate from Exam #
          </button>
          <button
            onClick={scheduleNewStudents}
            className="btn btn-primary"
            disabled={loading}
            style={{ backgroundColor: 'var(--success)', borderColor: 'var(--success)' }}
            title="Add new/unscheduled students to the end of existing schedules without affecting anyone else"
          >
            {loading ? 'Scheduling...' : '➕ Schedule New Students'}
          </button>
          <button onClick={exportToCSV} className="btn btn-outline" disabled={loading}>
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
            {result.generated_count !== undefined ? (
              `Generated ${result.generated_count} exam slots`
            ) : result.scheduled_count !== undefined ? (
              <>
                Scheduled {result.scheduled_count} slots for{' '}
                {result.students_processed?.length || 0} students
                {result.unscheduled_count > 0 && (
                  <>
                    <br />
                    ⚠️ {result.unscheduled_count} slots couldn't fit (exceeded exam time)
                  </>
                )}
              </>
            ) : (
              result.message
            )}
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
          <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>Schedule Overview</h3>

          <div style={{ marginBottom: '1.5rem' }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1rem' }}>
              <div
                style={{
                  padding: '1rem',
                  backgroundColor: 'var(--background)',
                  borderRadius: '0.5rem',
                }}
              >
                <div style={{ fontSize: '0.875rem', color: 'var(--text-light)' }}>
                  Total Students
                </div>
                <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--primary)' }}>
                  {overview.total_students}
                </div>
              </div>
              <div
                style={{
                  padding: '1rem',
                  backgroundColor: 'var(--background)',
                  borderRadius: '0.5rem',
                }}
              >
                <div style={{ fontSize: '0.875rem', color: 'var(--text-light)' }}>
                  Scheduled Slots
                </div>
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
                  border: '2px solid transparent',
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
                          <span key={idx} className="badge badge-primary">
                            {code}
                          </span>
                        ))}
                      </div>
                    </td>
                    <td>{item.ta ? item.ta.full_name : 'No TA'}</td>
                    <td>{item.students_count}</td>
                    <td>
                      <span className="badge badge-success">{item.scheduled_slots}</span>
                    </td>
                    <td>
                      <span className="badge badge-error">{item.unscheduled_slots_count}</span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Unscheduled Slots Selection Modal */}
      {showUnscheduledModal && !selectedExam && overview && (
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
            zIndex: 1000,
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
              {[1, 2, 3, 4, 5].map((examNum) => {
                // Calculate counts for each exam/week combination
                const oddCount = overview.overview.reduce((sum, section) => {
                  const count = section.unscheduled_slots.filter(
                    (slot) => slot.exam_number === examNum && slot.week_type === 'odd'
                  ).length;
                  return sum + count;
                }, 0);

                const evenCount = overview.overview.reduce((sum, section) => {
                  const count = section.unscheduled_slots.filter(
                    (slot) => slot.exam_number === examNum && slot.week_type === 'even'
                  ).length;
                  return sum + count;
                }, 0);

                return (
                  <div
                    key={examNum}
                    style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}
                  >
                    <h4 style={{ fontSize: '1rem', marginBottom: '0.5rem' }}>
                      Oral Exam #{examNum}
                    </h4>
                    <button
                      onClick={() => {
                        setSelectedExam(examNum);
                        setSelectedWeek('odd');
                      }}
                      disabled={oddCount === 0}
                      className="btn btn-outline"
                      style={{
                        width: '100%',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        opacity: oddCount === 0 ? 0.5 : 1,
                        cursor: oddCount === 0 ? 'not-allowed' : 'pointer',
                        backgroundColor: oddCount === 0 ? 'var(--background)' : 'transparent',
                      }}
                    >
                      <span>Odd Week</span>
                      {oddCount > 0 && (
                        <span
                          style={{
                            backgroundColor: '#ef4444',
                            color: 'white',
                            borderRadius: '50%',
                            width: '24px',
                            height: '24px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: '0.75rem',
                            fontWeight: 'bold',
                          }}
                        >
                          {oddCount}
                        </span>
                      )}
                    </button>
                    <button
                      onClick={() => {
                        setSelectedExam(examNum);
                        setSelectedWeek('even');
                      }}
                      disabled={evenCount === 0}
                      className="btn btn-outline"
                      style={{
                        width: '100%',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        opacity: evenCount === 0 ? 0.5 : 1,
                        cursor: evenCount === 0 ? 'not-allowed' : 'pointer',
                        backgroundColor: evenCount === 0 ? 'var(--background)' : 'transparent',
                      }}
                    >
                      <span>Even Week</span>
                      {evenCount > 0 && (
                        <span
                          style={{
                            backgroundColor: '#ef4444',
                            color: 'white',
                            borderRadius: '50%',
                            width: '24px',
                            height: '24px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: '0.75rem',
                            fontWeight: 'bold',
                          }}
                        >
                          {evenCount}
                        </span>
                      )}
                    </button>
                  </div>
                );
              })}
            </div>

            <div style={{ marginTop: '1.5rem' }}>
              <button onClick={() => setShowUnscheduledModal(false)} className="btn btn-outline">
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

      {/* Regenerate from Exam Modal */}
      {showRegenerateModal && (
        <div
          onClick={() => setShowRegenerateModal(false)}
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
            zIndex: 1000,
          }}
        >
          <div
            className="card"
            onClick={(e) => e.stopPropagation()}
            style={{ maxWidth: '500px', width: '90%' }}
          >
            <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
              Regenerate from Exam Number
            </h3>

            <p style={{ marginBottom: '1rem', color: 'var(--text-light)' }}>
              This will preserve all exam schedules <strong>before</strong> the specified exam
              number and regenerate everything from that exam onwards. This is useful when:
            </p>

            <ul style={{ marginBottom: '1rem', marginLeft: '1.5rem', color: 'var(--text-light)' }}>
              <li>Enabling balanced TA scheduling midway through the quarter</li>
              <li>Making major schedule changes for future exams only</li>
              <li>Preserving already-completed or locked exam schedules</li>
            </ul>

            <div style={{ marginBottom: '1rem' }}>
              <label className="form-label">Start from Exam #:</label>
              <input
                type="number"
                min="1"
                className="form-input"
                value={startExam}
                onChange={(e) => setStartExam(parseInt(e.target.value) || 1)}
                placeholder="e.g., 3"
              />
              <div
                style={{ fontSize: '0.875rem', color: 'var(--text-light)', marginTop: '0.25rem' }}
              >
                All exams before Exam #{startExam} will be preserved
              </div>
            </div>

            <div
              style={{
                padding: '0.75rem',
                backgroundColor: 'var(--warning-light)',
                borderRadius: '6px',
                marginBottom: '1rem',
                fontSize: '0.875rem',
              }}
            >
              <strong>⚠️ Note:</strong> Locked exam slots will always be preserved, regardless of
              the start exam number.
            </div>

            <div style={{ display: 'flex', gap: '1rem' }}>
              <button onClick={regenerateFromExam} className="btn btn-primary" disabled={loading}>
                {loading ? 'Regenerating...' : `Regenerate from Exam ${startExam}`}
              </button>
              <button
                onClick={() => setShowRegenerateModal(false)}
                className="btn btn-outline"
                disabled={loading}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
