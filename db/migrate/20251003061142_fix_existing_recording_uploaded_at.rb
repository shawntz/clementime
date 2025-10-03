class FixExistingRecordingUploadedAt < ActiveRecord::Migration[8.0]
  def up
    # Fix recordings that have a recording_url but no uploaded_at timestamp
    # The uploaded? method now only checks for recording_url presence,
    # but we still set uploaded_at for consistency with the schema
    Recording.where.not(recording_url: nil).where(uploaded_at: nil).find_each do |recording|
      recording.update_column(:uploaded_at, recording.recorded_at)
    end
  end

  def down
    # No need to reverse this - we're just fixing data
  end
end
