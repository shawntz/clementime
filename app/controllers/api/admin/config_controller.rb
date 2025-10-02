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
          grade_form_urls: SystemConfig.get("grade_form_urls", {}),
          exam_dates: SystemConfig.get("exam_dates", {})
        }

        render json: config_hash, status: :ok
      end

      def update
        config_params = params[:config] || {}
        errors = []

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
            when "google_service_account_json"
              SystemConfig.set("google_service_account_json", value, config_type: "string")
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
            when "grade_form_urls"
              SystemConfig.set("grade_form_urls", value, config_type: "json")
            when "exam_dates"
              SystemConfig.set("exam_dates", value, config_type: "json")
            end
          rescue => e
            errors << "#{key}: #{e.message}"
          end
        end

        if errors.empty?
          render json: { message: "Configuration updated successfully" }, status: :ok
        else
          render json: { errors: errors }, status: :unprocessable_entity
        end
      end
    end
  end
end
