import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function SlackMatching() {
  const [file, setFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const [uploadResult, setUploadResult] = useState(null);
  const [unmatched, setUnmatched] = useState([]);
  const [slackUsers, setSlackUsers] = useState([]);
  const [error, setError] = useState(null);
  const [showHelpModal, setShowHelpModal] = useState(false);
  const [lastUpload, setLastUpload] = useState(null);

  useEffect(() => {
    loadUnmatched();
    // Load last upload info from localStorage
    const saved = localStorage.getItem('slack_last_upload');
    if (saved) {
      setLastUpload(JSON.parse(saved));
    }
  }, []);

  const loadUnmatched = async () => {
    try {
      const response = await api.get('/admin/slack/unmatched');
      setUnmatched(response.data.unmatched_students);
      setSlackUsers(response.data.slack_users);
    } catch (err) {
      console.error('Failed to load unmatched students', err);
    }
  };

  const handleUpload = async (e) => {
    e.preventDefault();
    if (!file) return;

    setLoading(true);
    setError(null);
    setUploadResult(null);

    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await api.post('/admin/slack/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      setUploadResult(response.data);

      // Save upload info
      const uploadInfo = {
        filename: file.name,
        uploadDate: new Date().toISOString(),
        matchedCount: response.data.matched_count,
        fileData: await file.text(), // Store CSV content
      };
      localStorage.setItem('slack_last_upload', JSON.stringify(uploadInfo));
      setLastUpload(uploadInfo);
      setFile(null);
      loadUnmatched();
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Upload failed');
    } finally {
      setLoading(false);
    }
  };

  const handleMatch = async (studentId, slackUserId) => {
    try {
      await api.put(`/admin/slack/match/${studentId}`, { slack_user_id: slackUserId });
      loadUnmatched();
    } catch (err) {
      alert('Failed to match student');
    }
  };

  const handleDownload = () => {
    if (!lastUpload) return;

    const blob = new Blob([lastUpload.fileData], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = lastUpload.filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      {/* Last Upload Preview */}
      {lastUpload && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <h4 className="text-sm font-semibold text-blue-900 mb-2">Last Uploaded File</h4>
              <div className="space-y-1 text-sm text-blue-800">
                <div className="flex items-center gap-2">
                  <span className="font-medium">📄</span>
                  <span>{lastUpload.filename}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="font-medium">📅</span>
                  <span>{new Date(lastUpload.uploadDate).toLocaleString()}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="font-medium">✓</span>
                  <span>{lastUpload.matchedCount} students matched</span>
                </div>
              </div>
            </div>
            <button
              onClick={handleDownload}
              className="ml-4 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors flex items-center gap-2 text-sm font-medium"
            >
              <span>⬇</span>
              Download
            </button>
          </div>
        </div>
      )}

      {/* Upload Form */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-2xl font-extrabold text-orange-600 flex items-center gap-2">
            <span>💬</span>
            Upload Slack Roster
          </h3>
          <button
            onClick={() => setShowHelpModal(true)}
            className="px-4 py-2 bg-purple-100 hover:bg-purple-200 text-purple-700 rounded-lg transition-colors flex items-center gap-2 text-sm font-medium"
          >
            <span>❓</span>
            How to Export
          </button>
        </div>

        <form onSubmit={handleUpload}>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Select Slack Members CSV File
            </label>
            <div className="relative">
              <input
                type="file"
                accept=".csv"
                onChange={(e) => setFile(e.target.files[0])}
                className="hidden"
                id="slack-file-input"
                disabled={loading}
              />
              <label
                htmlFor="slack-file-input"
                className="flex items-center justify-center w-full px-6 py-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-purple-500 transition-colors cursor-pointer bg-gray-50 hover:bg-purple-50"
              >
                <div className="text-center">
                  <svg
                    className="mx-auto h-12 w-12 text-gray-400"
                    stroke="currentColor"
                    fill="none"
                    viewBox="0 0 48 48"
                    aria-hidden="true"
                  >
                    <path
                      d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                  <p className="mt-2 text-sm text-gray-600">
                    <span className="font-semibold text-purple-600">Click to upload</span> or drag
                    and drop
                  </p>
                  <p className="text-xs text-gray-500">Slack member list CSV</p>
                </div>
              </label>
            </div>
            {file && (
              <div className="mt-3 flex items-center gap-2 p-3 bg-green-50 border border-green-200 rounded-lg">
                <svg
                  className="h-5 w-5 text-green-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span className="text-sm text-green-800 font-medium">{file.name}</span>
              </div>
            )}
          </div>

          <button
            type="submit"
            className="w-full bg-purple-600 hover:bg-purple-700 text-white font-semibold py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={!file || loading}
          >
            {loading ? 'Uploading...' : 'Upload & Match'}
          </button>
        </form>

        {uploadResult && (
          <div className="mt-4 bg-green-50 border border-green-200 rounded-lg p-4">
            <div className="text-green-800">
              <strong className="flex items-center gap-2">
                <span>✅</span>
                {uploadResult.message}
              </strong>
              <p className="mt-1">Matched {uploadResult.matched_count} students automatically</p>
            </div>
          </div>
        )}

        {error && (
          <div className="mt-4 bg-red-50 border border-red-200 rounded-lg p-4">
            <div className="text-red-800">
              <strong className="flex items-center gap-2">
                <span>❌</span>
                Error:
              </strong>
              <p className="mt-1">{error}</p>
            </div>
          </div>
        )}
      </div>

      {/* Unmatched Students */}
      {unmatched.length > 0 && (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h3 className="text-2xl font-extrabold text-orange-600 mb-4">
            Unmatched Students ({unmatched.length})
          </h3>
          <p className="mb-4 text-gray-600">These students need manual Slack matching:</p>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Student Name
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Email
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Section
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Match with Slack User
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {unmatched.map((student) => (
                  <tr key={student.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {student.full_name}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {student.email}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full bg-orange-100 text-orange-800">
                        {student.section}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <select
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                        onChange={(e) => e.target.value && handleMatch(student.id, e.target.value)}
                        defaultValue=""
                      >
                        <option value="">Select Slack user...</option>
                        {slackUsers.map((su) => (
                          <option key={su.value} value={su.value}>
                            {su.label}
                          </option>
                        ))}
                      </select>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Success Message */}
      {unmatched.length === 0 && uploadResult && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4">
          <div className="text-green-800 flex items-center gap-2">
            <span className="text-2xl">🎉</span>
            <span className="font-semibold">All students are matched with Slack users!</span>
          </div>
        </div>
      )}

      {/* Help Modal */}
      {showHelpModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl w-full max-w-3xl max-h-[90vh] overflow-y-auto">
            <div className="p-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-2xl font-bold text-gray-800">
                  How to Export Slack Member List
                </h3>
                <button
                  onClick={() => setShowHelpModal(false)}
                  className="text-gray-400 hover:text-gray-600 text-2xl"
                >
                  ×
                </button>
              </div>

              <div className="space-y-4">
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <h4 className="font-semibold text-blue-900 mb-2">
                    Step 1: Navigate to Slack Admin
                  </h4>
                  <p className="text-blue-800 text-sm">
                    Go to your Slack workspace admin panel at{' '}
                    <code className="bg-blue-100 px-2 py-1 rounded">su-212489.slack.com/admin</code>{' '}
                    (or your workspace URL)
                  </p>
                </div>

                <div className="bg-purple-50 border border-purple-200 rounded-lg p-4">
                  <h4 className="font-semibold text-purple-900 mb-2">
                    Step 2: Go to "Manage members"
                  </h4>
                  <p className="text-purple-800 text-sm mb-3">
                    Click on "Manage members" in the admin sidebar, then click "Export full member
                    list"
                  </p>
                  <img
                    src="/images/slack-export-screenshot.png"
                    alt="Slack Admin Panel showing Manage members and Export full member list button"
                    className="rounded-lg border border-gray-300 w-full shadow-md"
                    onError={(e) => {
                      e.target.src =
                        "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='800' height='400' viewBox='0 0 800 400'%3E%3Crect fill='%23f3f4f6' width='800' height='400'/%3E%3Ctext x='400' y='200' font-family='Arial' font-size='16' fill='%236b7280' text-anchor='middle'%3EScreenshot: Slack Admin Panel%3C/text%3E%3Ctext x='400' y='230' font-family='Arial' font-size='14' fill='%239ca3af' text-anchor='middle'%3E(Place slack-export-screenshot.png in public/images/)%3C/text%3E%3C/svg%3E";
                    }}
                  />
                  <p className="text-xs text-purple-600 mt-2">
                    Screenshot showing the "Manage members" section with "Export full member list"
                    button
                  </p>
                </div>

                <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                  <h4 className="font-semibold text-green-900 mb-2">
                    Step 3: Upload to Clementime
                  </h4>
                  <p className="text-green-800 text-sm">
                    The exported CSV file will contain all workspace members with their Full name,
                    Display name, and Email address. Upload it here and Clementime will
                    automatically match students by email address.
                  </p>
                </div>

                <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                  <h4 className="font-semibold text-yellow-900 mb-2 flex items-center gap-2">
                    <span>💡</span>
                    Pro Tip
                  </h4>
                  <p className="text-yellow-800 text-sm">
                    Make sure students are using their Stanford email addresses in Slack for
                    automatic matching to work correctly.
                  </p>
                </div>
              </div>

              <div className="mt-6 flex justify-end">
                <button
                  onClick={() => setShowHelpModal(false)}
                  className="px-6 py-3 bg-orange-600 hover:bg-orange-700 text-white font-semibold rounded-lg transition-colors"
                >
                  Got it!
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
