module Api
  module Ta
    class ConfigController < Api::BaseController
      before_action :authenticate_user!

      def index
        # Only return public config values that TAs need
        # Check if R2 is configured
        r2_configured = [
          SystemConfig.get("cloudflare_r2_account_id"),
          SystemConfig.get("cloudflare_r2_access_key_id"),
          SystemConfig.get("cloudflare_r2_secret_access_key"),
          SystemConfig.get("cloudflare_r2_bucket_name"),
          SystemConfig.get("cloudflare_r2_public_url")
        ].all?(&:present?)

        config_hash = {
          exam_day: SystemConfig.get(SystemConfig::EXAM_DAY, "friday"),
          exam_start_time: SystemConfig.get(SystemConfig::EXAM_START_TIME, "13:30"),
          exam_end_time: SystemConfig.get(SystemConfig::EXAM_END_TIME, "14:50"),
          exam_duration_minutes: SystemConfig.get(SystemConfig::EXAM_DURATION_MINUTES, 7),
          exam_buffer_minutes: SystemConfig.get(SystemConfig::EXAM_BUFFER_MINUTES, 1),
          quarter_start_date: SystemConfig.get(SystemConfig::QUARTER_START_DATE, Date.today.to_s),
          total_exams: SystemConfig.get(SystemConfig::TOTAL_EXAMS, 5),
          navbar_title: SystemConfig.get("navbar_title", ""),
          exam_dates: SystemConfig.get("exam_dates", {}),
          cloudflare_r2_configured: r2_configured
        }

        render json: config_hash, status: :ok
      end
    end
  end
end
