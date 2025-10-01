class Student < ApplicationRecord
  # Associations
  belongs_to :section
  has_many :exam_slots, dependent: :destroy
  has_many :constraints, dependent: :destroy
  has_many :recordings, dependent: :destroy

  # Validations
  validates :sis_user_id, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, presence: true
  validates :week_group, inclusion: { in: %w[odd even], allow_nil: true }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :with_slack, -> { where.not(slack_user_id: nil) }
  scope :without_slack, -> { where(slack_user_id: nil) }
  scope :slack_matched, -> { where(slack_matched: true) }
  scope :slack_unmatched, -> { where(slack_matched: false) }
  scope :odd_week, -> { where(week_group: 'odd') }
  scope :even_week, -> { where(week_group: 'even') }

  # Methods
  def scheduled_exams_count
    exam_slots.where(is_scheduled: true).count
  end

  def has_constraints?
    constraints.where(is_active: true).any?
  end

  def active_constraints
    constraints.where(is_active: true)
  end
end
