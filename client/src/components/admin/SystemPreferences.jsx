import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function SystemPreferences() {
  const [activeTab, setActiveTab] = useState('exam');
  const [showGoogleHelp, setShowGoogleHelp] = useState(false);
  const [config, setConfig] = useState({
    exam_day: 'friday',
    exam_start_time: '13:30',
    exam_end_time: '14:50',
    exam_duration_minutes: 7,
    exam_buffer_minutes: 1,
    quarter_start_date: '',
    total_exams: 5,
    navbar_title: '',
    base_url: '',
    google_drive_folder_id: '',
    google_service_account_json: '',
    slack_bot_token: '',
    slack_app_token: '',
    slack_signing_secret: '',
    slack_channel_name_template: '{{course}}-oralexam-{{ta_name}}-week{{week}}-{{term}}',
    slack_student_message_template: '📝 TEST: Oral Exam Session for {{student_name}}\n\nDate: {{date}}\nTime: {{time}}\nLocation: {{location}}\nFacilitator: {{ta_name}}\n\n📋 Course: {{course}} | 🎓 Term: {{term}}',
    slack_ta_message_template: '📋 *Oral Exam Schedule*\n\n*Date:* {{date}}\n*Location:* {{location}}\n*Week:* {{week}}\n\n*Today\'s Schedule ({{student_count}} students):*\n\n{{schedule_list}}\n\n🌐 Go to TA Page\n📝 Grade Form\n\n📚 Course: {{course}} | 🎓 Week {{week}} | 👥 {{student_count}} students',
    slack_test_mode: false,
    slack_test_user_id: '',
    admin_slack_ids: '',
    super_admin_slack_id: '',
    super_admin_email: '',
    slack_exam_location: '',
    slack_course_name: '',
    slack_term: '',
    grade_form_urls: {},
    exam_dates: {}  // New: flexible exam dates { 1: '2025-01-15', 2: '2025-01-22', ... }
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [googleDriveStatus, setGoogleDriveStatus] = useState(null);
  const [sendingTest, setSendingTest] = useState(null);
  const [testingDrive, setTestingDrive] = useState(false);
  const [driveTestResult, setDriveTestResult] = useState(null);

  useEffect(() => {
    loadConfig();
  }, []);

  const loadConfig = async () => {
    setLoading(true);
    try {
      const response = await api.get('/admin/config');
      const examDates = response.data.exam_dates || {};

      // Migrate old format to new format if needed
      const migratedDates = {};
      Object.keys(examDates).forEach(key => {
        // If key is a number (old format like "1", "2"), migrate it
        if (/^\d+$/.test(key)) {
          // Skip migration - let user set odd/even dates manually
        } else {
          // Already in new format (like "1_odd", "1_even")
          migratedDates[key] = examDates[key];
        }
      });

      // Ensure objects are always initialized
      const loadedConfig = {
        ...response.data,
        grade_form_urls: response.data.grade_form_urls || {},
        exam_dates: migratedDates
      };
      setConfig(loadedConfig);
    } catch (err) {
      console.error('Failed to load config', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setGoogleDriveStatus(null);

    try {
      console.log('Saving config:', config);
      const response = await api.put('/admin/config', { config });
      console.log('Save response:', response.data);

      // Check if Google Drive validation results are included
      if (response.data.google_drive_status) {
        setGoogleDriveStatus(response.data.google_drive_status);
      }

      alert('Configuration saved successfully');
      // Reload config to ensure we have the latest from server
      await loadConfig();
    } catch (err) {
      console.error('Save error:', err);
      alert('Failed to save configuration: ' + (err.response?.data?.error || err.message));
    } finally {
      setSaving(false);
    }
  };

  const handleChange = (field, value) => {
    setConfig(prev => ({ ...prev, [field]: value }));
  };

  const handleFileUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        // Validate it's valid JSON
        JSON.parse(event.target.result);
        // Base64 encode the file content
        const base64 = btoa(event.target.result);
        handleChange('google_service_account_json', base64);
        alert('Service account JSON file uploaded and encoded successfully');
      } catch (err) {
        alert('Invalid JSON file: ' + err.message);
      }
    };
    reader.readAsText(file);
  };

  const sendTestMessage = async (messageType) => {
    if (!config.slack_test_user_id) {
      alert('Please set a Test User Slack ID first');
      return;
    }

    setSendingTest(messageType);
    try {
      const response = await api.post('/admin/slack_messages/test_message', {
        message_type: messageType,
        test_user_id: config.slack_test_user_id
      });
      alert(`✅ Test ${messageType} message sent successfully!`);
    } catch (err) {
      alert(`Failed to send test message: ${err.response?.data?.error || err.message}`);
    } finally {
      setSendingTest(null);
    }
  };

  const testGoogleDriveConnection = async () => {
    setTestingDrive(true);
    setDriveTestResult(null);

    try {
      const response = await api.post('/admin/config/test_google_drive');
      setDriveTestResult(response.data);
    } catch (err) {
      setDriveTestResult({
        success: false,
        error: err.response?.data?.error || err.message
      });
    } finally {
      setTestingDrive(false);
    }
  };

  if (loading) {
    return <div className="spinner" />;
  }

  return (
    <div className="card">
      <h3 style={{ color: 'var(--primary)', marginBottom: '1rem' }}>
        System Preferences
      </h3>

      {/* Tabs */}
      <div style={{
        display: 'flex',
        gap: '0.5rem',
        marginBottom: '1.5rem',
        borderBottom: '2px solid var(--border)'
      }}>
        <button
          type="button"
          onClick={() => setActiveTab('exam')}
          style={{
            padding: '0.75rem 1.5rem',
            background: 'none',
            border: 'none',
            borderBottom: activeTab === 'exam' ? '2px solid var(--primary)' : '2px solid transparent',
            color: activeTab === 'exam' ? 'var(--primary)' : 'var(--text-light)',
            fontWeight: activeTab === 'exam' ? '600' : '400',
            cursor: 'pointer',
            marginBottom: '-2px'
          }}
        >
          Exam Settings
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('integrations')}
          style={{
            padding: '0.75rem 1.5rem',
            background: 'none',
            border: 'none',
            borderBottom: activeTab === 'integrations' ? '2px solid var(--primary)' : '2px solid transparent',
            color: activeTab === 'integrations' ? 'var(--primary)' : 'var(--text-light)',
            fontWeight: activeTab === 'integrations' ? '600' : '400',
            cursor: 'pointer',
            marginBottom: '-2px'
          }}
        >
          Integrations
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('slack-messages')}
          style={{
            padding: '0.75rem 1.5rem',
            background: 'none',
            border: 'none',
            borderBottom: activeTab === 'slack-messages' ? '2px solid var(--primary)' : '2px solid transparent',
            color: activeTab === 'slack-messages' ? 'var(--primary)' : 'var(--text-light)',
            fontWeight: activeTab === 'slack-messages' ? '600' : '400',
            cursor: 'pointer',
            marginBottom: '-2px'
          }}
        >
          Slack Messages
        </button>
      </div>

      <form onSubmit={handleSubmit}>
        {activeTab === 'exam' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {/* Exam Day */}
          <div>
            <label htmlFor="exam_day" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Exam Day of Week
            </label>
            <select
              id="exam_day"
              className="form-input"
              value={config.exam_day}
              onChange={(e) => handleChange('exam_day', e.target.value)}
              style={{ width: '100%' }}
            >
              <option value="monday">Monday</option>
              <option value="tuesday">Tuesday</option>
              <option value="wednesday">Wednesday</option>
              <option value="thursday">Thursday</option>
              <option value="friday">Friday</option>
              <option value="saturday">Saturday</option>
              <option value="sunday">Sunday</option>
            </select>
          </div>

          {/* Start Time */}
          <div>
            <label htmlFor="exam_start_time" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Exam Start Time
            </label>
            <input
              id="exam_start_time"
              type="time"
              className="form-input"
              value={config.exam_start_time}
              onChange={(e) => handleChange('exam_start_time', e.target.value)}
              style={{ width: '100%' }}
            />
          </div>

          {/* End Time */}
          <div>
            <label htmlFor="exam_end_time" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Exam End Time
            </label>
            <input
              id="exam_end_time"
              type="time"
              className="form-input"
              value={config.exam_end_time}
              onChange={(e) => handleChange('exam_end_time', e.target.value)}
              style={{ width: '100%' }}
            />
          </div>

          {/* Exam Duration */}
          <div>
            <label htmlFor="exam_duration_minutes" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Exam Duration (minutes)
            </label>
            <input
              id="exam_duration_minutes"
              type="number"
              className="form-input"
              value={config.exam_duration_minutes}
              onChange={(e) => handleChange('exam_duration_minutes', parseInt(e.target.value))}
              min="1"
              style={{ width: '100%' }}
            />
          </div>

          {/* Buffer Time */}
          <div>
            <label htmlFor="exam_buffer_minutes" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Buffer Between Exams (minutes)
            </label>
            <input
              id="exam_buffer_minutes"
              type="number"
              className="form-input"
              value={config.exam_buffer_minutes}
              onChange={(e) => handleChange('exam_buffer_minutes', parseInt(e.target.value))}
              min="0"
              style={{ width: '100%' }}
            />
          </div>

          {/* Quarter Start Date */}
          <div>
            <label htmlFor="quarter_start_date" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Quarter Start Date
            </label>
            <input
              id="quarter_start_date"
              type="date"
              className="form-input"
              value={config.quarter_start_date}
              onChange={(e) => handleChange('quarter_start_date', e.target.value)}
              style={{ width: '100%' }}
            />
          </div>

          {/* Total Exams */}
          <div>
            <label htmlFor="total_exams" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Total Number of Exams
            </label>
            <input
              id="total_exams"
              type="number"
              className="form-input"
              value={config.total_exams}
              onChange={(e) => handleChange('total_exams', parseInt(e.target.value))}
              min="1"
              max="10"
              style={{ width: '100%' }}
            />
          </div>

          {/* Exam Dates */}
          <div>
            <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Exam Session Dates
            </label>
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginBottom: '0.75rem', display: 'block' }}>
              Specify the exact date for each oral exam session (odd and even sections have different dates)
            </small>
            {Array.from({ length: config.total_exams }, (_, i) => i + 1).map((examNum) => (
              <div key={examNum} style={{ marginBottom: '1rem', padding: '1rem', background: 'var(--background)', borderRadius: '8px', border: '1px solid var(--border)' }}>
                <div style={{ marginBottom: '0.5rem', fontSize: '0.875rem', fontWeight: '600', color: 'var(--primary)' }}>
                  Oral Exam #{examNum}
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div>
                    <label htmlFor={`exam_date_${examNum}_odd`} style={{ display: 'block', marginBottom: '0.25rem', fontSize: '0.875rem', fontWeight: '500' }}>
                      Odd Sections Date
                    </label>
                    <input
                      id={`exam_date_${examNum}_odd`}
                      type="date"
                      className="form-input"
                      value={config.exam_dates?.[`${examNum}_odd`] || ''}
                      onChange={(e) => handleChange('exam_dates', { ...config.exam_dates, [`${examNum}_odd`]: e.target.value })}
                      style={{ width: '100%' }}
                    />
                  </div>
                  <div>
                    <label htmlFor={`exam_date_${examNum}_even`} style={{ display: 'block', marginBottom: '0.25rem', fontSize: '0.875rem', fontWeight: '500' }}>
                      Even Sections Date
                    </label>
                    <input
                      id={`exam_date_${examNum}_even`}
                      type="date"
                      className="form-input"
                      value={config.exam_dates?.[`${examNum}_even`] || ''}
                      onChange={(e) => handleChange('exam_dates', { ...config.exam_dates, [`${examNum}_even`]: e.target.value })}
                      style={{ width: '100%' }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Navbar Title */}
          <div>
            <label htmlFor="navbar_title" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Navbar Title
            </label>
            <input
              id="navbar_title"
              type="text"
              className="form-input"
              value={config.navbar_title}
              onChange={(e) => handleChange('navbar_title', e.target.value)}
              placeholder="e.g., Admin, PSYCH 1, CS 101"
              style={{ width: '100%' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block' }}>
              Customize the title displayed in the navigation bar (defaults to "Admin" if empty)
            </small>
          </div>

          {/* Base URL */}
          <div>
            <label htmlFor="base_url" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Application Base URL
            </label>
            <input
              id="base_url"
              type="url"
              className="form-input"
              value={config.base_url}
              onChange={(e) => handleChange('base_url', e.target.value)}
              placeholder="https://clementime.app"
              style={{ width: '100%' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block' }}>
              The base URL where your application is hosted (used in Slack links and notifications)
            </small>
          </div>

          {/* Grade Form URLs */}
          <div>
            <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Google Form Grading Links
            </label>
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginBottom: '0.75rem', display: 'block' }}>
              Add Google Form links for each oral exam for TA grading
            </small>
            {Array.from({ length: config.total_exams }, (_, i) => i + 1).map((examNum) => (
              <div key={examNum} style={{ marginBottom: '0.75rem' }}>
                <label htmlFor={`grade_form_${examNum}`} style={{ display: 'block', marginBottom: '0.25rem', fontSize: '0.875rem', fontWeight: '500' }}>
                  Oral Exam #{examNum}
                </label>
                <input
                  id={`grade_form_${examNum}`}
                  type="url"
                  className="form-input"
                  value={config.grade_form_urls?.[examNum] || ''}
                  onChange={(e) => handleChange('grade_form_urls', { ...config.grade_form_urls, [examNum]: e.target.value })}
                  placeholder="https://forms.gle/xRahzQUg5Vkzps5w5"
                  style={{ width: '100%' }}
                />
              </div>
            ))}
          </div>

          {/* Save Button */}
          <div>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={saving}
            >
              {saving ? 'Saving...' : 'Save Configuration'}
            </button>
          </div>
        </div>
        )}

        {activeTab === 'integrations' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          <h4 style={{ color: 'var(--primary)', marginTop: 0 }}>Google Drive</h4>

          {/* Google Drive Folder ID */}
          <div>
            <label htmlFor="google_drive_folder_id" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Google Drive Folder ID
            </label>
            <input
              id="google_drive_folder_id"
              type="text"
              className="form-input"
              value={config.google_drive_folder_id}
              onChange={(e) => handleChange('google_drive_folder_id', e.target.value)}
              placeholder="e.g., 1a2b3c4d5e6f7g8h9i0j"
              style={{ width: '100%' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block' }}>
              The folder ID from the Google Drive URL where recordings will be uploaded
            </small>
          </div>

          {/* Google Drive Validation Status */}
          {googleDriveStatus && (
            <div style={{
              padding: '1rem',
              borderRadius: '8px',
              marginBottom: '1rem',
              backgroundColor: googleDriveStatus.valid ? '#d1fae5' : '#fee2e2',
              border: `1px solid ${googleDriveStatus.valid ? '#10b981' : '#ef4444'}`
            }}>
              <div style={{
                fontWeight: '600',
                marginBottom: '0.5rem',
                color: googleDriveStatus.valid ? '#065f46' : '#991b1b'
              }}>
                {googleDriveStatus.message}
              </div>
              {googleDriveStatus.details && (
                <div style={{
                  fontSize: '0.875rem',
                  color: googleDriveStatus.valid ? '#047857' : '#b91c1c'
                }}>
                  {googleDriveStatus.details}
                </div>
              )}
              {googleDriveStatus.error && (
                <div style={{
                  fontSize: '0.875rem',
                  marginTop: '0.5rem',
                  fontFamily: 'monospace',
                  color: '#991b1b'
                }}>
                  Error: {googleDriveStatus.error}
                </div>
              )}
            </div>
          )}

          {/* Test Google Drive Connection */}
          <div>
            <button
              type="button"
              onClick={testGoogleDriveConnection}
              disabled={testingDrive}
              className="btn btn-outline"
              style={{ marginBottom: '1rem' }}
            >
              {testingDrive ? '🔄 Testing...' : '🧪 Test Google Drive Connection'}
            </button>
          </div>

          {driveTestResult && (
            <div style={{
              padding: '1rem',
              borderRadius: '8px',
              marginBottom: '1rem',
              backgroundColor: driveTestResult.success ? '#d1fae5' : '#fee2e2',
              border: `1px solid ${driveTestResult.success ? '#10b981' : '#ef4444'}`
            }}>
              <div style={{
                fontWeight: '600',
                marginBottom: '0.5rem',
                color: driveTestResult.success ? '#065f46' : '#991b1b'
              }}>
                {driveTestResult.success ? '✅ Connection Successful' : '❌ Connection Failed'}
              </div>

              {driveTestResult.error && (
                <div style={{
                  fontSize: '0.875rem',
                  color: '#991b1b',
                  marginBottom: '0.5rem',
                  fontFamily: 'monospace'
                }}>
                  {driveTestResult.error}
                </div>
              )}

              {driveTestResult.folder_structure && (
                <div style={{ marginTop: '1rem' }}>
                  <div style={{ fontWeight: '600', marginBottom: '0.5rem', color: '#065f46' }}>
                    Folder Structure:
                  </div>
                  <div style={{
                    fontFamily: 'monospace',
                    fontSize: '0.875rem',
                    background: 'white',
                    padding: '0.75rem',
                    borderRadius: '4px',
                    border: '1px solid #10b981',
                    maxHeight: '300px',
                    overflowY: 'auto'
                  }}>
                    <div style={{ marginBottom: '0.5rem', color: '#047857' }}>
                      📁 <strong>{driveTestResult.root_folder_name}</strong> (Root)
                    </div>
                    {driveTestResult.folder_structure.map((folder, idx) => (
                      <div key={idx} style={{ marginLeft: '1.5rem', marginBottom: '0.25rem', color: '#059669' }}>
                        📁 {folder}
                      </div>
                    ))}
                    {driveTestResult.folder_structure.length === 0 && (
                      <div style={{ marginLeft: '1.5rem', color: '#6b7280', fontStyle: 'italic' }}>
                        (No subfolders - recordings will be organized here)
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Google Service Account JSON */}
          <div>
            <label htmlFor="google_service_account_json" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem', fontWeight: '600' }}>
              Google Service Account JSON
              <button
                type="button"
                onClick={() => setShowGoogleHelp(!showGoogleHelp)}
                style={{
                  background: 'var(--primary)',
                  color: 'white',
                  border: 'none',
                  borderRadius: '50%',
                  width: '20px',
                  height: '20px',
                  fontSize: '0.75rem',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontWeight: 'bold'
                }}
                title="How to get service account JSON"
              >
                ?
              </button>
            </label>

            {showGoogleHelp && (
              <div style={{
                background: '#e3f2fd',
                border: '1px solid #2196f3',
                borderRadius: '8px',
                padding: '1rem',
                marginBottom: '1rem',
                fontSize: '0.875rem'
              }}>
                <h5 style={{ margin: '0 0 0.75rem 0', color: '#1976d2' }}>How to Create a Google Service Account</h5>
                <ol style={{ margin: 0, paddingLeft: '1.25rem', lineHeight: '1.6' }}>
                  <li style={{ marginBottom: '0.5rem' }}>
                    Go to <a href="https://console.cloud.google.com" target="_blank" rel="noopener noreferrer" style={{ color: '#1976d2' }}>Google Cloud Console</a>
                  </li>
                  <li style={{ marginBottom: '0.5rem' }}>
                    Create a new project or select an existing one
                  </li>
                  <li style={{ marginBottom: '0.5rem' }}>
                    Navigate to <strong>APIs & Services → Credentials</strong>
                  </li>
                  <li style={{ marginBottom: '0.5rem' }}>
                    Click <strong>Create Credentials → Service Account</strong>
                  </li>
                  <li style={{ marginBottom: '0.5rem' }}>
                    Fill in the service account details and click <strong>Create and Continue</strong>
                  </li>
                  <li style={{ marginBottom: '0.5rem' }}>
                    Grant the service account the <strong>Editor</strong> role (or custom role with Drive access)
                  </li>
                  <li style={{ marginBottom: '0.5rem' }}>
                    Click on the created service account, go to <strong>Keys</strong> tab
                  </li>
                  <li style={{ marginBottom: '0.5rem' }}>
                    Click <strong>Add Key → Create new key → JSON</strong>
                  </li>
                  <li style={{ marginBottom: '0.5rem' }}>
                    The JSON file will be downloaded - upload it here
                  </li>
                  <li>
                    <strong>Important:</strong> Enable the <strong>Google Drive API</strong> for your project in APIs & Services → Library
                  </li>
                </ol>
              </div>
            )}

            <div style={{ marginBottom: '0.5rem' }}>
              <input
                type="file"
                accept=".json"
                onChange={handleFileUpload}
                style={{ display: 'block', marginBottom: '0.5rem' }}
              />
              <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', display: 'block' }}>
                Upload your Google service account JSON file (will be automatically base64 encoded)
              </small>
            </div>
            <textarea
              id="google_service_account_json"
              className="form-input"
              value={config.google_service_account_json}
              onChange={(e) => handleChange('google_service_account_json', e.target.value)}
              placeholder="Or paste the base64-encoded JSON here manually"
              rows="4"
              style={{ width: '100%', fontFamily: 'monospace', fontSize: '0.875rem' }}
            />
          </div>

          <hr style={{ border: 'none', borderTop: '1px solid var(--border)', margin: '1rem 0' }} />

          <h4 style={{ color: 'var(--primary)', marginTop: 0 }}>Slack</h4>

          {/* Slack Bot Token */}
          <div>
            <label htmlFor="slack_bot_token" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Slack Bot Token
            </label>
            <input
              id="slack_bot_token"
              type="password"
              className="form-input"
              value={config.slack_bot_token}
              onChange={(e) => handleChange('slack_bot_token', e.target.value)}
              placeholder="xoxb-..."
              style={{ width: '100%' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block' }}>
              Your Slack bot token for sending notifications
            </small>
          </div>

          {/* Slack App Token */}
          <div>
            <label htmlFor="slack_app_token" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Slack App Token
            </label>
            <input
              id="slack_app_token"
              type="password"
              className="form-input"
              value={config.slack_app_token}
              onChange={(e) => handleChange('slack_app_token', e.target.value)}
              placeholder="xapp-..."
              style={{ width: '100%' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block' }}>
              Your Slack app-level token (starts with xapp-)
            </small>
          </div>

          {/* Slack Signing Secret */}
          <div>
            <label htmlFor="slack_signing_secret" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
              Slack Signing Secret
            </label>
            <input
              id="slack_signing_secret"
              type="password"
              className="form-input"
              value={config.slack_signing_secret}
              onChange={(e) => handleChange('slack_signing_secret', e.target.value)}
              placeholder="Enter signing secret"
              style={{ width: '100%' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block' }}>
              Your Slack app signing secret for webhook verification
            </small>
          </div>

          {/* Save Button */}
          <div>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={saving}
            >
              {saving ? 'Saving...' : 'Save Configuration'}
            </button>
          </div>
        </div>
        )}

        {activeTab === 'slack-messages' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {/* Test Mode Section */}
          <div style={{ background: '#fef3c7', border: '2px solid #f59e0b', borderRadius: '8px', padding: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '1rem' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', cursor: 'pointer', fontWeight: '600', color: '#92400e' }}>
                <input
                  type="checkbox"
                  checked={config.slack_test_mode}
                  onChange={(e) => handleChange('slack_test_mode', e.target.checked)}
                  style={{ width: '20px', height: '20px', cursor: 'pointer' }}
                />
                <span>🧪 Test Mode</span>
              </label>
            </div>

            {config.slack_test_mode && (
              <div>
                <label htmlFor="slack_test_user_id" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600', color: '#92400e' }}>
                  Test User Slack ID
                </label>
                <input
                  id="slack_test_user_id"
                  type="text"
                  className="form-input"
                  value={config.slack_test_user_id}
                  onChange={(e) => handleChange('slack_test_user_id', e.target.value)}
                  placeholder="U01234ABCDE"
                  style={{ width: '100%', fontFamily: 'monospace' }}
                />
                <small style={{ color: '#92400e', fontSize: '0.875rem', marginTop: '0.5rem', display: 'block' }}>
                  <strong>⚠️ Warning:</strong> When test mode is enabled, ALL Slack messages will be sent only to this user ID instead of the actual recipients. Use this for testing before sending to students/TAs.
                </small>
              </div>
            )}

            {!config.slack_test_mode && (
              <p style={{ color: '#92400e', fontSize: '0.875rem', margin: 0 }}>
                Test mode is currently disabled. Messages will be sent to actual recipients.
              </p>
            )}
          </div>

          <div style={{ marginBottom: '1.5rem' }}>
            <label htmlFor="super_admin_slack_id" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600', color: 'var(--text)' }}>
              Super Admin Slack ID
            </label>
            <input
              id="super_admin_slack_id"
              type="text"
              className="form-input"
              value={config.super_admin_slack_id}
              onChange={(e) => handleChange('super_admin_slack_id', e.target.value)}
              placeholder="U01234ABCDE"
              style={{ width: '100%', fontFamily: 'monospace' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.5rem', display: 'block' }}>
              Super admin Slack ID to include in all credential MPDMs
            </small>
          </div>

          <div style={{ marginBottom: '1.5rem' }}>
            <label htmlFor="super_admin_email" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600', color: 'var(--text)' }}>
              Super Admin Email
            </label>
            <input
              id="super_admin_email"
              type="email"
              className="form-input"
              value={config.super_admin_email}
              onChange={(e) => handleChange('super_admin_email', e.target.value)}
              placeholder="admin@example.com"
              style={{ width: '100%' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.5rem', display: 'block' }}>
              Email to CC on all password/credential emails
            </small>
          </div>

          <div style={{ marginBottom: '1.5rem' }}>
            <label htmlFor="admin_slack_ids" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600', color: 'var(--text)' }}>
              Additional Admin Slack IDs (for MPDMs)
            </label>
            <input
              id="admin_slack_ids"
              type="text"
              className="form-input"
              value={config.admin_slack_ids}
              onChange={(e) => handleChange('admin_slack_ids', e.target.value)}
              placeholder="U01234ABCDE, U56789FGHIJ"
              style={{ width: '100%', fontFamily: 'monospace' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.5rem', display: 'block' }}>
              Comma-separated list of additional admin Slack IDs to include in credential MPDMs
            </small>
          </div>

          <div style={{ background: '#e0f2fe', border: '1px solid #0ea5e9', borderRadius: '8px', padding: '1rem', fontSize: '0.875rem' }}>
            <strong style={{ color: '#0369a1' }}>Available Variables:</strong>
            <ul style={{ margin: '0.5rem 0', paddingLeft: '1.25rem', lineHeight: '1.6', color: '#075985' }}>
              <li><code>{'{{student_name}}'}</code> - Student's full name</li>
              <li><code>{'{{ta_name}}'}</code> - TA's full name (for TA messages)</li>
              <li><code>{'{{date}}'}</code> - Exam date (e.g., Friday, October 10, 2025)</li>
              <li><code>{'{{time}}'}</code> - Exam time slot (e.g., 1:30 PM - 1:37 PM)</li>
              <li><code>{'{{location}}'}</code> - Exam location/room</li>
              <li><code>{'{{week}}'}</code> - Week number</li>
              <li><code>{'{{course}}'}</code> - Course name</li>
              <li><code>{'{{term}}'}</code> - Term (e.g., Fall 2025)</li>
              <li><code>{'{{facilitator}}'}</code> - TA/facilitator name</li>
              <li><code>{'{{ta_page_url}}'}</code> - URL to TA page</li>
              <li><code>{'{{grade_form_url}}'}</code> - URL to grade form</li>
              <li><code>{'{{student_count}}'}</code> - Number of students (for TA messages)</li>
            </ul>
          </div>

          {/* Template Variable Configuration */}
          <div>
            <h4 style={{ color: 'var(--primary)', marginTop: 0, marginBottom: '1rem' }}>Template Variables</h4>
            <p style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginBottom: '1rem' }}>
              Configure the values for template variables used in Slack messages
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <label htmlFor="slack_exam_location" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
                  Exam Location <code style={{ fontWeight: 'normal', color: 'var(--text-light)' }}>{'{{location}}'}</code>
                </label>
                <input
                  id="slack_exam_location"
                  type="text"
                  className="form-input"
                  value={config.slack_exam_location}
                  onChange={(e) => handleChange('slack_exam_location', e.target.value)}
                  placeholder="e.g., Jordan Hall 420"
                  style={{ width: '100%' }}
                />
              </div>

              <div>
                <label htmlFor="slack_course_name" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
                  Course Name <code style={{ fontWeight: 'normal', color: 'var(--text-light)' }}>{'{{course}}'}</code>
                </label>
                <input
                  id="slack_course_name"
                  type="text"
                  className="form-input"
                  value={config.slack_course_name}
                  onChange={(e) => handleChange('slack_course_name', e.target.value)}
                  placeholder="e.g., PSYCH 10 / STATS 60"
                  style={{ width: '100%' }}
                />
              </div>

              <div>
                <label htmlFor="slack_term" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '600' }}>
                  Term <code style={{ fontWeight: 'normal', color: 'var(--text-light)' }}>{'{{term}}'}</code>
                </label>
                <input
                  id="slack_term"
                  type="text"
                  className="form-input"
                  value={config.slack_term}
                  onChange={(e) => handleChange('slack_term', e.target.value)}
                  placeholder="e.g., Fall 2025"
                  style={{ width: '100%' }}
                />
              </div>
            </div>
          </div>

          {/* Channel Name Template */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
              <label htmlFor="slack_channel_name_template" style={{ fontWeight: '600' }}>
                Channel Name Template
              </label>
              <button
                type="button"
                onClick={() => sendTestMessage('channel_name')}
                disabled={sendingTest === 'channel_name'}
                className="btn btn-outline"
                style={{ fontSize: '0.75rem', padding: '0.25rem 0.75rem' }}
              >
                {sendingTest === 'channel_name' ? 'Sending...' : '🧪 Test'}
              </button>
            </div>
            <input
              id="slack_channel_name_template"
              type="text"
              className="form-input"
              value={config.slack_channel_name_template}
              onChange={(e) => handleChange('slack_channel_name_template', e.target.value)}
              placeholder="{{course}}-oral-exam-session-ta-{{ta_name}}-week{{week}}-{{term}}"
              style={{ width: '100%', fontFamily: 'monospace' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block' }}>
              Template for Slack channel names (lowercase, no spaces, hyphens only)
            </small>
          </div>

          {/* Student Message Template */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
              <label htmlFor="slack_student_message_template" style={{ fontWeight: '600' }}>
                Student Notification Message
              </label>
              <button
                type="button"
                onClick={() => sendTestMessage('student')}
                disabled={sendingTest === 'student'}
                className="btn btn-outline"
                style={{ fontSize: '0.75rem', padding: '0.25rem 0.75rem' }}
              >
                {sendingTest === 'student' ? 'Sending...' : '🧪 Test'}
              </button>
            </div>
            <textarea
              id="slack_student_message_template"
              className="form-input"
              value={config.slack_student_message_template}
              onChange={(e) => handleChange('slack_student_message_template', e.target.value)}
              placeholder={'📝 TEST: Oral Exam Session for {{student_name}}\n\nDate: {{date}}\nTime: {{time}}\nLocation: {{location}}\nFacilitator: {{ta_name}}\n\n📋 Course: {{course}} | 🎓 Term: {{term}}'}
              rows="10"
              style={{ width: '100%', fontFamily: 'monospace', fontSize: '0.875rem' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block' }}>
              Message template sent to individual students about their exam session
            </small>
          </div>

          {/* TA Message Template */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
              <label htmlFor="slack_ta_message_template" style={{ fontWeight: '600' }}>
                TA/Admin Schedule Message
              </label>
              <button
                type="button"
                onClick={() => sendTestMessage('ta')}
                disabled={sendingTest === 'ta'}
                className="btn btn-outline"
                style={{ fontSize: '0.75rem', padding: '0.25rem 0.75rem' }}
              >
                {sendingTest === 'ta' ? 'Sending...' : '🧪 Test'}
              </button>
            </div>
            <textarea
              id="slack_ta_message_template"
              className="form-input"
              value={config.slack_ta_message_template}
              onChange={(e) => handleChange('slack_ta_message_template', e.target.value)}
              placeholder={'📋 *Oral Exam Schedule*\n\n*Date:* {{date}}\n*Location:* {{location}}\n*Week:* {{week}}\n\n*Today\'s Schedule ({{student_count}} students):*\n\n{{schedule_list}}\n\n🌐 Go to TA Page\n📝 Grade Form\n\n📚 Course: {{course}} | 🎓 Week {{week}} | 👥 {{student_count}} students'}
              rows="12"
              style={{ width: '100%', fontFamily: 'monospace', fontSize: '0.875rem' }}
            />
            <small style={{ color: 'var(--text-light)', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block' }}>
              Message template sent to TAs/admins with full schedule. Use <code style={{ background: 'var(--background)', padding: '0.125rem 0.25rem', borderRadius: '3px' }}>{'{{schedule_list}}'}</code> for student list with times.
            </small>
          </div>

          {/* Save Button */}
          <div>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={saving}
            >
              {saving ? 'Saving...' : 'Save Configuration'}
            </button>
          </div>
        </div>
        )}
      </form>
    </div>
  );
}
