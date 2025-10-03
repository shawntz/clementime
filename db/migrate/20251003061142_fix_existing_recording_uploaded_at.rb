class FixExistingRecordingUploadedAt < ActiveRecord::Migration[8.0]
  def up
    # Fix recordings that have a recording_url but no uploaded_at timestamp
    Recording.where.not(recording_url: nil).where(uploaded_at: nil).find_each do |recording|
      recording.update_column(:uploaded_at, recording.recorded_at)
    end

    # Fix recordings that were uploaded to R2 but don't have recording_url set
    # This can happen if the upload succeeded but the database update failed
    public_url = SystemConfig.get("cloudflare_r2_public_url")

    if public_url.present?
      Recording.where(recording_url: nil)
               .where.not(recorded_at: nil)
               .includes(:exam_slot, :ta, :student, :section)
               .find_each do |recording|
        # Reconstruct the R2 URL based on the naming convention
        exam_slot = recording.exam_slot
        ta_username = recording.ta.username
        student_name = recording.student.full_name.gsub(/[^0-9A-Za-z.\-]/, "_")
        timestamp = recording.recorded_at.strftime("%Y%m%d_%H%M%S")

        file_key = "week_#{exam_slot.week_number}/#{ta_username}/#{recording.section.code}_#{student_name}_Exam#{exam_slot.exam_number}_#{timestamp}.webm"
        recording_url = "#{public_url}/#{file_key}"

        recording.update_columns(
          recording_url: recording_url,
          uploaded_at: recording.recorded_at
        )
      end
    end
  end

  def down
    # No need to reverse this - we're just fixing data
  end
end
