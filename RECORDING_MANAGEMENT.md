# Recording Management Guide

## Overview

The recording system now supports full CRUD operations with the following capabilities:

1. **Create new recordings** - Record audio for any exam slot
2. **View recordings** - Play back uploaded recordings directly from R2
3. **Delete recordings** - Remove recordings and re-record if needed
4. **Handle legacy recordings** - Automatically fix old recordings from testing

## Features

### 1. Recording Status Display

Recordings show one of three statuses:

- **✓ Uploaded** (green) - Recording successfully uploaded to R2 with playback URL
- **⏳ Pending Upload** (light green) - Recording created but not yet uploaded
- **Not recorded** (orange) - No recording exists for this slot

### 2. Actions Available

#### For Uploaded Recordings:
- **▶️ Play** - Opens the recording in a new tab from R2
- **🗑️ Delete** - Removes the recording (with confirmation)

#### For Pending Upload Recordings:
- **🗑️ Delete** - Removes the failed/pending recording so you can re-record

#### For Not Recorded Slots:
- **🎙️ Record** - Start a new recording

### 3. Re-recording Workflow

If you need to redo a recording:

1. Click the **🗑️** delete button next to the recording
2. Confirm deletion in the popup
3. The **🎙️ Record** button will appear
4. Record the new audio

**Note**: Deleting only removes the database entry. The old file in R2 will remain but won't be referenced.

## Handling Legacy/Test Recordings

### Problem: Old recordings showing "Pending Upload"

This happens when:
- Recordings were created during testing before R2 was implemented
- Only local files were downloaded, nothing uploaded to cloud
- Database has recording entries but no `recording_url`

### Solution: Delete and Re-record

For any recording showing "Pending Upload" that you want to fix:

1. **If it's an old test recording you don't need:**
   - Click 🗑️ to delete it
   - Record a new one if needed

2. **If it was a real recording with only a local file:**
   - Delete the database entry (🗑️)
   - Re-record the exam
   - The new recording will upload to R2 automatically

### Automatic Fix for R2 Recordings Missing URLs

The migration `20251003061142_fix_existing_recording_uploaded_at.rb` automatically:

1. Sets `uploaded_at` for recordings that have `recording_url`
2. Reconstructs R2 URLs for recordings that uploaded successfully but didn't save the URL

Run this migration on your server:

```bash
bin/rails db:migrate
```

This will fix any recordings that are actually in R2 but showing as "Pending Upload" due to missing `recording_url` in the database.

## Recording Status Logic

The system uses a simple, reliable check:

```ruby
def uploaded?
  recording_url.present?
end
```

**Has `recording_url`?** ✅ Uploaded
**No `recording_url`?** ⏳ Not uploaded

This works for both:
- **Cloudflare R2** recordings (primary method)
- **Legacy Google Drive** recordings (deprecated but still supported)

## File Organization in R2

Recordings are stored with this structure:

```
clementime-oral-exam-recordings/
├── week_1/
│   ├── shawn/
│   │   ├── F25-PSYCH-10-09_Flynn__Grace_Audrey_Exam1_20251003_060241.webm
│   │   └── F25-PSYCH-10-09_Wang__Sophia_Exam1_20251003_053037.webm
├── week_2/
│   ├── shawn/
│   │   └── ...
└── ...
```

Format: `week_{week_number}/{ta_username}/{section_code}_{student_name}_Exam{exam_num}_{timestamp}.webm`

## API Endpoints

### Create Recording
```
POST /api/ta/recordings
Body: { exam_slot_id: 123 }
```

### Upload Audio
```
POST /api/ta/recordings/:id/upload
Body: { audio_data: "base64_encoded_audio" }
```

### Delete Recording
```
DELETE /api/ta/recordings/:id
```

Permissions: Only the TA who created the recording can delete it.

## Security

- **TA Authorization**: TAs can only delete their own recordings
- **Confirmation Required**: Delete action requires user confirmation
- **Access Control**: Only TAs assigned to the section can access/modify recordings
- **Public URLs**: R2 files are publicly accessible via the R2.dev URL (no auth required for playback)

## Troubleshooting

### Recording shows "Pending Upload" but file exists in R2

**Solution**: Run the migration to reconstruct the URL:
```bash
bin/rails db:migrate
```

### Can't record because "Recording already exists"

**Solution**: Delete the existing recording first, then record again

### Delete button not working

**Check**:
1. You are the TA who created the recording
2. You're not trying to delete someone else's recording
3. Browser console for any error messages

### Play button opens blank page

**Check**:
1. R2 Public Access is enabled on your bucket
2. The Public R2.dev URL is correctly configured in System Preferences
3. The file actually exists in R2 (check Cloudflare dashboard)

## Best Practices

1. **Always delete old test recordings** - Keeps the interface clean
2. **Re-record immediately if upload fails** - Don't leave pending uploads
3. **Verify playback** - Click Play after uploading to confirm it works
4. **Local backup** - Recordings auto-download locally as a backup before uploading

## Migration Checklist

When deploying these changes:

- [x] Update `Recording` model to check `recording_url` for status
- [x] Add delete endpoint to recordings controller
- [x] Add delete route in `config/routes.rb`
- [x] Update WeeklySchedule UI to show delete button
- [x] Create migration to fix legacy recordings
- [ ] Run `bin/rails db:migrate` on server
- [ ] Delete any unwanted test recordings from TA dashboard
- [ ] Test re-recording workflow
