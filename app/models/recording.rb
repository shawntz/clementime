class Recording < ApplicationRecord
  # Associations
  belongs_to :exam_slot
  belongs_to :section
  belongs_to :student
  belongs_to :ta, class_name: "User"

  # Validations
  validates :exam_slot_id, uniqueness: true

  # Scopes
  scope :uploaded, -> { where.not(google_drive_file_id: nil) }
  scope :not_uploaded, -> { where(google_drive_file_id: nil) }
  scope :recent, -> { order(recorded_at: :desc) }

  # Methods
  def uploaded?
    google_drive_file_id.present? && uploaded_at.present?
  end

  def duration
    return nil unless recorded_at && uploaded_at
    uploaded_at - recorded_at
  end
end
