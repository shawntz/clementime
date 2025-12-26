import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function AdminProfile() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [profileForm, setProfileForm] = useState({
    username: '',
    first_name: '',
    last_name: '',
    email: '',
  });
  const [profileLoading, setProfileLoading] = useState(false);
  const [profileError, setProfileError] = useState(null);
  const [profileSuccess, setProfileSuccess] = useState(false);
  const [passwordForm, setPasswordForm] = useState({
    current_password: '',
    new_password: '',
    password_confirmation: '',
  });
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState(null);
  const [passwordSuccess, setPasswordSuccess] = useState(false);

  useEffect(() => {
    loadProfile();
  }, []);

  const loadProfile = async () => {
    try {
      const response = await api.get('/profile');
      setUser(response.data.user);
      setProfileForm({
        username: response.data.user.username,
        first_name: response.data.user.first_name,
        last_name: response.data.user.last_name,
        email: response.data.user.email,
      });
    } catch (err) {
      console.error('Failed to load profile', err);
    } finally {
      setLoading(false);
    }
  };

  const handleProfileUpdate = async (e) => {
    e.preventDefault();
    setProfileLoading(true);
    setProfileError(null);
    setProfileSuccess(false);

    try {
      const response = await api.put('/profile', {
        username: profileForm.username,
        first_name: profileForm.first_name,
        last_name: profileForm.last_name,
        email: profileForm.email,
      });
      setUser(response.data.user);
      setProfileSuccess(true);
      setEditing(false);
    } catch (err) {
      setProfileError(err.response?.data?.errors?.join(', ') || 'Failed to update profile');
    } finally {
      setProfileLoading(false);
    }
  };

  const handleCancelEdit = () => {
    setProfileForm({
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
    });
    setEditing(false);
    setProfileError(null);
    setProfileSuccess(false);
  };

  const handlePasswordChange = async (e) => {
    e.preventDefault();
    setPasswordLoading(true);
    setPasswordError(null);
    setPasswordSuccess(false);

    if (passwordForm.new_password !== passwordForm.password_confirmation) {
      setPasswordError('New password and confirmation do not match');
      setPasswordLoading(false);
      return;
    }

    if (passwordForm.new_password.length < 6) {
      setPasswordError('Password must be at least 6 characters');
      setPasswordLoading(false);
      return;
    }

    try {
      await api.put('/profile/password', {
        current_password: passwordForm.current_password,
        new_password: passwordForm.new_password,
        password_confirmation: passwordForm.password_confirmation,
      });
      setPasswordSuccess(true);
      setPasswordForm({
        current_password: '',
        new_password: '',
        password_confirmation: '',
      });
    } catch (err) {
      setPasswordError(err.response?.data?.errors?.join(', ') || 'Failed to change password');
    } finally {
      setPasswordLoading(false);
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
            alignItems: 'center',
            marginBottom: '1rem',
          }}
        >
          <h3 style={{ color: 'var(--primary)', margin: 0 }}>Profile Information</h3>
          {!editing && (
            <button type="button" className="btn btn-outline" onClick={() => setEditing(true)}>
              Edit Profile
            </button>
          )}
        </div>

        {!editing ? (
          <div style={{ display: 'grid', gap: '1rem', gridTemplateColumns: 'auto 1fr' }}>
            <strong>Name:</strong>
            <span>{user.full_name}</span>

            <strong>Username:</strong>
            <span>
              <code>{user.username}</code>
            </span>

            <strong>Email:</strong>
            <span>{user.email}</span>

            <strong>Role:</strong>
            <span>
              <span
                className="badge badge-primary"
                style={{ display: 'inline-block', width: 'auto' }}
              >
                {user.role.toUpperCase()}
              </span>
            </span>
          </div>
        ) : (
          <form onSubmit={handleProfileUpdate} style={{ maxWidth: '500px' }}>
            <div style={{ marginBottom: '1rem' }}>
              <label className="form-label">First Name</label>
              <input
                type="text"
                className="form-input"
                value={profileForm.first_name}
                onChange={(e) => setProfileForm({ ...profileForm, first_name: e.target.value })}
                required
              />
            </div>

            <div style={{ marginBottom: '1rem' }}>
              <label className="form-label">Last Name</label>
              <input
                type="text"
                className="form-input"
                value={profileForm.last_name}
                onChange={(e) => setProfileForm({ ...profileForm, last_name: e.target.value })}
                required
              />
            </div>

            <div style={{ marginBottom: '1rem' }}>
              <label className="form-label">Username</label>
              <input
                type="text"
                className="form-input"
                value={profileForm.username}
                onChange={(e) => setProfileForm({ ...profileForm, username: e.target.value })}
                required
              />
              <div
                style={{ fontSize: '0.875rem', color: 'var(--text-light)', marginTop: '0.25rem' }}
              >
                Auto-filled as first.last but can be changed
              </div>
            </div>

            <div style={{ marginBottom: '1rem' }}>
              <label className="form-label">Email</label>
              <input
                type="email"
                className="form-input"
                value={profileForm.email}
                onChange={(e) => setProfileForm({ ...profileForm, email: e.target.value })}
                required
              />
            </div>

            {profileError && (
              <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
                {profileError}
              </div>
            )}

            {profileSuccess && (
              <div className="alert alert-success" style={{ marginBottom: '1rem' }}>
                Profile updated successfully!
              </div>
            )}

            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button type="submit" className="btn btn-primary" disabled={profileLoading}>
                {profileLoading ? 'Saving...' : 'Save Changes'}
              </button>
              <button
                type="button"
                className="btn btn-outline"
                onClick={handleCancelEdit}
                disabled={profileLoading}
              >
                Cancel
              </button>
            </div>
          </form>
        )}
      </div>

      <div className="card">
        <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>Change Password</h3>

        <form onSubmit={handlePasswordChange} style={{ maxWidth: '500px' }}>
          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Current Password</label>
            <input
              type="password"
              className="form-input"
              value={passwordForm.current_password}
              onChange={(e) =>
                setPasswordForm({ ...passwordForm, current_password: e.target.value })
              }
              required
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">New Password</label>
            <input
              type="password"
              className="form-input"
              value={passwordForm.new_password}
              onChange={(e) => setPasswordForm({ ...passwordForm, new_password: e.target.value })}
              required
              minLength={6}
            />
            <div style={{ fontSize: '0.875rem', color: 'var(--text-light)', marginTop: '0.25rem' }}>
              Minimum 6 characters
            </div>
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label className="form-label">Confirm New Password</label>
            <input
              type="password"
              className="form-input"
              value={passwordForm.password_confirmation}
              onChange={(e) =>
                setPasswordForm({ ...passwordForm, password_confirmation: e.target.value })
              }
              required
              minLength={6}
            />
          </div>

          {passwordError && (
            <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
              {passwordError}
            </div>
          )}

          {passwordSuccess && (
            <div className="alert alert-success" style={{ marginBottom: '1rem' }}>
              Password changed successfully!
            </div>
          )}

          <button type="submit" className="btn btn-primary" disabled={passwordLoading}>
            {passwordLoading ? 'Changing Password...' : 'Change Password'}
          </button>
        </form>
      </div>
    </div>
  );
}
