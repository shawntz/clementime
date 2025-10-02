require "google/apis/drive_v3"
require "googleauth"

class GoogleDriveUploader
  attr_reader :errors

  def initialize
    @errors = []
    @drive_service = nil
    setup_service
  end

  def upload_recording(file_path, recording)
    return false unless @drive_service

    begin
      root_folder_id = SystemConfig.get(SystemConfig::GOOGLE_DRIVE_FOLDER_ID)
      unless root_folder_id
        @errors << "Google Drive folder ID not configured"
        return false
      end

      # Create folder structure: Root > Week X - Oral Exam Y > TA Username
      exam_slot = recording.exam_slot
      ta_username = recording.ta.username
      week_folder_name = "Week #{exam_slot.week_number} - Oral Exam #{exam_slot.exam_number}"

      # Get or create week folder
      week_folder_id = find_or_create_folder(week_folder_name, root_folder_id)
      unless week_folder_id
        @errors << "Failed to create week folder"
        return false
      end

      # Get or create TA folder inside week folder
      ta_folder_id = find_or_create_folder(ta_username, week_folder_id)
      unless ta_folder_id
        @errors << "Failed to create TA folder"
        return false
      end

      # Generate filename
      filename = generate_filename(recording)

      # Upload file to TA folder
      file_metadata = {
        name: filename,
        parents: [ ta_folder_id ]
      }

      file = @drive_service.create_file(
        file_metadata,
        fields: "id, name, webViewLink",
        upload_source: file_path,
        content_type: "audio/webm"
      )

      # Update recording
      recording.update!(
        google_drive_file_id: file.id,
        recording_url: file.web_view_link,
        uploaded_at: Time.current
      )

      true
    rescue => e
      @errors << "Upload failed: #{e.message}"
      Rails.logger.error("Google Drive upload error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    end
  end

  def upload_from_data(audio_data, recording)
    return false unless @drive_service

    begin
      # Create temp file
      temp_file = Tempfile.new([ "recording", ".webm" ])
      temp_file.binmode
      temp_file.write(audio_data)
      temp_file.rewind

      result = upload_recording(temp_file.path, recording)

      temp_file.close
      temp_file.unlink

      result
    rescue => e
      @errors << "Upload from data failed: #{e.message}"
      false
    end
  end

  def test_upload(audio_data, user)
    return { success: false, error: "Drive service not initialized" } unless @drive_service

    begin
      root_folder_id = SystemConfig.get(SystemConfig::GOOGLE_DRIVE_FOLDER_ID)
      unless root_folder_id
        return { success: false, error: "Google Drive folder ID not configured" }
      end

      # Create test folder
      test_folder_name = "Test_Recordings"
      test_folder_id = find_or_create_folder(test_folder_name, root_folder_id)
      unless test_folder_id
        return { success: false, error: "Failed to create test folder" }
      end

      # Generate test filename
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      filename = "test_recording_#{user.username}_#{timestamp}.wav"

      # Create temp file
      temp_file = Tempfile.new([ "test_recording", ".wav" ])
      temp_file.binmode
      temp_file.write(audio_data)
      temp_file.rewind

      # Upload to Google Drive
      file_metadata = {
        name: filename,
        parents: [ test_folder_id ]
      }

      file = @drive_service.create_file(
        file_metadata,
        fields: "id, name, webViewLink, size",
        upload_source: temp_file.path,
        content_type: "audio/wav"
      )

      # Download the file back to verify
      downloaded_content = @drive_service.get_file(file.id, download_dest: StringIO.new)

      temp_file.close
      temp_file.unlink

      {
        success: true,
        file_id: file.id,
        file_name: file.name,
        file_url: file.web_view_link,
        file_size: file.size,
        uploaded_size: audio_data.bytesize,
        downloaded_size: downloaded_content.string.bytesize,
        verification: audio_data.bytesize == downloaded_content.string.bytesize ? "✅ Match" : "❌ Size mismatch"
      }
    rescue => e
      { success: false, error: e.message, backtrace: e.backtrace.first(5) }
    end
  end

  private

  def setup_service
    begin
      # Get service account credentials from SystemConfig or environment
      credentials_json = SystemConfig.get("google_service_account_json") || ENV["GOOGLE_SERVICE_ACCOUNT_JSON"]

      unless credentials_json
        @errors << "Google service account JSON not configured"
        return
      end

      # Decode if base64 encoded
      if credentials_json.match?(/^[A-Za-z0-9+\/=]+$/)
        credentials_json = Base64.decode64(credentials_json)
      end

      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(credentials_json),
        scope: Google::Apis::DriveV3::AUTH_DRIVE_FILE
      )

      @drive_service = Google::Apis::DriveV3::DriveService.new
      @drive_service.authorization = credentials

      # Test connection
      @drive_service.get_file("root", fields: "id")

    rescue => e
      @errors << "Failed to initialize Google Drive service: #{e.message}"
      Rails.logger.error("Google Drive setup error: #{e.message}")
      @drive_service = nil
    end
  end

  def find_or_create_folder(folder_name, parent_id)
    # Search for existing folder
    query = "name='#{folder_name}' and '#{parent_id}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"

    response = @drive_service.list_files(
      q: query,
      fields: "files(id, name)",
      spaces: "drive"
    )

    # Return existing folder if found
    return response.files.first.id if response.files.any?

    # Create new folder
    file_metadata = {
      name: folder_name,
      mime_type: "application/vnd.google-apps.folder",
      parents: [ parent_id ]
    }

    folder = @drive_service.create_file(
      file_metadata,
      fields: "id"
    )

    folder.id
  rescue => e
    Rails.logger.error("Error finding/creating folder '#{folder_name}': #{e.message}")
    nil
  end

  def generate_filename(recording)
    student = recording.student
    exam_slot = recording.exam_slot
    timestamp = recording.recorded_at.strftime("%Y%m%d_%H%M%S")

    # Format: Section_StudentName_Exam1_20250101_143000.webm
    "#{recording.section.code}_#{sanitize_filename(student.full_name)}_Exam#{exam_slot.exam_number}_#{timestamp}.webm"
  end

  def sanitize_filename(filename)
    filename.gsub(/[^0-9A-Za-z.\-]/, "_")
  end
end
