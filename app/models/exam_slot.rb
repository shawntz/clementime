class ExamSlot < ApplicationRecord
  # Associations
  belongs_to :student
  belongs_to :section
  has_one :recording, dependent: :destroy
  has_many :histories, class_name: 'ExamSlotHistory', dependent: :destroy

  # Callbacks
  after_update :create_history_entry, if: :saved_change_to_scheduling_attributes?

  # Validations
  validates :exam_number, presence: true,
            uniqueness: { scope: :student_id },
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 5 }
  validates :week_number, presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validate :start_time_before_end_time

  # Scopes
  scope :scheduled, -> { where(is_scheduled: true) }
  scope :unscheduled, -> { where(is_scheduled: false) }
  scope :for_exam, ->(exam_num) { where(exam_number: exam_num) }
  scope :for_week, ->(week_num) { where(week_number: week_num) }
  scope :upcoming, -> { where('date >= ?', Date.today).order(:date, :start_time) }
  scope :past, -> { where('date < ?', Date.today).order(date: :desc, start_time: :desc) }

  # Methods
  def duration_minutes
    return nil unless start_time && end_time
    ((end_time - start_time) / 60).to_i
  end

  def formatted_time_range
    return 'Not scheduled' unless start_time && end_time
    "#{start_time.strftime('%I:%M %p')} - #{end_time.strftime('%I:%M %p')}"
  end

  def has_recording?
    recording.present?
  end

  private

  def start_time_before_end_time
    if start_time.present? && end_time.present? && start_time >= end_time
      errors.add(:start_time, "must be before end time")
    end
  end

  def saved_change_to_scheduling_attributes?
    saved_change_to_date? || saved_change_to_start_time? || saved_change_to_end_time? ||
    saved_change_to_week_number? || saved_change_to_section_id? || saved_change_to_is_scheduled?
  end

  def create_history_entry
    histories.create!(
      student: student,
      section: section,
      exam_number: exam_number,
      week_number: week_number_before_last_save,
      date: date_before_last_save,
      start_time: start_time_before_last_save,
      end_time: end_time_before_last_save,
      is_scheduled: is_scheduled_before_last_save,
      changed_at: Time.current,
      changed_by: 'system',
      reason: 'Schedule updated'
    )
  end
end
