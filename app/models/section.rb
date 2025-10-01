class Section < ApplicationRecord
  # Associations
  belongs_to :ta, class_name: 'User', optional: true
  has_many :students, dependent: :destroy
  has_many :exam_slots, dependent: :destroy
  has_many :recordings, dependent: :destroy

  # Validations
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :with_ta, -> { where.not(ta_id: nil) }

  # Methods
  def display_name
    "#{code} - #{name}"
  end

  def students_count
    students.active.count
  end
end
