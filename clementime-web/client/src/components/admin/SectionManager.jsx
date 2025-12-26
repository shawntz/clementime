import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function SectionManager() {
  const [sections, setSections] = useState([]);
  const [tas, setTas] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [sectionsRes, tasRes] = await Promise.all([
        api.get('/admin/sections'),
        api.get('/admin/users?role=ta'),
      ]);
      // Filter out section 01 (lecture sections)
      const filteredSections = sectionsRes.data.sections.filter((section) => {
        const parts = section.code.split('-');
        if (parts.length >= 4) {
          const sectionNum = parseInt(parts[3]);
          return sectionNum !== 1;
        }
        return true;
      });
      setSections(filteredSections);
      // Filter out inactive TAs
      setTas(tasRes.data.users.filter((ta) => ta.is_active));
    } catch (err) {
      console.error('Failed to load data', err);
    } finally {
      setLoading(false);
    }
  };

  const assignTA = async (sectionId, taId) => {
    try {
      await api.put(`/admin/sections/${sectionId}/assign_ta`, { ta_id: taId });
      loadData();
    } catch (err) {
      alert('Failed to assign TA');
    }
  };

  if (loading) {
    return <div className="spinner" />;
  }

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
    <div className="card">
      <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>Section Management</h3>

      <table className="table">
        <thead>
          <tr>
            <th>Section Code</th>
            <th>Name</th>
            <th>Location</th>
            <th>Students</th>
            <th>Assigned TA</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {sections.map((section) => {
            const codes = getCrossListedCodes(section.code);
            return (
              <tr key={section.id}>
                <td>
                  <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                    {codes.map((code, idx) => (
                      <span key={idx} className="badge badge-primary">
                        {code}
                      </span>
                    ))}
                  </div>
                </td>
                <td>{section.name}</td>
                <td>{section.location || 'Not set'}</td>
                <td>{section.students_count}</td>
                <td>{section.ta ? section.ta.full_name : 'Unassigned'}</td>
                <td>
                  <select
                    className="form-input"
                    value={section.ta?.id || ''}
                    onChange={(e) => assignTA(section.id, e.target.value)}
                    style={{ minWidth: '200px' }}
                  >
                    <option value="">Select TA...</option>
                    {tas.map((ta) => (
                      <option key={ta.id} value={ta.id}>
                        {ta.full_name} ({ta.email})
                      </option>
                    ))}
                  </select>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
