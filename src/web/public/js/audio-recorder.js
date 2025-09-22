export class AudioRecorderService {
  constructor(config = {}) {
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.stream = null;
    this.isRecording = false;
    this.recordingStartTime = null;
    this.recordingId = null;

    this.config = {
      mimeType: 'audio/webm;codecs=opus',
      audioBitsPerSecond: 128000,
      ...config
    };

    this.FALLBACK_MIME_TYPES = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4'
    ];
  }

  getSupportedMimeType() {
    const requestedType = this.config.mimeType;
    if (requestedType && MediaRecorder.isTypeSupported(requestedType)) {
      return requestedType;
    }

    for (const type of this.FALLBACK_MIME_TYPES) {
      if (MediaRecorder.isTypeSupported(type)) {
        return type;
      }
    }

    return '';
  }

  async startRecording(callbacks = {}) {
    if (this.isRecording) {
      throw new Error('Recording already in progress');
    }

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      });

      const mimeType = this.getSupportedMimeType();
      if (!mimeType) {
        throw new Error('No supported audio recording format found');
      }

      const options = {
        mimeType,
        audioBitsPerSecond: this.config.audioBitsPerSecond
      };

      this.mediaRecorder = new MediaRecorder(this.stream, options);
      this.audioChunks = [];
      this.recordingStartTime = new Date();
      this.recordingId = `recording_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data);
          callbacks.onDataAvailable?.(event.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        const audioBlob = new Blob(this.audioChunks, { type: mimeType });
        callbacks.onStop?.(audioBlob);
        this.cleanup();
      };

      this.mediaRecorder.onerror = (event) => {
        const error = new Error(`Recording error: ${event.type}`);
        callbacks.onError?.(error);
        this.cleanup();
      };

      this.mediaRecorder.start(1000);
      this.isRecording = true;
      callbacks.onStart?.();

      return this.recordingId;
    } catch (error) {
      this.cleanup();
      throw new Error(`Failed to start recording: ${error.message}`);
    }
  }

  stopRecording() {
    return new Promise((resolve, reject) => {
      if (!this.mediaRecorder || !this.isRecording) {
        reject(new Error('No recording in progress'));
        return;
      }

      const mimeType = this.mediaRecorder.mimeType;

      this.mediaRecorder.onstop = () => {
        const audioBlob = new Blob(this.audioChunks, { type: mimeType });
        this.cleanup();
        resolve(audioBlob);
      };

      this.mediaRecorder.stop();
      this.isRecording = false;
    });
  }

  pauseRecording() {
    if (this.mediaRecorder && this.isRecording && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.pause();
    }
  }

  resumeRecording() {
    if (this.mediaRecorder && this.isRecording && this.mediaRecorder.state === 'paused') {
      this.mediaRecorder.resume();
    }
  }

  getRecordingState() {
    if (!this.mediaRecorder) return 'inactive';
    return this.mediaRecorder.state;
  }

  getRecordingDuration() {
    if (!this.recordingStartTime) return 0;
    return Date.now() - this.recordingStartTime.getTime();
  }

  getRecordingId() {
    return this.recordingId;
  }

  isRecordingActive() {
    return this.isRecording;
  }

  cleanup() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }

    this.mediaRecorder = null;
    this.audioChunks = [];
    this.isRecording = false;
    this.recordingStartTime = null;
  }

  static async checkPermissions() {
    try {
      const result = await navigator.permissions.query({ name: 'microphone' });
      return result.state;
    } catch (error) {
      console.warn('Could not check microphone permissions:', error);
      return 'prompt';
    }
  }

  static isSupported() {
    return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia && MediaRecorder);
  }

  static getSupportedMimeTypes() {
    if (!MediaRecorder.isTypeSupported) return [];

    const types = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4'
    ];

    return types.filter(type => MediaRecorder.isTypeSupported(type));
  }
}