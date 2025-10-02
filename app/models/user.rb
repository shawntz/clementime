class User < ApplicationRecord
  has_secure_password

  # Associations
  has_many :sections, foreign_key: "ta_id", dependent: :nullify
  has_many :recordings, foreign_key: "ta_id", dependent: :nullify

  # Validations
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: %w[admin ta] }
  validates :first_name, :last_name, presence: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :admins, -> { where(role: "admin") }
  scope :tas, -> { where(role: "ta") }

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def admin?
    role == "admin"
  end

  def ta?
    role == "ta"
  end
end
