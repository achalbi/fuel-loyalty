class User < ApplicationRecord
  PHONE_NUMBER_LENGTH = 10
  PHONE_NUMBER_FORMAT = /\A\d{#{PHONE_NUMBER_LENGTH}}\z/
  PHONE_NUMBER_ERROR_MESSAGE = "must be a 10 digit mobile number"
  INTERNAL_EMAIL_DOMAIN = "users.fuel-loyalty.local"

  attr_writer :login

  enum :role, { admin: 0, staff: 1 }, default: :staff, validate: true

  has_many :transactions, dependent: :restrict_with_exception

  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  before_validation :normalize_phone_number
  before_validation :sync_internal_email_from_phone_number

  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-zA-Z0-9_]+\z/ }
  validates :role, presence: true
  validates :phone_number, uniqueness: true, allow_blank: true
  validates :phone_number, format: { with: PHONE_NUMBER_FORMAT, message: PHONE_NUMBER_ERROR_MESSAGE }, allow_blank: true
  validate :phone_number_required, if: :phone_number_required?
  validate :must_keep_at_least_one_admin, if: :demoting_last_admin?

  def login
    @login || username || phone_number || email
  end

  def display_name
    username.presence || display_phone_number || "User"
  end

  def display_contact
    display_phone_number || explicit_email || username.presence
  end

  def display_phone_number
    return if phone_number.blank?

    "+91 #{phone_number}"
  end

  def explicit_email
    return if email.blank? || self.class.internal_email?(email)

    email
  end

  def avatar_initial
    display_name.to_s.first.to_s.upcase.presence || "U"
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    login = conditions.delete(:login)&.strip

    if login.present?
      normalized_phone_number = normalize_phone_number(login)
      lowered_login = login.downcase

      where(conditions).find_by(
        "LOWER(username) = :value OR phone_number = :phone OR LOWER(email) = :value",
        value: lowered_login,
        phone: normalized_phone_number
      )
    else
      find_by(conditions)
    end
  end

  def self.normalize_phone_number(value)
    value.to_s.gsub(/\D/, "")
  end

  def self.valid_phone_number?(value)
    normalize_phone_number(value).match?(PHONE_NUMBER_FORMAT)
  end

  def self.internal_email_for(phone_number)
    "user-#{normalize_phone_number(phone_number)}@#{INTERNAL_EMAIL_DOMAIN}"
  end

  def self.internal_email?(value)
    value.to_s.downcase.match?(/\Auser-\d+@#{Regexp.escape(INTERNAL_EMAIL_DOMAIN)}\z/)
  end

  def email_required?
    false
  end

  private

  def demoting_last_admin?
    persisted? && will_save_change_to_role? && role_change_to_be_saved&.first == "admin" && role != "admin"
  end

  def phone_number_required?
    new_record? || will_save_change_to_phone_number? || phone_number.present?
  end

  def phone_number_required
    errors.add(:phone_number, "can't be blank") if phone_number.blank?
  end

  def normalize_phone_number
    self.phone_number = self.class.normalize_phone_number(phone_number)
  end

  def sync_internal_email_from_phone_number
    return if phone_number.blank?
    return unless email.blank? || self.class.internal_email?(email)

    self.email = self.class.internal_email_for(phone_number)
  end

  def must_keep_at_least_one_admin
    return if self.class.where(role: :admin).where.not(id: id).exists?

    errors.add(:role, "must leave at least one admin user")
  end
end
