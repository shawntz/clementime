class Constraint < ApplicationRecord
  # Associations
  belongs_to :student

  # Validations
  validates :constraint_type, presence: true,
            inclusion: { in: %w[time_before time_after week_preference specific_date exclude_date] }
  validates :constraint_value, presence: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(constraint_type: type) }
  scope :time_constraints, -> { where(constraint_type: [ "time_before", "time_after" ]) }
  scope :week_constraints, -> { where(constraint_type: "week_preference") }

  # Methods
  def display_description
    return description if description.present?

    case constraint_type
    when "time_before"
      "Must complete exam before #{constraint_value}"
    when "time_after"
      "Cannot take exam before #{constraint_value}"
    when "week_preference"
      "Prefers #{constraint_value} weeks only"
    when "specific_date"
      "Must take exam on #{constraint_value}"
    when "exclude_date"
      "Cannot take exam on #{constraint_value}"
    else
      constraint_value
    end
  end
end
