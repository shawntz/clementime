import { useState } from 'react';
import api from '../../services/api';

export default function SlackControlCenter() {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [testingRecording, setTestingRecording] = useState(false);

  const sendTASchedules = async (examNumber, weekType) => {
    if (!confirm(`Send schedule to all TAs for Oral Exam #${examNumber} (${weekType} week)?`)) {
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await api.post('/admin/slack_messages/send_ta_schedules', {
        exam_number: examNumber,
        week_type: weekType
      });

      setResult({
        type: 'ta',
        examNumber,
        weekType,
        ...response.data
      });
    } catch (err) {
      setError(err.response?.data?.errors || 'Failed to send TA schedules');
    } finally {
      setLoading(false);
    }
  };

  const sendStudentSchedules = async (examNumber, weekType) => {
    if (!confirm(`Send schedules to all students for Oral Exam #${examNumber} (${weekType} week)?\n\nThis will LOCK the schedules and prevent further changes.`)) {
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await api.post('/admin/slack_messages/send_student_schedules', {
        exam_number: examNumber,
        week_type: weekType
      });

      setResult({
        type: 'student',
        examNumber,
        weekType,
        ...response.data
      });
    } catch (err) {
      setError(err.response?.data?.errors || 'Failed to send student schedules');
    } finally {
      setLoading(false);
    }
  };

  const testRecording = async () => {
    setTestingRecording(true);
    setError(null);

    try {
      const response = await api.post('/admin/slack_messages/test_recording');
      alert(`Recording test successful!\n\n${response.data.message}`);
    } catch (err) {
      setError(err.response?.data?.error || 'Recording test failed');
    } finally {
      setTestingRecording(false);
    }
  };

  return (
    <div>
      <div className="card" style={{ marginBottom: '1.5rem' }}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          🚀 Slack Control Center
        </h3>
        <p style={{ color: 'var(--text-light)', marginBottom: '1.5rem' }}>
          Send schedule notifications to TAs and students. Student schedules will be locked after sending.
        </p>

        {/* Recording Test */}
        <div style={{
          padding: '1rem',
          backgroundColor: 'var(--bg-light)',
          borderRadius: '8px',
          marginBottom: '1.5rem'
        }}>
          <h4 style={{ marginBottom: '0.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            🎙️ Recording Test
          </h4>
          <p style={{ fontSize: '0.875rem', color: 'var(--text-light)', marginBottom: '1rem' }}>
            Test the recording system without affecting student data
          </p>
          <button
            onClick={testRecording}
            disabled={testingRecording}
            className="btn btn-primary"
          >
            {testingRecording ? 'Testing...' : 'Test Recording System'}
          </button>
        </div>

        {/* Exam Selection Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '1.5rem' }}>
          {[1, 2, 3, 4, 5].map(examNumber => (
            <div key={examNumber} style={{
              border: '2px solid var(--border)',
              borderRadius: '8px',
              padding: '1rem'
            }}>
              <h4 style={{ marginBottom: '1rem', color: 'var(--primary)' }}>
                Oral Exam #{examNumber}
              </h4>

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '1rem' }}>
                {/* Odd Week */}
                <div style={{
                  padding: '1rem',
                  backgroundColor: 'rgba(255, 152, 0, 0.05)',
                  borderRadius: '6px',
                  border: '1px solid rgba(255, 152, 0, 0.2)'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '0.75rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    📅 Odd Week
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                    <button
                      onClick={() => sendTASchedules(examNumber, 'odd')}
                      disabled={loading}
                      className="btn btn-outline"
                      style={{ fontSize: '0.875rem' }}
                    >
                      📨 Send to TAs
                    </button>
                    <button
                      onClick={() => sendStudentSchedules(examNumber, 'odd')}
                      disabled={loading}
                      className="btn btn-primary"
                      style={{ fontSize: '0.875rem' }}
                    >
                      🔒 Send to Students & Lock
                    </button>
                  </div>
                </div>

                {/* Even Week */}
                <div style={{
                  padding: '1rem',
                  backgroundColor: 'rgba(33, 150, 243, 0.05)',
                  borderRadius: '6px',
                  border: '1px solid rgba(33, 150, 243, 0.2)'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '0.75rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    📅 Even Week
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                    <button
                      onClick={() => sendTASchedules(examNumber, 'even')}
                      disabled={loading}
                      className="btn btn-outline"
                      style={{ fontSize: '0.875rem' }}
                    >
                      📨 Send to TAs
                    </button>
                    <button
                      onClick={() => sendStudentSchedules(examNumber, 'even')}
                      disabled={loading}
                      className="btn btn-primary"
                      style={{ fontSize: '0.875rem' }}
                    >
                      🔒 Send to Students & Lock
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Results Display */}
      {loading && (
        <div className="card">
          <div className="spinner" />
          <p style={{ textAlign: 'center', marginTop: '1rem' }}>Sending messages...</p>
        </div>
      )}

      {error && (
        <div className="card" style={{ backgroundColor: 'rgba(244, 67, 54, 0.1)', border: '2px solid var(--error)' }}>
          <h4 style={{ color: 'var(--error)', marginBottom: '0.5rem' }}>❌ Error</h4>
          <p>{error}</p>
        </div>
      )}

      {result && (
        <div className="card" style={{ backgroundColor: 'rgba(76, 175, 80, 0.1)', border: '2px solid var(--success)' }}>
          <h4 style={{ color: 'var(--success)', marginBottom: '1rem' }}>
            ✅ {result.message}
          </h4>

          <div style={{ marginBottom: '1rem' }}>
            <p><strong>Oral Exam:</strong> #{result.examNumber}</p>
            <p><strong>Week Type:</strong> {result.weekType}</p>
            <p><strong>Messages Sent:</strong> {result.sent_count}</p>
            {result.locked_count > 0 && (
              <p><strong>Schedules Locked:</strong> {result.locked_count}</p>
            )}
          </div>

          {result.results && result.results.length > 0 && (
            <details style={{ marginTop: '1rem' }}>
              <summary style={{ cursor: 'pointer', fontWeight: 'bold', marginBottom: '0.5rem' }}>
                View Details ({result.results.length} items)
              </summary>
              <div style={{
                maxHeight: '300px',
                overflowY: 'auto',
                backgroundColor: 'white',
                padding: '1rem',
                borderRadius: '4px',
                marginTop: '0.5rem'
              }}>
                {result.type === 'ta' ? (
                  <table className="table" style={{ fontSize: '0.875rem' }}>
                    <thead>
                      <tr>
                        <th>TA</th>
                        <th>Section</th>
                        <th>Students</th>
                      </tr>
                    </thead>
                    <tbody>
                      {result.results.map((item, idx) => (
                        <tr key={idx}>
                          <td>{item.ta}</td>
                          <td>{item.section}</td>
                          <td>{item.student_count}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                ) : (
                  <table className="table" style={{ fontSize: '0.875rem' }}>
                    <thead>
                      <tr>
                        <th>Student</th>
                        <th>Time</th>
                        <th>Locked</th>
                      </tr>
                    </thead>
                    <tbody>
                      {result.results.map((item, idx) => (
                        <tr key={idx}>
                          <td>{item.student}</td>
                          <td>{item.time}</td>
                          <td>
                            {item.locked && (
                              <span className="badge badge-success">🔒 Locked</span>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            </details>
          )}

          {result.errors && result.errors.length > 0 && (
            <details style={{ marginTop: '1rem' }}>
              <summary style={{ cursor: 'pointer', fontWeight: 'bold', color: 'var(--error)', marginBottom: '0.5rem' }}>
                ⚠️ Errors ({result.errors.length})
              </summary>
              <ul style={{
                marginTop: '0.5rem',
                padding: '1rem',
                backgroundColor: 'rgba(244, 67, 54, 0.05)',
                borderRadius: '4px'
              }}>
                {result.errors.map((err, idx) => (
                  <li key={idx} style={{ color: 'var(--error)', fontSize: '0.875rem' }}>{err}</li>
                ))}
              </ul>
            </details>
          )}
        </div>
      )}
    </div>
  );
}
