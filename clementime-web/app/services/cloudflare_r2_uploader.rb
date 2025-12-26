require "aws-sdk-s3"

class CloudflareR2Uploader
  attr_reader :errors

  def initialize
    @errors = []
    @s3_client = nil
    setup_client
  end

  def upload_from_data(audio_data, recording)
    return false unless @s3_client

    begin
      exam_slot = recording.exam_slot
      ta_username = recording.ta.username
      student_name = sanitize_filename(recording.student.full_name)
      timestamp = recording.recorded_at.strftime("%Y%m%d_%H%M%S")

      # File path: week_X/ta_username/Section_StudentName_ExamN_TIMESTAMP.webm
      file_key = "week_#{exam_slot.week_number}/#{ta_username}/#{recording.section.code}_#{student_name}_Exam#{exam_slot.exam_number}_#{timestamp}.webm"

      # Upload to R2
      bucket_name = SystemConfig.get("cloudflare_r2_bucket_name")
      public_url = SystemConfig.get("cloudflare_r2_public_url") # e.g., https://pub-xxxxx.r2.dev

      @s3_client.put_object(
        bucket: bucket_name,
        key: file_key,
        body: audio_data,
        content_type: "audio/webm"
      )

      # Generate public URL
      recording_url = "#{public_url}/#{file_key}"

      # Update recording with URL
      recording.update!(
        recording_url: recording_url,
        uploaded_at: Time.current
      )

      true
    rescue Aws::S3::Errors::ServiceError => e
      @errors << "R2 upload failed: #{e.message}"
      Rails.logger.error("R2 upload error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    rescue => e
      @errors << "Upload failed: #{e.message}"
      Rails.logger.error("R2 upload error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    end
  end

  private

  def setup_client
    begin
      account_id = SystemConfig.get("cloudflare_r2_account_id")
      access_key_id = SystemConfig.get("cloudflare_r2_access_key_id")
      secret_access_key = SystemConfig.get("cloudflare_r2_secret_access_key")

      unless account_id.present? && access_key_id.present? && secret_access_key.present?
        @errors << "Cloudflare R2 credentials not configured"
        return
      end

      # Cloudflare R2 endpoint format
      endpoint = "https://#{account_id}.r2.cloudflarestorage.com"

      @s3_client = Aws::S3::Client.new(
        region: "auto",
        endpoint: endpoint,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        force_path_style: true
      )

    rescue => e
      @errors << "Failed to initialize R2 client: #{e.message}"
      Rails.logger.error("R2 setup error: #{e.class}: #{e.message}")
      @s3_client = nil
    end
  end

  def sanitize_filename(filename)
    filename.gsub(/[^0-9A-Za-z.\-]/, "_")
  end
end
