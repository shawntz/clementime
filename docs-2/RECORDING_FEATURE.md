# Audio Recording Feature Documentation

## Overview
The audio recording feature allows TAs to record their sessions directly from the Clementime dashboard. Recordings are automatically saved to Google Drive for secure cloud storage.

## Features
- Browser-based audio recording (no additional software required)
- Automatic upload to Google Drive
- Real-time audio level monitoring
- Pause/resume functionality
- Session metadata tracking (student, TA, date, week number)
- Recording management (view, delete)

## Setup

### 1. Environment Variables
Ensure these environment variables are set:

```bash
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_DRIVE_FOLDER_ID=optional_parent_folder_id  # Optional: specific folder for recordings
```

### 2. Google API Configuration
1. Enable Google Drive API in your Google Cloud Console
2. Add the following OAuth scopes:
   - `https://www.googleapis.com/auth/drive.file`
   - `https://www.googleapis.com/auth/drive.metadata.readonly`

### 3. Browser Requirements
The recording feature requires a modern browser with MediaRecorder API support:
- Chrome/Edge 49+
- Firefox 25+
- Safari 14.1+

## Usage

### Starting a Recording
1. Navigate to the Recording page from the dashboard (🎙️ Recording)
2. Select the session you want to record from the dropdown
3. Click "Start Recording"
4. Grant microphone permissions when prompted

### During Recording
- Monitor audio levels in real-time via the level indicator
- Use Pause/Resume buttons as needed
- Recording timer shows elapsed time

### Stopping and Saving
1. Click "Stop Recording"
2. Recording automatically uploads to Google Drive
3. A folder called "Clementime_Recordings" is created in your Drive
4. Files are named with format: `recording_YYYYMMDD_HHMM_StudentName_weekN_sectionID.webm`

### Managing Recordings
- View all recordings in the "Recent Recordings" section
- Click "View" to open in Google Drive
- Click "Delete" to remove recordings
- Recordings include metadata:
  - Student name and email
  - TA name
  - Session date and time
  - Week number
  - Section ID

## Technical Details

### Audio Format
- Primary format: WebM with Opus codec (high quality, small file size)
- Fallback formats: WebM, Ogg/Opus, MP4
- Bitrate: 128kbps (configurable)

### Audio Processing
- Echo cancellation: Enabled
- Noise suppression: Enabled
- Automatic gain control: Enabled

### Security
- Recordings require Google authentication
- Files are stored in the user's Google Drive
- Access permissions set based on email domain

## Troubleshooting

### "Browser Not Supported" Error
- Update to a modern browser version
- Check that you're using HTTPS (required for MediaRecorder API)

### "Google Drive service not configured" Error
- Verify environment variables are set
- Check Google Cloud Console API credentials

### No Audio or Low Audio Levels
- Check microphone permissions in browser settings
- Ensure correct microphone is selected in system settings
- Test microphone in other applications

### Upload Failures
- Check internet connection
- Verify Google Drive storage quota
- Re-authenticate with Google if needed

## API Endpoints

- `GET /recording` - Recording page UI
- `POST /api/recording/upload` - Upload recorded audio
- `GET /api/recording/list` - List all recordings
- `GET /api/recording/:fileId` - Get specific recording
- `DELETE /api/recording/:fileId` - Delete recording
- `GET /api/recording/auth/url` - Get Google OAuth URL
- `POST /api/recording/auth/callback` - Handle OAuth callback

## File Structure

```
src/
├── services/
│   └── drive-upload.ts         # Google Drive upload service
├── web/
│   ├── views/
│   │   └── recording.ejs       # Recording UI
│   └── public/
│       └── js/
│           └── audio-recorder.js # Client-side recording logic
└── server.ts                    # Recording API endpoints
```