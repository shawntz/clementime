module Api
  module Admin
    class ConfigController < Api::BaseController
      before_action :authorize_admin!

      def index
        config_hash = {
          exam_day: SystemConfig.get(SystemConfig::EXAM_DAY, "friday"),
          exam_start_time: SystemConfig.get(SystemConfig::EXAM_START_TIME, "13:30"),
          exam_end_time: SystemConfig.get(SystemConfig::EXAM_END_TIME, "14:50"),
          exam_duration_minutes: SystemConfig.get(SystemConfig::EXAM_DURATION_MINUTES, 7),
          exam_buffer_minutes: SystemConfig.get(SystemConfig::EXAM_BUFFER_MINUTES, 1),
          quarter_start_date: SystemConfig.get(SystemConfig::QUARTER_START_DATE, Date.today.to_s),
          total_exams: SystemConfig.get(SystemConfig::TOTAL_EXAMS, 5),
          navbar_title: SystemConfig.get("navbar_title", ""),
          base_url: SystemConfig.get("base_url", ""),
          cloudflare_r2_account_id: SystemConfig.get("cloudflare_r2_account_id", ""),
          cloudflare_r2_access_key_id: SystemConfig.get("cloudflare_r2_access_key_id", ""),
          cloudflare_r2_secret_access_key: SystemConfig.get("cloudflare_r2_secret_access_key", ""),
          cloudflare_r2_bucket_name: SystemConfig.get("cloudflare_r2_bucket_name", ""),
          cloudflare_r2_public_url: SystemConfig.get("cloudflare_r2_public_url", ""),
          slack_bot_token: SystemConfig.get(SystemConfig::SLACK_BOT_TOKEN, ""),
          slack_app_token: SystemConfig.get(SystemConfig::SLACK_APP_TOKEN, ""),
          slack_signing_secret: SystemConfig.get(SystemConfig::SLACK_SIGNING_SECRET, ""),
          slack_channel_name_template: SystemConfig.get("slack_channel_name_template", "{{course}}-oralexam-{{ta_name}}-week{{week}}-{{term}}"),
          slack_student_message_template: SystemConfig.get("slack_student_message_template", "📝 Oral Exam Session for {{student_name}}\n\n📊 Exam Number: {{exam_number}}\n📅 Date: {{date}}\n⏰ Time: {{time}}\n📍 Location: {{location}}\n👤 Facilitator: {{ta_name}}\n\n📋 Course: {{course}} | 🎓 Term: {{term}}"),
          slack_ta_message_template: SystemConfig.get("slack_ta_message_template", "📋 *Oral Exam Schedule*\n\n*Date:* {{date}}\n*Location:* {{location}}\n*Week:* {{week}}\n\n*Today's Schedule ({{student_count}} students):*\n\n{{schedule_list}}\n\n🌐 Go to TA Page\n📝 Grade Form\n\n📚 Course: {{course}} | 🎓 Week {{week}} | 👥 {{student_count}} students"),
          slack_test_mode: SystemConfig.get("slack_test_mode", false),
          slack_test_user_id: SystemConfig.get("slack_test_user_id", ""),
          admin_slack_ids: SystemConfig.get("admin_slack_ids", ""),
          super_admin_slack_id: SystemConfig.get("super_admin_slack_id", ""),
          super_admin_email: SystemConfig.get("super_admin_email", ""),
          slack_exam_location: SystemConfig.get("slack_exam_location", ""),
          slack_course_name: SystemConfig.get("slack_course_name", ""),
          slack_term: SystemConfig.get("slack_term", ""),
          grade_form_urls: SystemConfig.get("grade_form_urls", {}),
          exam_dates: SystemConfig.get("exam_dates", {})
        }

        render json: config_hash, status: :ok
      end

      def test_google_drive
        uploader = GoogleDriveUploader.new

        if uploader.errors.any?
          return render json: {
            success: false,
            error: uploader.errors.join(", ")
          }, status: :unprocessable_entity
        end

        begin
          folder_id = SystemConfig.get(SystemConfig::GOOGLE_DRIVE_FOLDER_ID)&.strip

          unless folder_id.present?
            return render json: {
              success: false,
              error: "Google Drive folder ID not configured"
            }, status: :unprocessable_entity
          end

          # Get folder info
          drive_service = uploader.instance_variable_get(:@drive_service)
          folder_info = drive_service.get_file(folder_id, fields: "id, name")

          # List subfolders
          response = drive_service.list_files(
            q: "'#{folder_id}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false",
            fields: "files(id, name)",
            order_by: "name"
          )

          folder_structure = response.files.map(&:name)

          render json: {
            success: true,
            root_folder_id: folder_id,
            root_folder_name: folder_info.name,
            folder_structure: folder_structure
          }, status: :ok
        rescue Google::Apis::ClientError => e
          error_msg = if e.message.include?("File not found") || e.message.include?("notFound")
            "Folder not found. Verify the folder ID is correct and the service account has access."
          elsif e.message.include?("Invalid") || e.message.include?("Bad Request")
            "Invalid folder ID format. Check your configuration."
          else
            e.message
          end

          render json: {
            success: false,
            error: error_msg
          }, status: :unprocessable_entity
        rescue => e
          render json: {
            success: false,
            error: e.message
          }, status: :internal_server_error
        end
      end

      def update
        config_params = params[:config] || {}
        errors = []
        google_drive_updated = false

        config_params.each do |key, value|
          begin
            case key.to_s
            when "exam_day"
              SystemConfig.set(SystemConfig::EXAM_DAY, value, config_type: "string")
            when "exam_start_time"
              SystemConfig.set(SystemConfig::EXAM_START_TIME, value, config_type: "string")
            when "exam_end_time"
              SystemConfig.set(SystemConfig::EXAM_END_TIME, value, config_type: "string")
            when "exam_duration_minutes"
              SystemConfig.set(SystemConfig::EXAM_DURATION_MINUTES, value.to_i, config_type: "integer")
            when "exam_buffer_minutes"
              SystemConfig.set(SystemConfig::EXAM_BUFFER_MINUTES, value.to_i, config_type: "integer")
            when "quarter_start_date"
              SystemConfig.set(SystemConfig::QUARTER_START_DATE, value, config_type: "date")
            when "total_exams"
              SystemConfig.set(SystemConfig::TOTAL_EXAMS, value.to_i, config_type: "integer")
            when "cloudflare_r2_account_id"
              SystemConfig.set("cloudflare_r2_account_id", value, config_type: "string")
            when "cloudflare_r2_access_key_id"
              SystemConfig.set("cloudflare_r2_access_key_id", value, config_type: "string")
            when "cloudflare_r2_secret_access_key"
              SystemConfig.set("cloudflare_r2_secret_access_key", value, config_type: "string")
            when "cloudflare_r2_bucket_name"
              SystemConfig.set("cloudflare_r2_bucket_name", value, config_type: "string")
            when "cloudflare_r2_public_url"
              SystemConfig.set("cloudflare_r2_public_url", value, config_type: "string")
            when "slack_bot_token"
              SystemConfig.set(SystemConfig::SLACK_BOT_TOKEN, value, config_type: "string")
            when "slack_app_token"
              SystemConfig.set(SystemConfig::SLACK_APP_TOKEN, value, config_type: "string")
            when "slack_signing_secret"
              SystemConfig.set(SystemConfig::SLACK_SIGNING_SECRET, value, config_type: "string")
            when "navbar_title"
              SystemConfig.set("navbar_title", value, config_type: "string")
            when "base_url"
              SystemConfig.set("base_url", value, config_type: "string")
            when "slack_channel_name_template"
              SystemConfig.set("slack_channel_name_template", value, config_type: "string")
            when "slack_student_message_template"
              SystemConfig.set("slack_student_message_template", value, config_type: "string")
            when "slack_ta_message_template"
              SystemConfig.set("slack_ta_message_template", value, config_type: "string")
            when "slack_test_mode"
              SystemConfig.set("slack_test_mode", value, config_type: "boolean")
            when "slack_test_user_id"
              SystemConfig.set("slack_test_user_id", value, config_type: "string")
            when "admin_slack_ids"
              SystemConfig.set("admin_slack_ids", value, config_type: "string")
            when "super_admin_slack_id"
              SystemConfig.set("super_admin_slack_id", value, config_type: "string")
            when "super_admin_email"
              SystemConfig.set("super_admin_email", value, config_type: "string")
            when "slack_exam_location"
              SystemConfig.set("slack_exam_location", value, config_type: "text")
            when "slack_course_name"
              SystemConfig.set("slack_course_name", value, config_type: "text")
            when "slack_term"
              SystemConfig.set("slack_term", value, config_type: "text")
            when "grade_form_urls"
              SystemConfig.set("grade_form_urls", value, config_type: "json")
            when "exam_dates"
              SystemConfig.set("exam_dates", value, config_type: "json")
            end
          rescue => e
            errors << "#{key}: #{e.message}"
          end
        end

        # Validate Google Drive credentials if they were updated
        google_drive_status = nil
        if google_drive_updated && errors.empty?
          google_drive_status = validate_google_drive_credentials
        end

        if errors.empty?
          response_data = { message: "Configuration updated successfully" }
          response_data[:google_drive_status] = google_drive_status if google_drive_status
          render json: response_data, status: :ok
        else
          render json: { errors: errors }, status: :unprocessable_entity
        end
      end

      private

      def validate_google_drive_credentials
        uploader = GoogleDriveUploader.new

        if uploader.errors.any?
          {
            valid: false,
            message: "❌ Google Drive validation failed",
            error: uploader.errors.join(", ")
          }
        else
          # Try to access the root folder
          begin
            folder_id = SystemConfig.get(SystemConfig::GOOGLE_DRIVE_FOLDER_ID)&.strip
            if folder_id.present?
              # Attempt to get folder metadata to verify access
              folder_info = uploader.instance_variable_get(:@drive_service).get_file(folder_id, fields: "id, name")
              {
                valid: true,
                message: "✅ Google Drive credentials verified successfully",
                details: "Successfully authenticated and can access folder: #{folder_info.name}",
                folder_id: folder_id
              }
            else
              {
                valid: true,
                message: "✅ Google Drive credentials verified",
                details: "Authenticated successfully. Set folder ID to complete setup."
              }
            end
          rescue => e
            error_details = "Steps to fix:\n1. Verify folder ID is correct (from Google Drive URL)\n2. Share the folder with service account email\n3. Grant 'Editor' permissions\n4. Wait a few minutes for permissions to propagate"

            # Add specific guidance for common errors
            if e.message.include?("File not found") || e.message.include?("notFound")
              error_details = "The folder ID '#{folder_id}' was not found. This usually means:\n1. The folder ID is incorrect or incomplete\n2. The folder was deleted\n3. The service account doesn't have access to it\n\nHow to fix:\n1. Get the folder ID from the Google Drive URL (the long string after /folders/)\n2. Share the folder with the service account email (found in your JSON credentials)\n3. Grant 'Editor' permissions to the service account"
            elsif e.message.include?("Invalid") || e.message.include?("Bad Request")
              error_details = "The folder ID format is invalid. Make sure you're using the full folder ID from the Google Drive URL (the long alphanumeric string after /folders/)"
            end

            {
              valid: false,
              message: "❌ Google Drive credentials valid but folder access failed",
              error: e.message,
              folder_id_attempted: folder_id,
              details: error_details
            }
          end
        end
      end
    end
  end
end
