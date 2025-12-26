import { useState, useEffect } from 'react';
import api from '../../services/api';
import StudentHistoryModal from './StudentHistoryModal';

export default function RosterManager() {
  const [students, setStudents] = useState([]);
  const [sections, setSections] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedSection, setSelectedSection] = useState('all');
  const [selectedCohort, setSelectedCohort] = useState('all');
  const [constraintFilter, setConstraintFilter] = useState('all');
  const [constraintType, setConstraintType] = useState('all');
  const [availableConstraintTypes, setAvailableConstraintTypes] = useState([]);
  const [selectedStudent, setSelectedStudent] = useState(null);
  const [showConstraintModal, setShowConstraintModal] = useState(false);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [showNotifyModal, setShowNotifyModal] = useState(false);
  const [showTransferModal, setShowTransferModal] = useState(false);
  const [showChangeSectionModal, setShowChangeSectionModal] = useState(false);
  const [showSwapCohortModal, setShowSwapCohortModal] = useState(false);
  const [selectedExamNumber, setSelectedExamNumber] = useState(1);
  const [transferFromExam, setTransferFromExam] = useState(1);
  const [transferToCohort, setTransferToCohort] = useState('odd');
  const [changeSectionTo, setChangeSectionTo] = useState('');
  const [swapFromExam, setSwapFromExam] = useState(1);

  useEffect(() => {
    loadData();
  }, [constraintFilter, constraintType]);

  const loadData = async () => {
    setLoading(true);
    try {
      const params = {};
      if (constraintFilter !== 'all') {
        params.constraint_filter = constraintFilter;
      }
      if (constraintType !== 'all') {
        params.constraint_type = constraintType;
      }

      const [studentsRes, sectionsRes] = await Promise.all([
        api.get('/admin/students', { params }),
        api.get('/admin/sections')
      ]);

      setStudents(studentsRes.data.students);
      setAvailableConstraintTypes(studentsRes.data.constraint_types || []);
      setSections(sectionsRes.data.sections.filter(s => {
        const parts = s.code.split('-');
        return parts.length >= 4 && parseInt(parts[3]) !== 1;
      }));
    } catch (err) {
      console.error('Failed to load data', err);
    } finally {
      setLoading(false);
    }
  };

  const toggleStudentStatus = async (studentId, currentStatus) => {
    try {
      await api.put(`/admin/students/${studentId}`, {
        is_active: !currentStatus
      });
      loadData();
    } catch (err) {
      alert('Failed to update student status');
    }
  };

  const openConstraintModal = (student) => {
    setSelectedStudent(student);
    setShowConstraintModal(true);
  };

  const openHistoryModal = (student) => {
    setSelectedStudent(student);
    setShowHistoryModal(true);
  };

  const openNotifyModal = (student) => {
    setSelectedStudent(student);
    setShowNotifyModal(true);
  };

  const openTransferModal = (student) => {
    setSelectedStudent(student);
    setTransferToCohort(student.cohort === 'odd' ? 'even' : 'odd');
    setShowTransferModal(true);
  };

  const transferCohort = async () => {
    if (!selectedStudent) return;

    try {
      await api.post(`/admin/students/${selectedStudent.id}/transfer_cohort`, {
        cohort: transferToCohort,
        from_exam: transferFromExam
      });
      alert(`Student transferred to ${transferToCohort} cohort from Exam #${transferFromExam} onwards`);
      setShowTransferModal(false);
      loadData();
    } catch (err) {
      alert(err.response?.data?.errors || 'Failed to transfer student');
    }
  };

  const openChangeSectionModal = (student) => {
    setSelectedStudent(student);
    // Set default to first different section
    const otherSection = sections.find(s => s.id !== student.section?.id);
    setChangeSectionTo(otherSection ? otherSection.id.toString() : '');
    setShowChangeSectionModal(true);
  };

  const changeSection = async () => {
    if (!selectedStudent || !changeSectionTo) return;

    if (!confirm(`This will move ${selectedStudent.full_name} to a new section and clear all their exam slots. The section override will be preserved on future roster uploads. Continue?`)) {
      return;
    }

    try {
      const response = await api.post(`/admin/students/${selectedStudent.id}/change_section`, {
        section_id: changeSectionTo
      });
      alert(response.data.message);
      setShowChangeSectionModal(false);
      loadData();
    } catch (err) {
      alert(err.response?.data?.errors || 'Failed to change section');
    }
  };

  const notifySlack = async () => {
    if (!selectedStudent) return;

    try {
      const response = await api.post(`/admin/students/${selectedStudent.id}/notify_slack`, {
        exam_number: selectedExamNumber
      });
      alert(response.data.message || `Slack notification sent for Oral Exam #${selectedExamNumber}`);
      setShowNotifyModal(false);
      loadData(); // Reload data to reflect locked status
    } catch (err) {
      const errorMsg = err.response?.data?.errors || 'Failed to send Slack notification';
      alert(errorMsg);
    }
  };

  const openSwapWeekModal = (student) => {
    setSelectedStudent(student);
    setSwapFromExam(1);
    setShowSwapCohortModal(true);
  };

  const swapToOppositeCohort = async () => {
    if (!selectedStudent) return;

    const newCohort = selectedStudent.cohort === 'odd' ? 'even' : 'odd';

    if (!confirm(`This will swap ${selectedStudent.full_name} from ${selectedStudent.cohort} cohort to ${newCohort} cohort starting from Exam ${swapFromExam}.\n\nThis will:\n- Unlock any locked exams from ${swapFromExam} onwards\n- Delete their old time slots\n- Place them at the END of the ${newCohort} cohort schedule\n- Not affect any other students\n\nContinue?`)) {
      return;
    }

    try {
      const response = await api.post(`/admin/students/${selectedStudent.id}/swap_to_opposite_cohort`, {
        from_exam: swapFromExam
      });
      alert(response.data.message + `\n\nMoved: ${response.data.moved_count} exams\nUnlocked: ${response.data.unlocked_count} exams`);
      setShowSwapCohortModal(false);
      loadData();
    } catch (err) {
      alert(err.response?.data?.errors || 'Failed to swap cohort');
    }
  };

  const filteredStudents = students.filter(student => {
    const matchesSearch = student.full_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         student.email.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesSection = selectedSection === 'all' || student.section?.id === parseInt(selectedSection);
    const matchesCohort = selectedCohort === 'all' || student.cohort === selectedCohort;
    return matchesSearch && matchesSection && matchesCohort;
  });

  if (loading) {
    return <div className="spinner" />;
  }

  const downloadFilteredRoster = async () => {
    try {
      // Build params based on current filters
      const params = {};

      if (selectedSection !== 'all') {
        params.section_id = selectedSection;
      }
      if (selectedCohort !== 'all') {
        params.cohort = selectedCohort;
      }
      if (searchTerm.trim()) {
        params.search = searchTerm.trim();
      }
      if (constraintFilter !== 'all') {
        params.constraint_filter = constraintFilter;
      }
      if (constraintType !== 'all') {
        params.constraint_type = constraintType;
      }

      const response = await api.get('/admin/students/export_by_section', {
        params,
        responseType: 'blob'
      });
      const blob = new Blob([response.data], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `roster_filtered_${new Date().toISOString().split('T')[0]}.csv`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (err) {
      let errorMessage = 'Failed to download roster';
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

  return (
    <div>
      <div className="card" style={{ marginBottom: '1.5rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
          <h3 style={{ color: 'var(--primary)', margin: 0 }}>
            Roster Management
          </h3>
          <button
            onClick={downloadFilteredRoster}
            className="btn btn-primary"
            style={{ fontSize: '0.875rem' }}
          >
            📥 Download Filtered CSV ({filteredStudents.length} students)
          </button>
        </div>

        <div style={{ display: 'flex', gap: '1rem', marginBottom: '1rem', alignItems: 'center', flexWrap: 'wrap' }}>
          <div style={{ flex: '1 1 300px' }}>
            <input
              type="text"
              className="form-input"
              placeholder="Search by name or email..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{ width: '100%' }}
            />
          </div>
          <div style={{ minWidth: '180px' }}>
            <select
              className="form-input"
              value={selectedSection}
              onChange={(e) => setSelectedSection(e.target.value)}
              style={{ width: '100%' }}
            >
              <option value="all">All Sections</option>
              {sections.map(section => (
                <option key={section.id} value={section.id}>
                  {section.name}
                </option>
              ))}
            </select>
          </div>
          <div style={{ minWidth: '140px' }}>
            <select
              className="form-input"
              value={selectedCohort}
              onChange={(e) => setSelectedCohort(e.target.value)}
              style={{ width: '100%' }}
            >
              <option value="all">All Groups</option>
              <option value="odd">Group A</option>
              <option value="even">Group B</option>
            </select>
          </div>
          <div style={{ minWidth: '180px' }}>
            <select
              className="form-input"
              value={constraintFilter}
              onChange={(e) => {
                setConstraintFilter(e.target.value);
                if (e.target.value !== 'with_constraints') {
                  setConstraintType('all');
                }
              }}
              style={{ width: '100%' }}
            >
              <option value="all">All Students</option>
              <option value="with_constraints">With Constraints</option>
              <option value="without_constraints">Without Constraints</option>
            </select>
          </div>
          {constraintFilter === 'with_constraints' && (
            <div style={{ minWidth: '180px' }}>
              <select
                className="form-input"
                value={constraintType}
                onChange={(e) => setConstraintType(e.target.value)}
                style={{ width: '100%' }}
              >
                <option value="all">All Constraint Types</option>
                {availableConstraintTypes.map(type => (
                  <option key={type.value} value={type.value}>
                    {type.label} ({type.count})
                  </option>
                ))}
              </select>
            </div>
          )}
        </div>

        <div style={{ color: 'var(--text-light)', marginBottom: '1rem' }}>
          Showing {filteredStudents.length} of {students.length} students
        </div>
      </div>

      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Section</th>
              <th>Constraints</th>
              <th>Slack</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filteredStudents.map((student) => (
              <tr key={student.id} style={{ opacity: student.is_active ? 1 : 0.5 }}>
                <td>
                  <div>
                    <div>{student.full_name}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-light)', marginTop: '0.15rem' }}>
                      {student.email}
                    </div>
                  </div>
                </td>
                <td>
                  {student.section ? (
                    <span
                      className="badge badge-primary"
                      title={student.section_override ? 'Section manually overridden - will not change on roster uploads' : ''}
                    >
                      {student.section_override ? '🔒 ' : ''}{student.section.name.replace(/^Section\s+/i, '')}
                    </span>
                  ) : (
                    <span style={{ color: 'var(--text-light)' }}>No section</span>
                  )}
                </td>
                <td>
                  {student.constraints_count > 0 ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
                      <span className="badge badge-warning" style={{ fontSize: '0.7rem' }}>
                        {student.constraints_count} constraint{student.constraints_count !== 1 ? 's' : ''}
                      </span>
                      {student.constraint_types && student.constraint_types.length > 0 && (
                        <div style={{ fontSize: '0.65rem', color: 'var(--text-light)', display: 'flex', flexWrap: 'wrap', gap: '0.15rem' }}>
                          {student.constraint_types.map(type => (
                            <span key={type} style={{
                              backgroundColor: 'var(--bg-light)',
                              padding: '0.1rem 0.3rem',
                              borderRadius: '3px',
                              whiteSpace: 'nowrap'
                            }}>
                              {type.replace(/_/g, ' ')}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  ) : (
                    <span style={{ color: 'var(--text-light)', fontSize: '0.75rem' }}>None</span>
                  )}
                </td>
                <td>
                  {student.slack_matched ? (
                    <span className="badge badge-success">
                      ✓ {student.slack_username ? `@${student.slack_username}` : 'Matched'}
                    </span>
                  ) : (
                    <span className="badge badge-error">Not matched</span>
                  )}
                </td>
                <td>
                  <span className={`badge ${student.is_active ? 'badge-success' : 'badge-error'}`}>
                    {student.is_active ? 'Active' : 'Inactive'}
                  </span>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                    <button
                      onClick={() => openConstraintModal(student)}
                      className="btn btn-primary"
                      style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                    >
                      Constraints
                    </button>
                    <button
                      onClick={() => openHistoryModal(student)}
                      className="btn btn-primary"
                      style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                    >
                      History
                    </button>
                    <button
                      onClick={() => openTransferModal(student)}
                      className="btn btn-primary"
                      style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                      disabled={!student.cohort}
                      title={student.cohort ? `Transfer from cohort ${student.cohort}` : 'No cohort assigned'}
                    >
                      ↔️ Transfer Cohort
                    </button>
                    <button
                      onClick={() => openChangeSectionModal(student)}
                      className="btn btn-primary"
                      style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                      title={student.section_override ? 'Section manually overridden' : 'Change section'}
                    >
                      {student.section_override ? '🔒 ' : ''}🔄 Change Section
                    </button>
                    <button
                      onClick={() => openSwapCohortModal(student)}
                      className="px-3 py-1.5 text-xs font-medium border border-orange-500 text-orange-600 rounded hover:bg-orange-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      disabled={!student.cohort}
                      title="Swap to opposite cohort and place at end of schedule"
                    >
                      🔁 Swap to {student.cohort === 'odd' ? 'Group B' : 'Group A'}
                    </button>
                    <button
                      onClick={() => openNotifyModal(student)}
                      className="px-3 py-1.5 text-xs font-medium border border-blue-500 text-blue-600 rounded hover:bg-blue-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      disabled={!student.slack_matched}
                    >
                      💬 Notify Slack
                    </button>
                    <button
                      onClick={() => toggleStudentStatus(student.id, student.is_active)}
                      className={`btn ${student.is_active ? 'btn-outline' : 'btn-primary'}`}
                      style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                    >
                      {student.is_active ? 'Deactivate' : 'Activate'}
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showConstraintModal && selectedStudent && (
        <ConstraintModal
          student={selectedStudent}
          onClose={() => {
            setShowConstraintModal(false);
            setSelectedStudent(null);
            loadData();
          }}
        />
      )}

      {showHistoryModal && selectedStudent && (
        <StudentHistoryModal
          student={selectedStudent}
          onClose={() => {
            setShowHistoryModal(false);
            setSelectedStudent(null);
            loadData();
          }}
        />
      )}

      {/* Notify Slack Modal */}
      {showNotifyModal && selectedStudent && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-xl p-6 w-full max-w-md">
            <h3 className="text-xl font-bold text-gray-800 mb-4">
              Send Slack Notification
            </h3>
            <p className="text-gray-600 mb-4">
              Sending notification to: <span className="font-semibold">{selectedStudent.full_name}</span>
            </p>

            <div className="mb-6">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Select Oral Exam Number
              </label>
              <select
                value={selectedExamNumber}
                onChange={(e) => setSelectedExamNumber(parseInt(e.target.value))}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              >
                {[1, 2, 3, 4, 5].map(num => (
                  <option key={num} value={num}>Oral Exam #{num}</option>
                ))}
              </select>
            </div>

            <div className="flex gap-3">
              <button
                onClick={notifySlack}
                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-4 rounded-lg transition-colors"
              >
                Send Notification
              </button>
              <button
                onClick={() => {
                  setShowNotifyModal(false);
                  setSelectedStudent(null);
                }}
                className="flex-1 bg-gray-200 hover:bg-gray-300 text-gray-700 font-semibold py-3 px-4 rounded-lg transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Transfer Cohort Modal */}
      {showTransferModal && selectedStudent && (
        <div
          onClick={() => {
            setShowTransferModal(false);
            setSelectedStudent(null);
          }}
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
            style={{ maxWidth: '500px', width: '90%' }}
          >
            <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
              Transfer Cohort
            </h3>
            <p style={{ marginBottom: '1rem' }}>
              <strong>{selectedStudent.full_name}</strong>
            </p>
            <p style={{ marginBottom: '1rem', color: 'var(--text-light)', fontSize: '0.875rem' }}>
              Current cohort: <span className="badge badge-primary">{selectedStudent.cohort}</span>
            </p>

            <div style={{ marginBottom: '1rem', padding: '1rem', backgroundColor: 'rgba(255, 152, 0, 0.1)', borderRadius: '8px' }}>
              <p style={{ fontSize: '0.875rem', margin: 0 }}>
                ⚠️ This will clear all exam schedules from the selected exam number onwards. Locked schedules cannot be transferred.
              </p>
            </div>

            <div style={{ marginBottom: '1rem' }}>
              <label className="form-label">Transfer to cohort</label>
              <select
                className="form-input"
                value={transferToCohort}
                onChange={(e) => setTransferToCohort(e.target.value)}
              >
                <option value="odd">Group A</option>
                <option value="even">Group B</option>
              </select>
            </div>

            <div style={{ marginBottom: '1.5rem' }}>
              <label className="form-label">Starting from Oral Exam #</label>
              <select
                className="form-input"
                value={transferFromExam}
                onChange={(e) => setTransferFromExam(parseInt(e.target.value))}
              >
                {[1, 2, 3, 4, 5].map(num => (
                  <option key={num} value={num}>Oral Exam #{num}</option>
                ))}
              </select>
              <p style={{ fontSize: '0.75rem', color: 'var(--text-light)', marginTop: '0.5rem' }}>
                All exam slots from this exam onwards will be cleared and unscheduled.
              </p>
            </div>

            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button
                onClick={transferCohort}
                className="btn btn-primary"
              >
                ✅ Confirm Transfer
              </button>
              <button
                onClick={() => {
                  setShowTransferModal(false);
                  setSelectedStudent(null);
                }}
                className="btn btn-outline"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Change Section Modal */}
      {showChangeSectionModal && selectedStudent && (
        <div
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
          onClick={() => {
            setShowChangeSectionModal(false);
            setSelectedStudent(null);
          }}
        >
          <div
            className="card"
            style={{ minWidth: '400px', maxWidth: '500px' }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
              Change Section
            </h3>
            <p style={{ marginBottom: '1rem' }}>
              Change section for <strong>{selectedStudent.full_name}</strong>
            </p>

            {selectedStudent.section_override && (
              <div style={{
                padding: '0.75rem',
                backgroundColor: '#fef3c7',
                border: '1px solid #f59e0b',
                borderRadius: '0.5rem',
                marginBottom: '1rem',
                fontSize: '0.875rem'
              }}>
                🔒 This student's section is already manually overridden
              </div>
            )}

            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
                Current Section: {selectedStudent.section?.name || 'None'}
              </label>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
                New Section
              </label>
              <select
                className="form-input"
                value={changeSectionTo}
                onChange={(e) => setChangeSectionTo(e.target.value)}
                style={{ width: '100%' }}
              >
                <option value="">Select Section</option>
                {sections
                  .filter(s => s.id !== selectedStudent.section?.id)
                  .map(section => (
                    <option key={section.id} value={section.id}>
                      {section.name} - {section.ta ? section.ta.full_name : 'No TA'}
                    </option>
                  ))}
              </select>
            </div>

            <div style={{
              padding: '0.75rem',
              backgroundColor: '#fef2f2',
              border: '1px solid #ef4444',
              borderRadius: '0.5rem',
              marginBottom: '1rem',
              fontSize: '0.875rem'
            }}>
              ⚠️ <strong>Warning:</strong> All exam slots for this student will be cleared. The section override will persist on future roster uploads.
            </div>

            <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end' }}>
              <button
                onClick={changeSection}
                className="btn btn-primary"
                disabled={!changeSectionTo}
              >
                ✅ Change Section
              </button>
              <button
                onClick={() => {
                  setShowChangeSectionModal(false);
                  setSelectedStudent(null);
                }}
                className="btn btn-outline"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Swap to Opposite Cohort Modal */}
      {showSwapCohortModal && selectedStudent && (
        <div
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
          onClick={() => {
            setShowSwapCohortModal(false);
            setSelectedStudent(null);
          }}
        >
          <div
            className="card"
            style={{ minWidth: '400px', maxWidth: '500px' }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
              Swap to Opposite Cohort
            </h3>
            <p style={{ marginBottom: '1rem' }}>
              Swap <strong>{selectedStudent.full_name}</strong> from <strong>{selectedStudent.cohort === 'odd' ? 'Group A' : 'Group B'}</strong> to <strong>{selectedStudent.cohort === 'odd' ? 'Group B' : 'Group A'}</strong>
            </p>

            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
                Starting from which exam?
              </label>
              <select
                className="form-input"
                value={swapFromExam}
                onChange={(e) => setSwapFromExam(parseInt(e.target.value))}
                style={{ width: '100%' }}
              >
                <option value={1}>Exam 1 (and all future exams)</option>
                <option value={2}>Exam 2 (and all future exams)</option>
                <option value={3}>Exam 3 (and all future exams)</option>
                <option value={4}>Exam 4 (and all future exams)</option>
                <option value={5}>Exam 5 only</option>
              </select>
            </div>

            <div style={{
              padding: '0.75rem',
              backgroundColor: '#fff7ed',
              border: '1px solid #f97316',
              borderRadius: '0.5rem',
              marginBottom: '1rem',
              fontSize: '0.875rem'
            }}>
              <strong>⚠️ This will:</strong>
              <ul style={{ marginTop: '0.5rem', marginLeft: '1.25rem' }}>
                <li>Unlock any locked exams from Exam {swapFromExam} onwards</li>
                <li>Delete their old time slots</li>
                <li>Place them at the END of the {selectedStudent.cohort === 'odd' ? 'Group B' : 'Group A'} schedule</li>
                <li>NOT affect any other students</li>
              </ul>
            </div>

            <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end' }}>
              <button
                onClick={swapToOppositeCohort}
                className="btn btn-primary"
              >
                🔁 Swap Cohort
              </button>
              <button
                onClick={() => {
                  setShowSwapCohortModal(false);
                  setSelectedStudent(null);
                }}
                className="btn btn-outline"
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

function ConstraintModal({ student, onClose }) {
  const [constraints, setConstraints] = useState([]);
  const [loading, setLoading] = useState(true);
  const [newConstraint, setNewConstraint] = useState({
    constraint_type: 'time_before',
    value: ''
  });

  useEffect(() => {
    loadConstraints();
  }, []);

  const loadConstraints = async () => {
    try {
      const response = await api.get(`/admin/constraints?student_id=${student.id}`);
      setConstraints(response.data.constraints);
    } catch (err) {
      console.error('Failed to load constraints', err);
    } finally {
      setLoading(false);
    }
  };

  const addConstraint = async () => {
    if (!newConstraint.value) {
      alert('Please enter a value');
      return;
    }

    try {
      await api.post('/admin/constraints', {
        student_id: student.id,
        constraint: {
          constraint_type: newConstraint.constraint_type,
          constraint_value: newConstraint.value
        }
      });
      setNewConstraint({ constraint_type: 'time_before', value: '' });
      loadConstraints();
    } catch (err) {
      alert('Failed to add constraint');
    }
  };

  const deleteConstraint = async (constraintId) => {
    if (!confirm('Delete this constraint?')) return;

    try {
      await api.delete(`/admin/constraints/${constraintId}`);
      loadConstraints();
    } catch (err) {
      alert('Failed to delete constraint');
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
      }}>
      <div
        className="card"
        onClick={(e) => e.stopPropagation()}
        style={{ maxWidth: '600px', width: '90%', maxHeight: '80vh', overflow: 'auto' }}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Scheduling Constraints
        </h3>
        <p style={{ marginBottom: '1rem' }}>
          <strong>{student.full_name}</strong> ({student.email})
        </p>

        <div style={{ marginBottom: '1.5rem' }}>
          <h4 style={{ marginBottom: '0.5rem' }}>Add New Constraint</h4>
          <div style={{ marginBottom: '0.5rem' }}>
            <label className="form-label">Constraint Type</label>
            <select
              className="form-input"
              value={newConstraint.constraint_type}
              onChange={(e) => setNewConstraint({ ...newConstraint, constraint_type: e.target.value, value: '' })}
            >
              <option value="time_before">No exams before (time)</option>
              <option value="time_after">No exams after (time)</option>
              <option value="week_preference">Prefer specific week (odd/even)</option>
              <option value="specific_date">Must be on specific date</option>
              <option value="exclude_date">Exclude specific date</option>
            </select>
          </div>

          <div style={{ marginBottom: '0.5rem' }}>
            <label className="form-label">Value</label>
            {newConstraint.constraint_type === 'week_preference' ? (
              <select
                className="form-input"
                value={newConstraint.value}
                onChange={(e) => setNewConstraint({ ...newConstraint, value: e.target.value })}
                required
              >
                <option value="">Select week preference...</option>
                <option value="odd">Odd weeks</option>
                <option value="even">Even weeks</option>
              </select>
            ) : (newConstraint.constraint_type === 'time_before' || newConstraint.constraint_type === 'time_after') ? (
              <input
                type="time"
                className="form-input"
                value={newConstraint.value}
                onChange={(e) => setNewConstraint({ ...newConstraint, value: e.target.value })}
                required
              />
            ) : (
              <input
                type="date"
                className="form-input"
                value={newConstraint.value}
                onChange={(e) => setNewConstraint({ ...newConstraint, value: e.target.value })}
                required
              />
            )}
          </div>

          <button onClick={addConstraint} className="btn btn-primary">
            Add Constraint
          </button>
        </div>

        {loading ? (
          <div className="spinner" />
        ) : (
          <div>
            <h4 style={{ marginBottom: '0.5rem' }}>Current Constraints</h4>
            {constraints.length === 0 ? (
              <p style={{ color: 'var(--text-light)' }}>No constraints set</p>
            ) : (
              <table className="table">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Value</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {constraints.map(constraint => (
                    <tr key={constraint.id}>
                      <td>{constraint.constraint_type.replace(/_/g, ' ')}</td>
                      <td><code>{constraint.constraint_value}</code></td>
                      <td>
                        <button
                          onClick={() => deleteConstraint(constraint.id)}
                          className="btn btn-outline"
                          style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                        >
                          Delete
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
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

function HistoryModal({ student, onClose }) {
  const [history, setHistory] = useState({});
  const [loading, setLoading] = useState(true);
  const [selectedExam, setSelectedExam] = useState(1);

  useEffect(() => {
    loadHistory();
  }, []);

  const loadHistory = async () => {
    try {
      const response = await api.get(`/admin/students/${student.id}/schedule_history`);
      setHistory(response.data.history);
    } catch (err) {
      console.error('Failed to load history', err);
    } finally {
      setLoading(false);
    }
  };

  const revertToHistory = async (historyId) => {
    if (!confirm('Revert to this schedule version?')) return;

    try {
      await api.post(`/admin/students/${student.id}/revert_schedule`, {
        history_id: historyId
      });
      alert('Schedule reverted successfully');
      loadHistory();
    } catch (err) {
      alert('Failed to revert schedule');
    }
  };

  const examNumbers = Object.keys(history).sort((a, b) => parseInt(a) - parseInt(b));

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
      }}>
      <div
        className="card"
        onClick={(e) => e.stopPropagation()}
        style={{ maxWidth: '800px', width: '90%', maxHeight: '80vh', overflow: 'auto' }}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Schedule History
        </h3>
        <p style={{ marginBottom: '1rem' }}>
          <strong>{student.full_name}</strong> ({student.email})
        </p>

        {loading ? (
          <div className="spinner" />
        ) : examNumbers.length === 0 ? (
          <p style={{ color: 'var(--text-light)' }}>No schedule history available</p>
        ) : (
          <>
            <div style={{ marginBottom: '1rem', display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
              {examNumbers.map((examNum) => (
                <button
                  key={examNum}
                  onClick={() => setSelectedExam(parseInt(examNum))}
                  className={`btn ${selectedExam === parseInt(examNum) ? 'btn-primary' : 'btn-outline'}`}
                  style={{ fontSize: '0.875rem', padding: '0.5rem 1rem' }}
                >
                  Oral Exam {examNum}
                </button>
              ))}
            </div>

            {history[selectedExam] && history[selectedExam].length > 0 ? (
              <div>
                <h4 style={{ marginBottom: '0.5rem' }}>
                  Oral Exam {selectedExam} - Schedule Changes
                </h4>
                <table className="table">
                  <thead>
                    <tr>
                      <th>Date</th>
                      <th>Week</th>
                      <th>Time</th>
                      <th>Status</th>
                      <th>Changed</th>
                      <th>Reason</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {history[selectedExam].map((item, idx) => (
                      <tr key={item.id} style={{ opacity: idx === 0 ? 1 : 0.7 }}>
                        <td>{item.date || 'N/A'}</td>
                        <td>Week {item.week_number}</td>
                        <td>
                          {item.start_time && item.end_time ? (
                            `${item.start_time} - ${item.end_time}`
                          ) : (
                            'N/A'
                          )}
                        </td>
                        <td>
                          <span className={`badge ${item.is_scheduled ? 'badge-success' : 'badge-warning'}`}>
                            {item.is_scheduled ? 'Scheduled' : 'Unscheduled'}
                          </span>
                          {idx === 0 && (
                            <span className="badge badge-primary" style={{ marginLeft: '0.5rem' }}>
                              Current
                            </span>
                          )}
                        </td>
                        <td style={{ fontSize: '0.75rem' }}>
                          {new Date(item.changed_at).toLocaleString()}
                          {item.changed_by && (
                            <div style={{ color: 'var(--text-light)' }}>by {item.changed_by}</div>
                          )}
                        </td>
                        <td style={{ fontSize: '0.75rem', color: 'var(--text-light)' }}>
                          {item.reason || 'N/A'}
                        </td>
                        <td>
                          {idx !== 0 && (
                            <button
                              onClick={() => revertToHistory(item.id)}
                              className="btn btn-outline"
                              style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                            >
                              Revert
                            </button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p style={{ color: 'var(--text-light)' }}>
                No history for Oral Exam {selectedExam}
              </p>
            )}
          </>
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
