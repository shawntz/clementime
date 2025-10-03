import { useState, useEffect } from 'react';
import api from '../../services/api';
import AudioRecorder from './AudioRecorder';

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

export default function WeeklySchedule({ weekNumber }) {
  const [schedules, setSchedules] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedSlot, setSelectedSlot] = useState(null);

  useEffect(() => {
    loadSchedule();
  }, [weekNumber]);

  const loadSchedule = async () => {
    setLoading(true);
    try {
      const response = await api.get(`/ta/schedules?week_number=${weekNumber}`);
      setSchedules(response.data.schedules);
    } catch (err) {
      console.error('Failed to load schedule', err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="spinner" />;
  }

  if (schedules.length === 0) {
    return (
      <div className="alert alert-info">
        No schedules assigned for Week {weekNumber}
      </div>
    );
  }

  return (
    <div>
      {schedules.map((schedule) => {
        const codes = getCrossListedCodes(schedule.section.code);
        return (
          <div key={schedule.section.id} className="card" style={{ marginBottom: '2rem' }}>
            <div style={{ marginBottom: '1rem' }}>
              <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', marginBottom: '0.5rem', flexWrap: 'wrap' }}>
                {codes.map((code, idx) => (
                  <span key={idx} className="badge badge-primary" style={{ fontSize: '0.875rem' }}>{code}</span>
                ))}
                <span style={{ fontSize: '1rem', fontWeight: 'bold', color: 'var(--primary)' }}>
                  - {schedule.section.name}
                </span>
              </div>
              <p style={{ color: 'var(--text-light)', margin: 0 }}>
                📍 Location: {schedule.section.location || 'TBD'}
              </p>
            </div>

            {schedule.slots.length === 0 ? (
              <p style={{ color: 'var(--text-light)' }}>No exams scheduled for this week</p>
            ) : (
              <table className="table">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Student</th>
                    <th>Exam #</th>
                    <th>Recording</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {schedule.slots.map((slot) => (
                    <tr key={slot.id}>
                      <td>{slot.formatted_time}</td>
                      <td>{slot.student.full_name}</td>
                      <td>
                        <span className="badge badge-primary">Exam {slot.exam_number}</span>
                      </td>
                      <td>
                        {slot.has_recording ? (
                          <span className="badge badge-success">
                            {slot.recording.uploaded ? '✓ Uploaded' : '⏳ Pending Upload'}
                          </span>
                        ) : (
                          <span className="badge badge-warning">Not recorded</span>
                        )}
                      </td>
                      <td>
                        {slot.has_recording && slot.recording.uploaded && slot.recording.recording_url ? (
                          <a
                            href={slot.recording.recording_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="btn btn-outline"
                            style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                          >
                            ▶️ Play
                          </a>
                        ) : !slot.has_recording ? (
                          <button
                            onClick={() => setSelectedSlot(slot)}
                            className="btn btn-primary"
                            style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                          >
                            🎙️ Record
                          </button>
                        ) : null}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        );
      })}

      {selectedSlot && (
        <AudioRecorder
          slot={selectedSlot}
          onClose={() => {
            setSelectedSlot(null);
            loadSchedule();
          }}
        />
      )}
    </div>
  );
}
