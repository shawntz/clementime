import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function UserManagement() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [editingUser, setEditingUser] = useState(null);

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      const response = await api.get('/admin/users?role=admin');
      setUsers(response.data.users);
    } catch (err) {
      console.error('Failed to load admin users', err);
    } finally {
      setLoading(false);
    }
  };

  const deleteUser = async (userId) => {
    if (!confirm('Delete this admin user?')) return;

    try {
      await api.delete(`/admin/users/${userId}`);
      loadUsers();
    } catch (err) {
      alert('Failed to delete user');
    }
  };

  const toggleUserStatus = async (userId, currentStatus) => {
    try {
      await api.put(`/admin/users/${userId}`, {
        is_active: !currentStatus
      });
      loadUsers();
    } catch (err) {
      alert('Failed to update user status');
    }
  };

  const sendWelcomeEmail = async (userId, userName) => {
    if (!confirm(`Send welcome email with new password to ${userName}?`)) return;

    try {
      await api.post(`/admin/users/${userId}/send_welcome_email`);
      alert('Welcome email sent successfully!');
    } catch (err) {
      alert(err.response?.data?.errors?.join(', ') || 'Failed to send email');
    }
  };

  const [slackModalUser, setSlackModalUser] = useState(null);

  const sendSlackCredentials = async (userId, userName, slackId) => {
    if (!slackId) {
      alert('This user has no Slack ID configured. Please add one first.');
      return;
    }

    setSlackModalUser({ id: userId, name: userName, slackId });
  };

  if (loading) {
    return <div className="spinner" />;
  }

  return (
    <div>
      <div className="card" style={{ marginBottom: '1.5rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
          <h3 style={{ color: 'var(--primary)', margin: 0 }}>
            Admin User Management
          </h3>
          <button
            className="btn btn-primary"
            onClick={() => setShowCreateModal(true)}
          >
            + Create Admin User
          </button>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table className="table">
            <thead>
              <tr>
                <th>Username</th>
                <th>Full Name</th>
                <th>Email</th>
                <th>Slack ID</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id}>
                  <td style={{ fontWeight: '500' }}>{user.username}</td>
                  <td>{user.full_name}</td>
                  <td>{user.email}</td>
                  <td>{user.slack_id ? <code>{user.slack_id}</code> : <span style={{ color: 'var(--text-light)' }}>Not set</span>}</td>
                  <td>
                    <span className={`badge ${user.is_active ? 'badge-success' : 'badge-error'}`}>
                      {user.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                      <button
                        className="btn btn-outline"
                        onClick={() => setEditingUser(user)}
                        style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => sendWelcomeEmail(user.id, user.full_name)}
                        className="btn btn-outline"
                        style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                        title="Send welcome email with new temporary password"
                      >
                        📧 Email
                      </button>
                      <button
                        onClick={() => sendSlackCredentials(user.id, user.full_name, user.slack_id)}
                        className="btn btn-outline"
                        style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                        title="Send credentials via Slack DM"
                        disabled={!user.slack_id}
                      >
                        💬 Slack
                      </button>
                      <button
                        className="btn"
                        onClick={() => toggleUserStatus(user.id, user.is_active)}
                        style={{
                          fontSize: '0.75rem',
                          padding: '0.25rem 0.5rem',
                          backgroundColor: user.is_active ? 'var(--warning)' : 'var(--success)',
                          color: 'white'
                        }}
                      >
                        {user.is_active ? 'Deactivate' : 'Activate'}
                      </button>
                      <button
                        className="btn"
                        onClick={() => deleteUser(user.id)}
                        style={{
                          fontSize: '0.75rem',
                          padding: '0.25rem 0.5rem',
                          backgroundColor: 'var(--error)',
                          color: 'white'
                        }}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {users.length === 0 && (
            <p style={{ textAlign: 'center', color: 'var(--text-light)', padding: '2rem' }}>
              No admin users found
            </p>
          )}
        </div>
      </div>

      {/* Create Modal */}
      {showCreateModal && (
        <CreateAdminModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={() => {
            setShowCreateModal(false);
            loadUsers();
          }}
        />
      )}

      {/* Edit Modal */}
      {editingUser && (
        <EditAdminModal
          user={editingUser}
          onClose={() => setEditingUser(null)}
          onSuccess={() => {
            setEditingUser(null);
            loadUsers();
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
      ].filter(u => u.slack_id && u.id !== user.id);

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

function CreateAdminModal({ onClose, onSuccess }) {
  const [formData, setFormData] = useState({
    username: '',
    full_name: '',
    email: '',
    password: '',
    slack_id: ''
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError(null);

    try {
      await api.post('/admin/users', {
        ...formData,
        role: 'admin'
      });
      onSuccess();
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Failed to create admin user');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }} onClick={onClose}>
      <div className="card" style={{ maxWidth: '500px', width: '90%' }} onClick={(e) => e.stopPropagation()}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Create New Admin User
        </h3>

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Username *</label>
            <input
              type="text"
              className="form-input"
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Full Name *</label>
            <input
              type="text"
              className="form-input"
              value={formData.full_name}
              onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Email *</label>
            <input
              type="email"
              className="form-input"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Password *</label>
            <input
              type="password"
              className="form-input"
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              required
              minLength="6"
            />
            <small style={{ fontSize: '0.75rem', color: 'var(--text-light)' }}>
              Minimum 6 characters
            </small>
          </div>

          <div className="form-group">
            <label className="form-label">Slack ID</label>
            <input
              type="text"
              className="form-input"
              placeholder="e.g., U01234ABCDE"
              value={formData.slack_id}
              onChange={(e) => setFormData({ ...formData, slack_id: e.target.value })}
            />
            <small style={{ fontSize: '0.75rem', color: 'var(--text-light)' }}>
              Used for Slack notifications and channel assignments
            </small>
          </div>

          {error && (
            <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
              {error}
            </div>
          )}

          <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end' }}>
            <button
              type="button"
              className="btn btn-outline"
              onClick={onClose}
              disabled={saving}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={saving}
            >
              {saving ? 'Creating...' : 'Create Admin'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function EditAdminModal({ user, onClose, onSuccess }) {
  const [formData, setFormData] = useState({
    username: user.username,
    full_name: user.full_name,
    email: user.email,
    slack_id: user.slack_id || ''
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError(null);

    try {
      await api.put(`/admin/users/${user.id}`, formData);
      onSuccess();
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Failed to update admin user');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }} onClick={onClose}>
      <div
        className="card"
        onClick={(e) => e.stopPropagation()}
        style={{ maxWidth: '500px', width: '90%' }}>
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
          Edit Admin: {user.full_name}
        </h3>

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Username *</label>
            <input
              type="text"
              className="form-input"
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Full Name *</label>
            <input
              type="text"
              className="form-input"
              value={formData.full_name}
              onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Email *</label>
            <input
              type="email"
              className="form-input"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Slack ID</label>
            <input
              type="text"
              className="form-input"
              placeholder="e.g., U01234ABCDE"
              value={formData.slack_id}
              onChange={(e) => setFormData({ ...formData, slack_id: e.target.value })}
            />
            <small style={{ fontSize: '0.75rem', color: 'var(--text-light)' }}>
              Used for Slack notifications and channel assignments
            </small>
          </div>

          {error && (
            <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
              {error}
            </div>
          )}

          <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end' }}>
            <button
              type="button"
              className="btn btn-outline"
              onClick={onClose}
              disabled={saving}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={saving}
            >
              {saving ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
