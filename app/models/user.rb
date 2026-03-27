class User < ApplicationRecord
  PHONE_NUMBER_LENGTH = 10
  PHONE_NUMBER_FORMAT = /\A\d{#{PHONE_NUMBER_LENGTH}}\z/
  PHONE_NUMBER_ERROR_MESSAGE = "must be a 10 digit mobile number"
  USERNAME_FORMAT = /\A\S+\z/
  INTERNAL_EMAIL_DOMAIN = "users.fuel-loyalty.local"

  attr_writer :login

  enum :role, { admin: 0, staff: 1 }, default: :staff, validate: true

  has_many :transactions, dependent: :restrict_with_exception
  has_many :shift_assignments, dependent: :restrict_with_exception
  has_many :shift_templates, through: :shift_assignments
  has_many :shift_cycles, through: :shift_assignments
  has_many :recorded_attendance_runs, class_name: "AttendanceRun", foreign_key: :recorded_by_id, dependent: :restrict_with_exception
  has_many :scheduled_attendance_entries, class_name: "AttendanceEntry", foreign_key: :scheduled_user_id, dependent: :restrict_with_exception
  has_many :actual_attendance_entries, class_name: "AttendanceEntry", foreign_key: :actual_user_id, dependent: :restrict_with_exception
  has_many :replacement_attendance_entries, class_name: "AttendanceEntry", foreign_key: :replacement_user_id, dependent: :restrict_with_exception
  has_many :attendance_entry_changes, class_name: "AttendanceEntryChange", foreign_key: :changed_by_id, dependent: :restrict_with_exception
  has_many :recorded_shift_swaps, class_name: "ShiftSwap", foreign_key: :recorded_by_id, dependent: :restrict_with_exception
  has_many :shift_swaps_from, class_name: "ShiftSwap", foreign_key: :from_user_id, dependent: :restrict_with_exception
  has_many :shift_swaps_to, class_name: "ShiftSwap", foreign_key: :to_user_id, dependent: :restrict_with_exception

  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  before_validation :normalize_name
  before_validation :normalize_username
  before_validation :normalize_email
  before_validation :normalize_phone_number, if: :phone_number_attribute_available?
  before_validation :sync_internal_email_from_phone_number, if: :phone_number_attribute_available?
  after_validation :suppress_internal_email_uniqueness_error

  validates :name, presence: true
  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: USERNAME_FORMAT }
  validates :role, presence: true
  validates :employee_code, uniqueness: { case_sensitive: false }, allow_blank: true, if: -> { has_attribute?(:employee_code) }
  validates :subtitle, length: { maximum: 120 }, allow_blank: true, if: -> { has_attribute?(:subtitle) }
  validates :phone_number, uniqueness: true, allow_blank: true, if: :phone_number_attribute_available?
  validates :phone_number, format: { with: PHONE_NUMBER_FORMAT, message: PHONE_NUMBER_ERROR_MESSAGE }, allow_blank: true, if: :phone_number_attribute_available?
  validate :phone_number_required, if: :phone_number_required?
  validate :must_keep_at_least_one_admin, if: :demoting_last_admin?

  scope :kept, -> { where(deleted_at: nil) }
  scope :soft_deleted, -> { where.not(deleted_at: nil) }

  def login
    @login || username || stored_phone_number || email
  end

  def display_name
    name.presence || username.presence || display_phone_number || "User"
  end

  def display_contact
    display_phone_number || explicit_email || username.presence
  end

  def display_phone_number
    return if stored_phone_number.blank?

    "+91 #{stored_phone_number}"
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
      lowered_login = login.downcase
      query = "LOWER(username) = :value OR LOWER(email) = :value"
      bindings = { value: lowered_login }

      if phone_number_attribute_available?
        query = "#{query} OR phone_number = :phone"
        bindings[:phone] = normalize_phone_number(login)
      end

      kept.where(conditions).find_by(query, bindings)
    else
      kept.find_by(conditions)
    end
  end

  def self.phone_number_attribute_available?
    attribute_names.include?("phone_number")
  end

  def self.normalize_phone_number(value)
    value.to_s.gsub(/\D/, "")
  end

  def self.valid_phone_number?(value)
    normalize_phone_number(value).match?(PHONE_NUMBER_FORMAT)
  end

  def self.active
    kept.where(active: true)
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

  def active_for_authentication?
    super && active? && !soft_deleted?
  end

  def inactive_message
    return :inactive unless active? && !soft_deleted?

    super
  end

  def soft_deleted?
    deleted_at.present?
  end

  def soft_delete!(at: Time.current)
    if admin?
      errors.add(:base, "Only staff accounts can be soft deleted")
      raise ActiveRecord::RecordInvalid, self
    end

    if active?
      errors.add(:base, "User is in active state. Deactivate before soft deleting")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(active: false, deleted_at: at)
  end

  def current_shift_assignment(on: Time.current)
    shift_assignments.active.effective_at(on).order(effective_from: :desc).first
  end

  def current_shift_template(on: Time.current)
    current_shift_assignment(on:)&.resolved_shift_template(at: on)
  end

  def current_shift_cycle(on: Time.current)
    assignment = current_shift_assignment(on:)
    assignment&.shift_cycle || assignment&.shift_template&.current_shift_cycle(at: on)
  end

  private

  def phone_number_attribute_available?
    self.class.phone_number_attribute_available? && has_attribute?(:phone_number)
  end

  def stored_phone_number
    return unless phone_number_attribute_available?

    self[:phone_number]
  end

  def demoting_last_admin?
    persisted? && will_save_change_to_role? && role_change_to_be_saved&.first == "admin" && role != "admin"
  end

  def phone_number_required?
    phone_number_attribute_available? && (new_record? || will_save_change_to_phone_number? || stored_phone_number.present?)
  end

  def phone_number_required
    errors.add(:phone_number, "can't be blank") if stored_phone_number.blank?
  end

  def normalize_phone_number
    self[:phone_number] = self.class.normalize_phone_number(stored_phone_number)
  end

  def normalize_name
    self[:name] = name.to_s.squish.presence
  end

  def normalize_username
    self[:username] = username.to_s.strip.presence
  end

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end

  def sync_internal_email_from_phone_number
    phone_number = stored_phone_number
    return if phone_number.blank?
    return unless email.blank? || self.class.internal_email?(email)

    self.email = self.class.internal_email_for(phone_number)
  end

  def suppress_internal_email_uniqueness_error
    return unless email.present? && self.class.internal_email?(email)
    return unless errors[:email].include?("has already been taken")

    errors.delete(:email)
  end

  def must_keep_at_least_one_admin
    return if self.class.where(role: :admin).where.not(id: id).exists?

    errors.add(:role, "must leave at least one admin user")
  end
end
