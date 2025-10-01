class SystemConfig < ApplicationRecord
  # Validations
  validates :key, presence: true, uniqueness: true
  validates :config_type, inclusion: { in: %w[string integer boolean json time date] }

  # Class methods for easy config access
  class << self
    def get(key, default = nil)
      config = find_by(key: key)
      return default unless config
      parse_value(config.value, config.config_type)
    end

    def set(key, value, config_type: 'string', description: nil)
      config = find_or_initialize_by(key: key)
      config.value = serialize_value(value, config_type)
      config.config_type = config_type
      config.description = description if description
      config.save!
      config
    end

    private

    def parse_value(value, type)
      return nil if value.nil?

      case type
      when 'string'
        value
      when 'integer'
        value.to_i
      when 'boolean'
        value.to_s.downcase == 'true'
      when 'json'
        JSON.parse(value)
      when 'time'
        Time.parse(value)
      when 'date'
        Date.parse(value)
      else
        value
      end
    rescue => e
      Rails.logger.error("Error parsing config value for type #{type}: #{e.message}")
      nil
    end

    def serialize_value(value, type)
      case type
      when 'json'
        value.to_json
      when 'time', 'date'
        value.to_s
      else
        value.to_s
      end
    end
  end

  # Configuration key constants
  EXAM_DAY = 'exam_day'
  EXAM_START_TIME = 'exam_start_time'
  EXAM_END_TIME = 'exam_end_time'
  EXAM_DURATION_MINUTES = 'exam_duration_minutes'
  EXAM_BUFFER_MINUTES = 'exam_buffer_minutes'
  GOOGLE_DRIVE_FOLDER_ID = 'google_drive_folder_id'
  SLACK_BOT_TOKEN = 'slack_bot_token'
  SLACK_APP_TOKEN = 'slack_app_token'
  SLACK_SIGNING_SECRET = 'slack_signing_secret'
  QUARTER_START_DATE = 'quarter_start_date'
  TOTAL_EXAMS = 'total_exams'
  NOTIFICATION_TIME = 'notification_time'
end
