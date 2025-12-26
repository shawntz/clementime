class User < ApplicationRecord
  has_secure_password validations: false

  # Associations
  has_many :sections, foreign_key: "ta_id", dependent: :nullify
  has_many :recordings, foreign_key: "ta_id", dependent: :nullify

  # Validations
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: %w[admin ta] }
  validates :first_name, :last_name, presence: true
  
  # Custom password validation - only validate if password is being set
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?

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

  def section_ids
    sections.pluck(:id)
  end

  # Password reset methods
  def generate_password_reset_token!
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save!(validate: false)
  end

  def clear_password_reset_token!
    self.reset_password_token = nil
    self.reset_password_sent_at = nil
    save!(validate: false)
  end

  def password_reset_token_valid?
    reset_password_sent_at.present? && reset_password_sent_at > 2.hours.ago
  end

  private

  def password_required?
    # Password is required when:
    # 1. Creating a new user with a password provided
    # 2. Updating password (password field is present)
    # But NOT required when creating a user without password (for welcome email flow)
    password.present? || password_confirmation.present? || (new_record? && password_digest.blank? && !password.nil?)
  end
end
