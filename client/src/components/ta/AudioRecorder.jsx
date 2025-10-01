import { useState, useRef } from 'react';
import api from '../../services/api';

export default function AudioRecorder({ slot, onClose }) {
  const [recording, setRecording] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [recordingId, setRecordingId] = useState(null);
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);

  const startRecording = async () => {
    try {
      // Create recording entry first
      const response = await api.post('/ta/recordings', {
        exam_slot_id: slot.id
      });
      setRecordingId(response.data.recording.id);

      // Start audio recording
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;
      chunksRef.current = [];

      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) {
          chunksRef.current.push(e.data);
        }
      };

      mediaRecorder.start();
      setRecording(true);
    } catch (err) {
      alert('Failed to start recording: ' + err.message);
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && recording) {
      mediaRecorderRef.current.stop();
      mediaRecorderRef.current.stream.getTracks().forEach(track => track.stop());
      setRecording(false);

      mediaRecorderRef.current.onstop = async () => {
        const audioBlob = new Blob(chunksRef.current, { type: 'audio/webm' });
        await uploadRecording(audioBlob);
      };
    }
  };

  const uploadRecording = async (audioBlob) => {
    setUploading(true);

    try {
      // First, download locally as backup
      const url = URL.createObjectURL(audioBlob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `exam-recording-${slot.student.full_name.replace(/[^a-zA-Z0-9]/g, '_')}-exam${slot.exam_number}-${new Date().toISOString()}.webm`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      // Then upload to Google Drive
      const reader = new FileReader();
      reader.readAsDataURL(audioBlob);
      reader.onloadend = async () => {
        const base64Audio = reader.result.split(',')[1];

        try {
          await api.post(`/ta/recordings/${recordingId}/upload`, {
            audio_data: base64Audio
          });

          alert('Recording saved locally and uploaded successfully!');
          onClose();
        } catch (uploadErr) {
          alert('Recording saved locally but upload failed: ' + uploadErr.message + '\nYou can manually upload the downloaded file later.');
          onClose();
        }
      };
    } catch (err) {
      alert('Failed to save recording: ' + err.message);
      setUploading(false);
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
          Record Oral Exam
        </h3>

        <div style={{ marginBottom: '1rem' }}>
          <p><strong>Student:</strong> {slot.student.full_name}</p>
          <p><strong>Exam:</strong> #{slot.exam_number}</p>
          <p><strong>Time:</strong> {slot.formatted_time}</p>
        </div>

        {!recording && !uploading && (
          <div style={{ display: 'flex', gap: '1rem' }}>
            <button onClick={startRecording} className="btn btn-primary">
              🎙️ Start Recording
            </button>
            <button onClick={onClose} className="btn btn-outline">
              Cancel
            </button>
          </div>
        )}

        {recording && (
          <div>
            <div style={{
              padding: '2rem',
              backgroundColor: 'var(--error)',
              color: 'white',
              borderRadius: '0.5rem',
              textAlign: 'center',
              marginBottom: '1rem',
              animation: 'pulse 2s infinite'
            }}>
              <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>🔴</div>
              <div>Recording in progress...</div>
            </div>

            <button onClick={stopRecording} className="btn btn-primary" style={{ width: '100%' }}>
              ⏹️ Stop & Upload
            </button>
          </div>
        )}

        {uploading && (
          <div style={{ textAlign: 'center' }}>
            <div className="spinner" style={{ margin: '0 auto 1rem' }} />
            <p>Uploading to Google Drive...</p>
          </div>
        )}
      </div>
    </div>
  );
}
