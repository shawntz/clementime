import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function TimeSlotManager() {
  const [sections, setSections] = useState([]);
  const [selectedSection, setSelectedSection] = useState('');
  const [selectedExam, setSelectedExam] = useState(1);
  const [slots, setSlots] = useState([]);
  const [loading, setLoading] = useState(false);
  const [editingSlot, setEditingSlot] = useState(null);

  useEffect(() => {
    loadSections();
  }, []);

  useEffect(() => {
    if (selectedSection) {
      loadSlots();
    }
  }, [selectedSection, selectedExam]);

  const loadSections = async () => {
    try {
      const response = await api.get('/admin/sections');
      const filtered = response.data.sections.filter(s => {
        const parts = s.code.split('-');
        return parts.length >= 4 && parseInt(parts[3]) !== 1;
      });
      setSections(filtered);
      if (filtered.length > 0) {
        setSelectedSection(filtered[0].id.toString());
      }
    } catch (err) {
      console.error('Failed to load sections', err);
    }
  };

  const loadSlots = async () => {
    setLoading(true);
    try {
      const response = await api.get(`/admin/sections/${selectedSection}/time_slots`, {
        params: { exam_number: selectedExam }
      });
      setSlots(response.data.slots);
    } catch (err) {
      console.error('Failed to load slots', err);
    } finally {
      setLoading(false);
    }
  };

  const updateSlotTime = async (slotId, newStartTime, newEndTime) => {
    try {
      await api.put(`/admin/exam_slots/${slotId}/update_time`, {
        start_time: newStartTime,
        end_time: newEndTime
      });
      loadSlots();
      setEditingSlot(null);
      alert('Time slot updated successfully');
    } catch (err) {
      alert('Failed to update time slot: ' + (err.response?.data?.errors?.join(', ') || err.message));
    }
  };

  const getAvailableTimeSlots = (currentSlot) => {
    // Get all occupied slots for this exam in this section (excluding current student)
    const occupiedSlots = slots.filter(s => s.id !== currentSlot.id && s.is_scheduled);

    // Generate all possible time slots based on configuration
    const allTimeSlots = [];
    const duration = 7; // minutes
    const buffer = 1; // minutes

    // Parse exam time range from existing slots or use defaults
    let startHour = 13;
    let startMinute = 30;
    let endHour = 15;
    let endMinute = 0;

    // Try to get actual start/end times from scheduled slots
    const scheduledSlots = slots.filter(s => s.is_scheduled && s.start_time);
    if (scheduledSlots.length > 0) {
      // Find earliest start time
      const earliestSlot = scheduledSlots.reduce((earliest, slot) => {
        return slot.start_time < earliest.start_time ? slot : earliest;
      });
      const [h, m] = earliestSlot.start_time.split(':');
      startHour = parseInt(h);
      startMinute = parseInt(m);

      // Find latest end time
      const latestSlot = scheduledSlots.reduce((latest, slot) => {
        return slot.end_time > latest.end_time ? slot : latest;
      });
      const [eh, em] = latestSlot.end_time.split(':');
      endHour = parseInt(eh);
      endMinute = parseInt(em);
    }

    let currentTime = new Date(2000, 0, 1, startHour, startMinute);
    const endTime = new Date(2000, 0, 1, endHour, endMinute);

    while (currentTime < endTime) {
      const slotEndTime = new Date(currentTime.getTime() + duration * 60000);
      if (slotEndTime <= endTime) {
        const timeStr = currentTime.toTimeString().substring(0, 5);
        const endTimeStr = slotEndTime.toTimeString().substring(0, 5);

        // Find ALL slots (both odd and even) occupying this time
        const occupyingSlotsAtTime = occupiedSlots.filter(s => s.start_time === timeStr);

        allTimeSlots.push({
          start: timeStr,
          end: endTimeStr,
          occupiedSlots: occupyingSlotsAtTime // Array of all students at this time
        });
      }
      currentTime = new Date(slotEndTime.getTime() + buffer * 60000);
    }

    return allTimeSlots;
  };

  const TimeSlotEditor = ({ slot }) => {
    const availableSlots = getAvailableTimeSlots(slot);
    const currentTimeKey = `${slot.start_time}-${slot.end_time}`;

    return (
      <div style={{ padding: '0.5rem 0' }}>
        <select
          className="form-input"
          value={currentTimeKey}
          onChange={(e) => {
            const [start, end] = e.target.value.split('-');
            if (confirm(`Update ${slot.student.full_name}'s time slot to ${start} - ${end}?`)) {
              updateSlotTime(slot.id, start, end);
            }
          }}
          style={{ width: '100%', fontSize: '0.875rem' }}
        >
          {availableSlots.map((timeSlot) => {
            const key = `${timeSlot.start}-${timeSlot.end}`;
            const isSelected = key === currentTimeKey;

            let label = `${timeSlot.start} - ${timeSlot.end}`;

            if (timeSlot.occupiedSlots.length > 0 && !isSelected) {
              // Show all students occupying this time slot
              const occupantNames = timeSlot.occupiedSlots.map(s =>
                `${s.student.full_name} - ${s.week_group}`
              ).join(', ');
              label += ` (${occupantNames})`;
            } else if (isSelected) {
              label += ' (Current)';
            }

            return (
              <option key={key} value={key}>
                {label}
              </option>
            );
          })}
        </select>
      </div>
    );
  };

  // Group slots by week
  const oddWeekSlots = slots.filter(s => s.week_group === 'odd');
  const evenWeekSlots = slots.filter(s => s.week_group === 'even');

  return (
    <div>
      <div className="card" style={{ marginBottom: '1.5rem' }}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Time Slot Manager
        </h3>

        <div style={{ display: 'flex', gap: '1rem', marginBottom: '1.5rem', flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: '200px' }}>
            <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Section
            </label>
            <select
              className="form-input"
              value={selectedSection}
              onChange={(e) => setSelectedSection(e.target.value)}
              style={{ width: '100%' }}
            >
              {sections.map(section => (
                <option key={section.id} value={section.id}>
                  {section.name}
                </option>
              ))}
            </select>
          </div>

          <div style={{ minWidth: '200px' }}>
            <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Oral Exam
            </label>
            <select
              className="form-input"
              value={selectedExam}
              onChange={(e) => setSelectedExam(parseInt(e.target.value))}
              style={{ width: '100%' }}
            >
              {[1, 2, 3, 4, 5].map(num => (
                <option key={num} value={num}>Oral Exam {num}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {loading ? (
        <div className="spinner" />
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem' }}>
          {/* Odd Week Slots */}
          <div className="card">
            <h4 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
              Odd Weeks ({oddWeekSlots.length} students)
            </h4>
            {oddWeekSlots.length === 0 ? (
              <p style={{ color: 'var(--text-light)' }}>No students scheduled</p>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                {oddWeekSlots.map(slot => (
                  <div key={slot.id} style={{
                    padding: '1rem',
                    backgroundColor: 'var(--background)',
                    borderRadius: '0.5rem',
                    border: '1px solid var(--border)'
                  }}>
                    <div style={{ marginBottom: '0.5rem' }}>
                      <strong>{slot.student.full_name}</strong>
                    </div>
                    <div style={{ fontSize: '0.875rem', color: 'var(--text-light)', marginBottom: '0.5rem' }}>
                      Week {slot.week_number} • {slot.date}
                    </div>
                    {slot.is_scheduled ? (
                      <TimeSlotEditor slot={slot} />
                    ) : (
                      <div style={{ color: 'var(--text-light)', fontSize: '0.875rem' }}>
                        Not scheduled
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Even Week Slots */}
          <div className="card">
            <h4 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
              Even Weeks ({evenWeekSlots.length} students)
            </h4>
            {evenWeekSlots.length === 0 ? (
              <p style={{ color: 'var(--text-light)' }}>No students scheduled</p>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                {evenWeekSlots.map(slot => (
                  <div key={slot.id} style={{
                    padding: '1rem',
                    backgroundColor: 'var(--background)',
                    borderRadius: '0.5rem',
                    border: '1px solid var(--border)'
                  }}>
                    <div style={{ marginBottom: '0.5rem' }}>
                      <strong>{slot.student.full_name}</strong>
                    </div>
                    <div style={{ fontSize: '0.875rem', color: 'var(--text-light)', marginBottom: '0.5rem' }}>
                      Week {slot.week_number} • {slot.date}
                    </div>
                    {slot.is_scheduled ? (
                      <TimeSlotEditor slot={slot} />
                    ) : (
                      <div style={{ color: 'var(--text-light)', fontSize: '0.875rem' }}>
                        Not scheduled
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
