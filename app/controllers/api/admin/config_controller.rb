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
          google_drive_folder_id: SystemConfig.get(SystemConfig::GOOGLE_DRIVE_FOLDER_ID, ""),
          google_service_account_json: SystemConfig.get("google_service_account_json", ""),
          slack_bot_token: SystemConfig.get(SystemConfig::SLACK_BOT_TOKEN, ""),
          slack_app_token: SystemConfig.get(SystemConfig::SLACK_APP_TOKEN, ""),
          slack_signing_secret: SystemConfig.get(SystemConfig::SLACK_SIGNING_SECRET, ""),
          slack_channel_name_template: SystemConfig.get("slack_channel_name_template", ""),
          slack_student_message_template: SystemConfig.get("slack_student_message_template", ""),
          slack_ta_message_template: SystemConfig.get("slack_ta_message_template", ""),
          slack_test_mode: SystemConfig.get("slack_test_mode", false),
          slack_test_user_id: SystemConfig.get("slack_test_user_id", ""),
          admin_slack_ids: SystemConfig.get("admin_slack_ids", ""),
          slack_exam_location: SystemConfig.get("slack_exam_location", ""),
          slack_course_name: SystemConfig.get("slack_course_name", ""),
          slack_term: SystemConfig.get("slack_term", ""),
          grade_form_urls: SystemConfig.get("grade_form_urls", {}),
          exam_dates: SystemConfig.get("exam_dates", {})
        }

        render json: config_hash, status: :ok
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
            when "google_drive_folder_id"
              SystemConfig.set(SystemConfig::GOOGLE_DRIVE_FOLDER_ID, value, config_type: "string")
              google_drive_updated = true
            when "google_service_account_json"
              SystemConfig.set("google_service_account_json", value, config_type: "string")
              google_drive_updated = true
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
            folder_id = SystemConfig.get(SystemConfig::GOOGLE_DRIVE_FOLDER_ID)
            if folder_id.present?
              # Attempt to get folder metadata to verify access
              uploader.instance_variable_get(:@drive_service).get_file(folder_id, fields: "id, name")
              {
                valid: true,
                message: "✅ Google Drive credentials verified successfully",
                details: "Successfully authenticated and can access the configured folder"
              }
            else
              {
                valid: true,
                message: "✅ Google Drive credentials verified",
                details: "Authenticated successfully. Set folder ID to complete setup."
              }
            end
          rescue => e
            {
              valid: false,
              message: "❌ Google Drive credentials valid but folder access failed",
              error: e.message,
              details: "Credentials are valid but cannot access the specified folder. Check folder ID and permissions."
            }
          end
        end
      end
    end
  end
end
