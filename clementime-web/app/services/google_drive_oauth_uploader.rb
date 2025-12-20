require "google/apis/drive_v3"
require "rest-client"

class GoogleDriveOauthUploader
  attr_reader :errors

  def initialize
    @errors = []
    @drive_service = nil
    setup_service
  end

  def upload_recording(file_path, recording)
    return false unless @drive_service

    begin
      root_folder_id = SystemConfig.get(SystemConfig::GOOGLE_DRIVE_FOLDER_ID)&.strip
      unless root_folder_id.present?
        @errors << "Google Drive folder ID not configured"
        return false
      end

      # Validate folder ID format
      unless root_folder_id.match?(/^[a-zA-Z0-9_-]+$/)
        @errors << "Invalid Google Drive folder ID format. Please check the folder ID and try again."
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
    rescue Google::Apis::ClientError => e
      if e.message.include?("File not found") || e.message.include?("notFound")
        @errors << "Google Drive folder not found. Please verify the folder ID is correct."
      elsif e.message.include?("Invalid") || e.message.include?("Bad Request")
        @errors << "Invalid Google Drive folder ID format. Please check your configuration."
      else
        @errors << "Google Drive error: #{e.message}"
      end
      Rails.logger.error("Google Drive upload error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
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

  private

  def setup_service
    begin
      # Check if OAuth is authorized
      unless SystemConfig.get("google_oauth_authorized", false)
        @errors << "Google Drive not authorized. Please authorize access in System Preferences."
        return
      end

      # Get access token (refresh if needed)
      access_token = get_valid_access_token
      unless access_token
        @errors << "Failed to get valid access token"
        return
      end

      # Create Drive service with OAuth token
      @drive_service = Google::Apis::DriveV3::DriveService.new
      @drive_service.authorization = access_token

      # Test connection
      @drive_service.get_file("root", fields: "id")

    rescue Google::Apis::AuthorizationError => e
      @errors << "Authorization failed: #{e.message}. Please re-authorize Google Drive access."
      Rails.logger.error("Google Drive auth error: #{e.message}")
      @drive_service = nil
    rescue => e
      @errors << "Failed to initialize Google Drive service: #{e.message}"
      Rails.logger.error("Google Drive setup error: #{e.class}: #{e.message}")
      @drive_service = nil
    end
  end

  def get_valid_access_token
    access_token = SystemConfig.get("google_oauth_access_token")
    expires_at = SystemConfig.get("google_oauth_expires_at")

    # Check if token is expired or will expire soon
    if expires_at.blank? || Time.parse(expires_at) < 5.minutes.from_now
      # Refresh the token
      access_token = refresh_access_token
    end

    access_token
  end

  def refresh_access_token
    refresh_token = SystemConfig.get("google_oauth_refresh_token")
    client_id = SystemConfig.get("google_oauth_client_id")
    client_secret = SystemConfig.get("google_oauth_client_secret")

    unless refresh_token.present?
      @errors << "No refresh token available. Please re-authorize Google Drive access."
      return nil
    end

    begin
      response = RestClient.post(
        "https://oauth2.googleapis.com/token",
        {
          refresh_token: refresh_token,
          client_id: client_id,
          client_secret: client_secret,
          grant_type: "refresh_token"
        }
      )

      tokens = JSON.parse(response.body)

      # Update stored tokens
      SystemConfig.set("google_oauth_access_token", tokens["access_token"], config_type: "string")
      SystemConfig.set("google_oauth_expires_at", (Time.current + tokens["expires_in"].to_i.seconds).to_s, config_type: "string")

      tokens["access_token"]
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error("Failed to refresh Google OAuth token: #{e.response}")
      @errors << "Failed to refresh access token. Please re-authorize Google Drive access."
      nil
    rescue => e
      Rails.logger.error("Failed to refresh Google OAuth token: #{e.message}")
      @errors << "Failed to refresh access token: #{e.message}"
      nil
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
