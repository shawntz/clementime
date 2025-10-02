import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function UnscheduledSlotsModal({ examNumber, weekType, onClose, onScheduled }) {
  const [slots, setSlots] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedSlot, setSelectedSlot] = useState(null);
  const [scheduleData, setScheduleData] = useState({
    date: '',
    start_time: '',
    end_time: ''
  });

  useEffect(() => {
    loadUnscheduledSlots();
  }, [examNumber, weekType]);

  const loadUnscheduledSlots = async () => {
    setLoading(true);
    try {
      const response = await api.get('/admin/schedules/overview');

      // Filter unscheduled slots for this exam and week type
      const allSlots = response.data.sections?.flatMap(section =>
        section.unscheduled_slots?.filter(slot =>
          slot.exam_number === examNumber &&
          slot.week_type === weekType
        ) || []
      ) || [];

      setSlots(allSlots);
    } catch (err) {
      console.error('Failed to load unscheduled slots', err);
    } finally {
      setLoading(false);
    }
  };

  const handleManualSchedule = async () => {
    if (!selectedSlot || !scheduleData.date || !scheduleData.start_time || !scheduleData.end_time) {
      alert('Please fill in all fields');
      return;
    }

    try {
      await api.post(`/admin/exam_slots/${selectedSlot.id}/manual_schedule`, scheduleData);

      alert('Slot scheduled successfully!');
      setSelectedSlot(null);
      setScheduleData({ date: '', start_time: '', end_time: '' });
      loadUnscheduledSlots();

      if (onScheduled) {
        onScheduled();
      }
    } catch (err) {
      alert(err.response?.data?.errors || 'Failed to schedule slot');
    }
  };

  const handleUnlockSlot = async (slotId) => {
    if (!confirm('Unlock this schedule? This should only be done in emergency situations.')) {
      return;
    }

    try {
      await api.post(`/admin/exam_slots/${slotId}/unlock`);
      alert('Schedule unlocked successfully');
      loadUnscheduledSlots();
    } catch (err) {
      alert(err.response?.data?.errors || 'Failed to unlock schedule');
    }
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
        zIndex: 1000
      }}
    >
      <div
        className="card"
        onClick={(e) => e.stopPropagation()}
        style={{ maxWidth: '900px', width: '90%', maxHeight: '80vh', overflow: 'auto' }}
      >
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Unscheduled Slots - Oral Exam #{examNumber} ({weekType} week)
        </h3>

        {loading ? (
          <div className="spinner" />
        ) : slots.length === 0 ? (
          <p style={{ color: 'var(--success)', textAlign: 'center', padding: '2rem' }}>
            ✅ All students are scheduled!
          </p>
        ) : (
          <>
            <div style={{ marginBottom: '1.5rem', padding: '1rem', backgroundColor: 'var(--bg-light)', borderRadius: '8px' }}>
              <p style={{ margin: 0, fontSize: '0.875rem', color: 'var(--text-light)' }}>
                <strong>{slots.length}</strong> student{slots.length !== 1 ? 's' : ''} need{slots.length === 1 ? 's' : ''} to be scheduled
              </p>
            </div>

            <table className="table">
              <thead>
                <tr>
                  <th>Student</th>
                  <th>Section</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {slots.map((slot) => (
                  <tr key={slot.id}>
                    <td>{slot.student.full_name}</td>
                    <td>
                      <span className="badge badge-primary">{slot.section.name}</span>
                    </td>
                    <td>
                      {slot.is_locked ? (
                        <span className="badge badge-error">🔒 Locked</span>
                      ) : (
                        <span className="badge badge-warning">Unscheduled</span>
                      )}
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        {slot.is_locked ? (
                          <button
                            onClick={() => handleUnlockSlot(slot.id)}
                            className="btn btn-outline"
                            style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                          >
                            🔓 Unlock
                          </button>
                        ) : (
                          <button
                            onClick={() => setSelectedSlot(slot)}
                            className="btn btn-primary"
                            style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                          >
                            📅 Schedule
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </>
        )}

        {/* Manual Scheduling Form */}
        {selectedSlot && (
          <div style={{
            marginTop: '1.5rem',
            padding: '1rem',
            backgroundColor: 'rgba(255, 152, 0, 0.1)',
            borderRadius: '8px',
            border: '2px solid var(--primary)'
          }}>
            <h4 style={{ marginBottom: '1rem' }}>
              Schedule: {selectedSlot.student.full_name}
            </h4>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1rem' }}>
              <div>
                <label className="form-label">Date</label>
                <input
                  type="date"
                  className="form-input"
                  value={scheduleData.date}
                  onChange={(e) => setScheduleData({ ...scheduleData, date: e.target.value })}
                />
              </div>
              <div>
                <label className="form-label">Start Time</label>
                <input
                  type="time"
                  className="form-input"
                  value={scheduleData.start_time}
                  onChange={(e) => setScheduleData({ ...scheduleData, start_time: e.target.value })}
                />
              </div>
              <div>
                <label className="form-label">End Time</label>
                <input
                  type="time"
                  className="form-input"
                  value={scheduleData.end_time}
                  onChange={(e) => setScheduleData({ ...scheduleData, end_time: e.target.value })}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button
                onClick={handleManualSchedule}
                className="btn btn-primary"
              >
                ✅ Confirm Schedule
              </button>
              <button
                onClick={() => setSelectedSlot(null)}
                className="btn btn-outline"
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        <div style={{ marginTop: '1rem' }}>
          <button onClick={onClose} className="btn btn-outline">
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
