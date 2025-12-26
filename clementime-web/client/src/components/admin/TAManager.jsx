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
      // Filter out inactive TAs
      setTas(tasRes.data.users.filter(ta => ta.is_active));
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

  const sendWelcomeEmail = async (taId, taName) => {
    if (!confirm(`Send welcome email with new password to ${taName}?`)) return;

    try {
      await api.post(`/admin/users/${taId}/send_welcome_email`);
      alert('Welcome email sent successfully!');
    } catch (err) {
      alert(err.response?.data?.errors?.join(', ') || 'Failed to send email');
    }
  };

  const [slackModalUser, setSlackModalUser] = useState(null);

  const sendSlackCredentials = async (taId, taName, slackId) => {
    if (!slackId) {
      alert('This TA has no Slack ID configured. Please add one first.');
      return;
    }

    setSlackModalUser({ id: taId, name: taName, slackId });
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
                        onClick={() => sendWelcomeEmail(ta.id, ta.full_name)}
                        className="btn btn-outline"
                        style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                        title="Send welcome email with new temporary password"
                      >
                        📧 Email
                      </button>
                      <button
                        onClick={() => sendSlackCredentials(ta.id, ta.full_name, ta.slack_id)}
                        className="btn btn-outline"
                        style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                        title="Send credentials via Slack DM"
                        disabled={!ta.slack_id}
                      >
                        💬 Slack
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

      {slackModalUser && (
        <SlackCredentialsModal
          user={slackModalUser}
          onClose={() => setSlackModalUser(null)}
        />
      )}
    </div>
  );
}

function SlackCredentialsModal({ user, onClose }) {
  const [allUsers, setAllUsers] = useState([]);
  const [selectedUserIds, setSelectedUserIds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);

  useEffect(() => {
    loadAllUsers();
  }, []);

  const loadAllUsers = async () => {
    try {
      const [adminsRes, tasRes] = await Promise.all([
        api.get('/admin/users?role=admin'),
        api.get('/admin/users?role=ta')
      ]);

      const usersWithSlack = [
        ...adminsRes.data.users.map(u => ({ ...u, type: 'Admin' })),
        ...tasRes.data.users.map(u => ({ ...u, type: 'TA' }))
      ].filter(u => u.slack_id && u.id !== user.id && u.is_active); // Exclude the recipient, users without Slack ID, and inactive users

      setAllUsers(usersWithSlack);
    } catch (err) {
      console.error('Failed to load users', err);
    } finally {
      setLoading(false);
    }
  };

  const toggleUser = (userId) => {
    setSelectedUserIds(prev =>
      prev.includes(userId)
        ? prev.filter(id => id !== userId)
        : [...prev, userId]
    );
  };

  const handleSend = async () => {
    if (!confirm(`Send login credentials via Slack to ${user.name}?`)) return;

    setSending(true);
    try {
      await api.post(`/admin/users/${user.id}/send_slack_credentials`, {
        include_user_ids: selectedUserIds
      });
      alert('Credentials sent via Slack successfully!');
      onClose();
    } catch (err) {
      alert(err.response?.data?.errors || 'Failed to send Slack message');
    } finally {
      setSending(false);
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
          Send Credentials to {user.name}
        </h3>

        <p style={{ marginBottom: '1rem', color: 'var(--text-light)' }}>
          Select additional admins/TAs to include in the multi-person DM:
        </p>

        {loading ? (
          <div className="spinner" />
        ) : (
          <>
            {allUsers.length === 0 ? (
              <p style={{ color: 'var(--text-light)', fontStyle: 'italic' }}>
                No other users with Slack IDs configured
              </p>
            ) : (
              <div style={{ maxHeight: '300px', overflow: 'auto', marginBottom: '1rem' }}>
                {allUsers.map(u => (
                  <label
                    key={u.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      padding: '0.75rem',
                      border: '1px solid var(--border)',
                      borderRadius: '6px',
                      marginBottom: '0.5rem',
                      cursor: 'pointer',
                      backgroundColor: selectedUserIds.includes(u.id) ? 'var(--primary-light)' : 'transparent'
                    }}>
                    <input
                      type="checkbox"
                      checked={selectedUserIds.includes(u.id)}
                      onChange={() => toggleUser(u.id)}
                      style={{ marginRight: '0.75rem' }}
                    />
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: '500' }}>{u.full_name}</div>
                      <div style={{ fontSize: '0.875rem', color: 'var(--text-light)' }}>
                        {u.type} • <code>{u.slack_id}</code>
                      </div>
                    </div>
                  </label>
                ))}
              </div>
            )}

            <div style={{
              padding: '0.75rem',
              backgroundColor: 'var(--info-light)',
              borderRadius: '6px',
              marginBottom: '1rem',
              fontSize: '0.875rem'
            }}>
              <strong>Recipients:</strong> {user.name}
              {selectedUserIds.length > 0 && ` + ${selectedUserIds.length} other${selectedUserIds.length > 1 ? 's' : ''}`}
            </div>

            <div style={{ display: 'flex', gap: '1rem' }}>
              <button
                onClick={handleSend}
                className="btn btn-primary"
                disabled={sending}
              >
                {sending ? 'Sending...' : 'Send Credentials'}
              </button>
              <button
                onClick={onClose}
                className="btn btn-outline"
                disabled={sending}
              >
                Cancel
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function CreateTAModal({ onClose }) {
  // Generate a random temporary password
  const generatePassword = () => {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    const passwordLength = 12;
    let password = '';
    const array = new Uint8Array(passwordLength);
    window.crypto.getRandomValues(array);
    for (let i = 0; i < passwordLength; i++) {
      // To avoid modulo bias, reject values >= 256 - (256 % chars.length)
      let idx = array[i];
      // If bias possible, redraw index in a loop
      while (idx >= 256 - (256 % chars.length)) {
        idx = window.crypto.getRandomValues(new Uint8Array(1))[0];
      }
      password += chars[idx % chars.length];
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
