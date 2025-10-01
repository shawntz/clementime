import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function CanvasUpload() {
  const [file, setFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [lastUpload, setLastUpload] = useState(null);

  useEffect(() => {
    // Load last upload info from localStorage
    const saved = localStorage.getItem('canvas_last_upload');
    if (saved) {
      setLastUpload(JSON.parse(saved));
    }
  }, []);

  const handleUpload = async (e) => {
    e.preventDefault();
    if (!file) return;

    setLoading(true);
    setError(null);
    setResult(null);

    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await api.post('/admin/canvas/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      setResult(response.data);

      // Save upload info
      const uploadInfo = {
        filename: file.name,
        uploadDate: new Date().toISOString(),
        studentsCount: response.data.success_count,
        sections: response.data.sections_created,
        fileData: await file.text() // Store CSV content
      };
      localStorage.setItem('canvas_last_upload', JSON.stringify(uploadInfo));
      setLastUpload(uploadInfo);
      setFile(null);
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Upload failed');
    } finally {
      setLoading(false);
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
                  <span className="font-medium">👥</span>
                  <span>{lastUpload.studentsCount} students</span>
                </div>
                {lastUpload.sections?.length > 0 && (
                  <div className="flex items-center gap-2">
                    <span className="font-medium">📋</span>
                    <span>Sections: {lastUpload.sections.join(', ')}</span>
                  </div>
                )}
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
        <h3 className="text-2xl font-extrabold text-orange-600 mb-4 flex items-center gap-2">
          <span>📤</span>
          Upload Canvas Roster
        </h3>

        <form onSubmit={handleUpload}>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Select Canvas CSV File
            </label>
            <div className="relative">
              <input
                type="file"
                accept=".csv"
                onChange={(e) => setFile(e.target.files[0])}
                className="hidden"
                id="canvas-file-input"
                disabled={loading}
              />
              <label
                htmlFor="canvas-file-input"
                className="flex items-center justify-center w-full px-6 py-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-orange-500 transition-colors cursor-pointer bg-gray-50 hover:bg-orange-50"
              >
                <div className="text-center">
                  <svg className="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48" aria-hidden="true">
                    <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                  <p className="mt-2 text-sm text-gray-600">
                    <span className="font-semibold text-orange-600">Click to upload</span> or drag and drop
                  </p>
                  <p className="text-xs text-gray-500">CSV files only</p>
                </div>
              </label>
            </div>
            {file && (
              <div className="mt-3 flex items-center gap-2 p-3 bg-green-50 border border-green-200 rounded-lg">
                <svg className="h-5 w-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span className="text-sm text-green-800 font-medium">{file.name}</span>
              </div>
            )}
          </div>

          <button
            type="submit"
            className="w-full bg-orange-500 hover:bg-orange-600 text-white font-semibold py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={!file || loading}
          >
            {loading ? 'Uploading...' : 'Upload Roster'}
          </button>
        </form>

        {result && (
          <div className="mt-4 bg-green-50 border border-green-200 rounded-lg p-4">
            <div className="text-green-800">
              <strong className="flex items-center gap-2">
                <span>✅</span>
                {result.message}
              </strong>
              <p className="mt-1">Imported {result.success_count} students</p>
              {result.sections_created?.length > 0 && (
                <p className="mt-1">Created sections: {result.sections_created.join(', ')}</p>
              )}
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
    </div>
  );
}
