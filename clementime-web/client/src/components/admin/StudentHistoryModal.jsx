import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function StudentHistoryModal({ student, onClose }) {
  const [selectedExam, setSelectedExam] = useState(1);
  const [history, setHistory] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadHistory(selectedExam);
  }, [selectedExam]);

  const loadHistory = async (examNumber) => {
    setLoading(true);
    try {
      const response = await api.get(
        `/admin/students/${student.id}/exam_slots/${examNumber}/histories`
      );
      setHistory(response.data);
    } catch (err) {
      console.error('Failed to load history', err);
    } finally {
      setLoading(false);
    }
  };

  const revertToHistory = async (historyId) => {
    if (!confirm('Revert to this previous schedule?')) return;

    try {
      await api.post(
        `/admin/students/${student.id}/exam_slots/${selectedExam}/histories/${historyId}/revert`
      );
      loadHistory(selectedExam);
      alert('Schedule reverted successfully');
    } catch (err) {
      alert('Failed to revert schedule');
    }
  };

  const formatDateTime = (datetime) => {
    if (!datetime) return 'N/A';
    return new Date(datetime).toLocaleString();
  };

  return (
    <div
      onClick={onClose}
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
        style={{ maxWidth: '900px', width: '90%', maxHeight: '80vh', overflow: 'auto' }}
      >
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Schedule History: {student.full_name}
        </h3>

        {/* Exam Tabs */}
        <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1.5rem', flexWrap: 'wrap' }}>
          {[1, 2, 3, 4, 5].map((examNum) => (
            <button
              key={examNum}
              onClick={() => setSelectedExam(examNum)}
              className={`btn ${selectedExam === examNum ? 'btn-primary' : 'btn-outline'}`}
              style={{ fontSize: '0.875rem' }}
            >
              Oral Exam {examNum}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="spinner" />
        ) : (
          <div>
            {/* Current Schedule */}
            <div style={{ marginBottom: '2rem' }}>
              <h4 style={{ color: 'var(--primary)', marginBottom: '0.5rem' }}>Current Schedule</h4>
              {history?.current ? (
                <div
                  className="card"
                  style={{ backgroundColor: 'var(--background)', padding: '1rem' }}
                >
                  <div
                    style={{ display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '0.5rem 1rem' }}
                  >
                    <strong>Week:</strong>
                    <span>{history.current.week_number}</span>
                    <strong>Date:</strong>
                    <span>{history.current.date || 'Not scheduled'}</span>
                    <strong>Time:</strong>
                    <span>{history.current.formatted_time}</span>
                    <strong>Section:</strong>
                    <span>{history.current.section?.name}</span>
                    <strong>Status:</strong>
                    <span
                      className={`badge ${history.current.is_scheduled ? 'badge-success' : 'badge-warning'}`}
                    >
                      {history.current.is_scheduled ? 'Scheduled' : 'Unscheduled'}
                    </span>
                  </div>
                </div>
              ) : (
                <p style={{ color: 'var(--text-light)' }}>No slot created yet for this exam</p>
              )}
            </div>

            {/* History */}
            <div>
              <h4 style={{ color: 'var(--primary)', marginBottom: '0.5rem' }}>
                Previous Schedules ({history?.histories?.length || 0})
              </h4>
              {history?.histories?.length === 0 ? (
                <p style={{ color: 'var(--text-light)' }}>No history available</p>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                  {history?.histories?.map((hist) => (
                    <div
                      key={hist.id}
                      className="card"
                      style={{ backgroundColor: 'var(--background)', padding: '1rem' }}
                    >
                      <div
                        style={{
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'start',
                          marginBottom: '0.5rem',
                        }}
                      >
                        <div style={{ fontSize: '0.875rem', color: 'var(--text-light)' }}>
                          Changed: {formatDateTime(hist.changed_at)}
                        </div>
                        <button
                          onClick={() => revertToHistory(hist.id)}
                          className="btn btn-outline"
                          style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                        >
                          Revert to This
                        </button>
                      </div>
                      <div
                        style={{
                          display: 'grid',
                          gridTemplateColumns: 'auto 1fr',
                          gap: '0.5rem 1rem',
                        }}
                      >
                        <strong>Week:</strong>
                        <span>{hist.week_number}</span>
                        <strong>Date:</strong>
                        <span>{hist.date || 'Not scheduled'}</span>
                        <strong>Time:</strong>
                        <span>
                          {hist.start_time && hist.end_time
                            ? `${hist.start_time} - ${hist.end_time}`
                            : 'Not scheduled'}
                        </span>
                        <strong>Section:</strong>
                        <span>{hist.section?.name}</span>
                        <strong>Status:</strong>
                        <span
                          className={`badge ${hist.is_scheduled ? 'badge-success' : 'badge-warning'}`}
                        >
                          {hist.is_scheduled ? 'Scheduled' : 'Unscheduled'}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        <div style={{ marginTop: '1.5rem' }}>
          <button onClick={onClose} className="btn btn-outline">
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
