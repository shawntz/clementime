import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function TAManager() {
  const [tas, setTas] = useState([]);
  const [sections, setSections] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [editingTA, setEditingTA] = useState(null);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [tasRes, sectionsRes] = await Promise.all([
        api.get('/admin/users?role=ta'),
        api.get('/admin/sections')
      ]);
      setTas(tasRes.data.users);
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

  const deleteTA = async (taId) => {
    if (!confirm('Delete this TA? Their sections will be unassigned.')) return;

    try {
      await api.delete(`/admin/users/${taId}`);
      loadData();
    } catch (err) {
      alert('Failed to delete TA');
    }
  };

  const toggleTAStatus = async (taId, currentStatus) => {
    try {
      await api.put(`/admin/users/${taId}`, {
        is_active: !currentStatus
      });
      loadData();
    } catch (err) {
      alert('Failed to update TA status');
    }
  };

  if (loading) {
    return <div className="spinner" />;
  }

  return (
    <div>
      <div className="card" style={{ marginBottom: '1.5rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
          <h3 style={{ color: 'var(--primary)', margin: 0 }}>
            TA Management
          </h3>
          <button
            onClick={() => setShowCreateModal(true)}
            className="btn btn-primary"
          >
            + Create TA
          </button>
        </div>

        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Username</th>
              <th>Email</th>
              <th>Location</th>
              <th>Slack ID</th>
              <th>Status</th>
              <th>Assigned Sections</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {tas.map((ta) => {
              const assignedSections = sections.filter(s => s.ta?.id === ta.id);
              return (
                <tr key={ta.id} style={{ opacity: ta.is_active ? 1 : 0.5 }}>
                  <td>{ta.full_name}</td>
                  <td><code>{ta.username}</code></td>
                  <td>{ta.email}</td>
                  <td>{ta.location || <span style={{ color: 'var(--text-light)' }}>Not set</span>}</td>
                  <td>{ta.slack_id ? <code>{ta.slack_id}</code> : <span style={{ color: 'var(--text-light)' }}>Not set</span>}</td>
                  <td>
                    <span className={`badge ${ta.is_active ? 'badge-success' : 'badge-error'}`}>
                      {ta.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td>
                    {assignedSections.length > 0 ? (
                      <div style={{ display: 'flex', gap: '0.25rem', flexWrap: 'wrap' }}>
                        {assignedSections.map(section => (
                          <span key={section.id} className="badge badge-primary">
                            {section.name}
                          </span>
                        ))}
                      </div>
                    ) : (
                      <span style={{ color: 'var(--text-light)' }}>None</span>
                    )}
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                      <button
                        onClick={() => setEditingTA(ta)}
                        className="btn btn-primary"
                        style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => toggleTAStatus(ta.id, ta.is_active)}
                        className={`btn ${ta.is_active ? 'btn-outline' : 'btn-primary'}`}
                        style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                      >
                        {ta.is_active ? 'Deactivate' : 'Activate'}
                      </button>
                      <button
                        onClick={() => deleteTA(ta.id)}
                        className="btn btn-outline"
                        style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem', color: 'var(--error)' }}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
            {tas.length === 0 && (
              <tr>
                <td colSpan="8" style={{ textAlign: 'center', color: 'var(--text-light)' }}>
                  No TAs created yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {showCreateModal && (
        <CreateTAModal
          onClose={() => {
            setShowCreateModal(false);
            loadData();
          }}
        />
      )}

      {editingTA && (
        <EditTAModal
          ta={editingTA}
          onClose={() => {
            setEditingTA(null);
            loadData();
          }}
        />
      )}
    </div>
  );
}

function CreateTAModal({ onClose }) {
  // Generate a random temporary password
  const generatePassword = () => {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    let password = '';
    for (let i = 0; i < 12; i++) {
      password += chars[Math.floor(Math.random() * chars.length)];
    }
    return password;
  };

  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: generatePassword(),
    first_name: '',
    last_name: '',
    location: '',
    slack_id: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Auto-generate username from first.last when names change
  useEffect(() => {
    if (formData.first_name && formData.last_name) {
      const baseUsername = `${formData.first_name.toLowerCase()}.${formData.last_name.toLowerCase()}`;
      setFormData(prev => ({ ...prev, username: baseUsername }));
    }
  }, [formData.first_name, formData.last_name]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      // Check if username exists and add number if needed
      let username = formData.username;
      let attempt = 1;
      let usernameExists = true;

      while (usernameExists && attempt <= 10) {
        try {
          const checkResponse = await api.get(`/admin/users?username=${username}`);
          if (checkResponse.data.users && checkResponse.data.users.length > 0) {
            username = `${formData.username}${attempt}`;
            attempt++;
          } else {
            usernameExists = false;
          }
        } catch (err) {
          usernameExists = false;
        }
      }

      await api.post('/admin/users', {
        user: {
          username,
          email: formData.email,
          password: formData.password,
          password_confirmation: formData.password,
          first_name: formData.first_name,
          last_name: formData.last_name,
          location: formData.location,
          slack_id: formData.slack_id,
          role: 'ta',
          is_active: true
        }
      });
      onClose();
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Failed to create TA');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
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
      <div className="card" style={{ maxWidth: '500px', width: '90%' }}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Create New TA
        </h3>

        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">First Name</label>
            <input
              type="text"
              className="form-input"
              value={formData.first_name}
              onChange={(e) => setFormData({ ...formData, first_name: e.target.value })}
              required
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Last Name</label>
            <input
              type="text"
              className="form-input"
              value={formData.last_name}
              onChange={(e) => setFormData({ ...formData, last_name: e.target.value })}
              required
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Username (auto-generated)</label>
            <input
              type="text"
              className="form-input"
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Email</label>
            <input
              type="email"
              className="form-input"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              required
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Office/Room Location</label>
            <input
              type="text"
              className="form-input"
              placeholder="e.g., 420-412"
              value={formData.location}
              onChange={(e) => setFormData({ ...formData, location: e.target.value })}
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Slack ID</label>
            <input
              type="text"
              className="form-input"
              placeholder="e.g., U01234ABCDE"
              value={formData.slack_id}
              onChange={(e) => setFormData({ ...formData, slack_id: e.target.value })}
            />
            <div style={{ fontSize: '0.875rem', color: 'var(--text-light)', marginTop: '0.25rem' }}>
              Used for Slack notifications and channel assignments
            </div>
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Temporary Password</label>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <input
                type="text"
                className="form-input"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                required
                style={{ flex: 1 }}
              />
              <button
                type="button"
                onClick={() => setFormData({ ...formData, password: generatePassword() })}
                className="btn btn-outline"
              >
                🔄 Generate
              </button>
            </div>
            <div style={{ fontSize: '0.875rem', color: 'var(--text-light)', marginTop: '0.25rem' }}>
              Auto-generated. TA can change after first login.
            </div>
          </div>

          {error && (
            <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
              {error}
            </div>
          )}

          <div style={{ display: 'flex', gap: '1rem' }}>
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Creating...' : 'Create TA'}
            </button>
            <button type="button" onClick={onClose} className="btn btn-outline">
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function EditTAModal({ ta, onClose }) {
  const [formData, setFormData] = useState({
    first_name: ta.first_name,
    last_name: ta.last_name,
    email: ta.email,
    location: ta.location || '',
    slack_id: ta.slack_id || ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      await api.put(`/admin/users/${ta.id}`, {
        user: {
          first_name: formData.first_name,
          last_name: formData.last_name,
          email: formData.email,
          location: formData.location,
          slack_id: formData.slack_id
        }
      });
      onClose();
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Failed to update TA');
    } finally {
      setLoading(false);
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
        style={{ maxWidth: '500px', width: '90%' }}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Edit TA: {ta.full_name}
        </h3>

        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">First Name</label>
            <input
              type="text"
              className="form-input"
              value={formData.first_name}
              onChange={(e) => setFormData({ ...formData, first_name: e.target.value })}
              required
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Last Name</label>
            <input
              type="text"
              className="form-input"
              value={formData.last_name}
              onChange={(e) => setFormData({ ...formData, last_name: e.target.value })}
              required
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Email</label>
            <input
              type="email"
              className="form-input"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              required
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Office/Room Location</label>
            <input
              type="text"
              className="form-input"
              placeholder="e.g., 420-412"
              value={formData.location}
              onChange={(e) => setFormData({ ...formData, location: e.target.value })}
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Slack ID</label>
            <input
              type="text"
              className="form-input"
              placeholder="e.g., U01234ABCDE"
              value={formData.slack_id}
              onChange={(e) => setFormData({ ...formData, slack_id: e.target.value })}
            />
            <div style={{ fontSize: '0.875rem', color: 'var(--text-light)', marginTop: '0.25rem' }}>
              Used for Slack notifications and channel assignments
            </div>
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Username (cannot be changed)</label>
            <input
              type="text"
              className="form-input"
              value={ta.username}
              readOnly
              style={{ backgroundColor: 'var(--background)', cursor: 'not-allowed' }}
            />
          </div>

          {error && (
            <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
              {error}
            </div>
          )}

          <div style={{ display: 'flex', gap: '1rem' }}>
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Saving...' : 'Save Changes'}
            </button>
            <button type="button" onClick={onClose} className="btn btn-outline">
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
