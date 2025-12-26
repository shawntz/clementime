import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function RosterView() {
  const [students, setStudents] = useState([]);
  const [sections, setSections] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedSection, setSelectedSection] = useState('all');
  const [selectedCohort, setSelectedCohort] = useState('all');
  const [constraintFilter, setConstraintFilter] = useState('all');
  const [constraintType, setConstraintType] = useState('all');
  const [availableConstraintTypes, setAvailableConstraintTypes] = useState([]);

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
        api.get('/ta/students', { params }),
        api.get('/ta/sections'),
      ]);

      setStudents(studentsRes.data.students);
      setAvailableConstraintTypes(studentsRes.data.constraint_types || []);
      setSections(
        sectionsRes.data.sections.filter((s) => {
          const parts = s.code.split('-');
          return parts.length >= 4 && parseInt(parts[3]) !== 1;
        })
      );
    } catch (err) {
      console.error('Failed to load data', err);
    } finally {
      setLoading(false);
    }
  };

  const filteredStudents = students.filter((student) => {
    const matchesSearch =
      student.full_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      student.email.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesSection =
      selectedSection === 'all' || student.section?.id === parseInt(selectedSection);
    const matchesCohort = selectedCohort === 'all' || student.cohort === selectedCohort;
    return matchesSearch && matchesSection && matchesCohort;
  });

  const downloadRosterBySection = async () => {
    try {
      const response = await api.get('/ta/students/export_by_section', {
        responseType: 'blob',
      });
      const blob = new Blob([response.data], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `roster_by_section_${new Date().toISOString().split('T')[0]}.csv`;
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

  if (loading) {
    return <div className="spinner" />;
  }

  return (
    <div>
      <div className="card" style={{ marginBottom: '1.5rem' }}>
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'flex-start',
            marginBottom: '0.5rem',
          }}
        >
          <div>
            <h3 style={{ color: 'var(--primary)', margin: 0, marginBottom: '0.5rem' }}>
              Student Roster (Read-Only)
            </h3>
            <p style={{ color: 'var(--text-light)', margin: 0, fontSize: '0.875rem' }}>
              View student roster, sections, and scheduling constraints
            </p>
          </div>
          <button
            onClick={downloadRosterBySection}
            className="btn btn-primary"
            style={{ fontSize: '0.875rem', whiteSpace: 'nowrap' }}
          >
            📥 Download CSV by Section
          </button>
        </div>

        <div
          style={{
            display: 'flex',
            gap: '1rem',
            marginBottom: '1rem',
            alignItems: 'center',
            flexWrap: 'wrap',
          }}
        >
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
              {sections.map((section) => (
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
                {availableConstraintTypes.map((type) => (
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
              <th>Email</th>
              <th>Section</th>
              <th>Week Group</th>
              <th>Constraints</th>
              <th>Slack</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {filteredStudents.map((student) => (
              <tr key={student.id} style={{ opacity: student.is_active ? 1 : 0.5 }}>
                <td>{student.full_name}</td>
                <td style={{ fontSize: '0.875rem' }}>{student.email}</td>
                <td>
                  {student.section ? (
                    <span className="badge badge-primary">{student.section.name}</span>
                  ) : (
                    <span style={{ color: 'var(--text-light)' }}>No section</span>
                  )}
                </td>
                <td>
                  <span
                    className={`badge ${student.cohort === 'odd' ? 'badge-info' : 'badge-secondary'}`}
                  >
                    {student.cohort === 'odd' ? 'Group A' : 'Group B'}
                  </span>
                </td>
                <td>
                  {student.constraints_count > 0 ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
                      <span className="badge badge-warning" style={{ fontSize: '0.7rem' }}>
                        {student.constraints_count} constraint
                        {student.constraints_count !== 1 ? 's' : ''}
                      </span>
                      {student.constraint_types && student.constraint_types.length > 0 && (
                        <div
                          style={{
                            fontSize: '0.65rem',
                            color: 'var(--text-light)',
                            display: 'flex',
                            flexWrap: 'wrap',
                            gap: '0.15rem',
                          }}
                        >
                          {student.constraint_types.map((type, idx) => (
                            <span
                              key={idx}
                              style={{
                                backgroundColor: 'var(--warning-light)',
                                padding: '0.1rem 0.3rem',
                                borderRadius: '0.2rem',
                                whiteSpace: 'nowrap',
                              }}
                            >
                              {type}
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
                    <span className="badge badge-success" style={{ fontSize: '0.7rem' }}>
                      ✓ Matched
                    </span>
                  ) : (
                    <span
                      className="badge"
                      style={{ backgroundColor: '#6c757d', fontSize: '0.7rem' }}
                    >
                      Not matched
                    </span>
                  )}
                </td>
                <td>
                  {student.is_active ? (
                    <span className="badge badge-success" style={{ fontSize: '0.7rem' }}>
                      Active
                    </span>
                  ) : (
                    <span
                      className="badge"
                      style={{ backgroundColor: '#6c757d', fontSize: '0.7rem' }}
                    >
                      Inactive
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
