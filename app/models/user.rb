class User < ApplicationRecord
  PHONE_NUMBER_LENGTH = 10
  PHONE_NUMBER_FORMAT = /\A\d{#{PHONE_NUMBER_LENGTH}}\z/
  PHONE_NUMBER_ERROR_MESSAGE = "must be a 10 digit mobile number"
  USERNAME_FORMAT = /\A\S+\z/
  INTERNAL_EMAIL_DOMAIN = "users.fuel-loyalty.local"

  # A7 — operator KYC.
  AADHAAR_FORMAT = /\A\d{12}\z/
  KYC_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  KYC_IMAGE_MAX_BYTES = 8.megabytes

  attr_writer :login

  enum :role, { admin: 0, staff: 1 }, default: :staff, validate: true

  has_many :transactions, dependent: :restrict_with_exception
  has_many :push_subscriptions, dependent: :nullify
  belongs_to :assigned_fuel_pump, class_name: "FuelPump", foreign_key: :fuel_pump_id, inverse_of: :assigned_users, optional: true
  has_many :pump_nozzle_assignments, class_name: "UserPumpNozzleAssignment", dependent: :destroy, inverse_of: :user
  has_many :assigned_fuel_pump_nozzles, through: :pump_nozzle_assignments, source: :fuel_pump_nozzle
  has_many :daily_pump_assignments, class_name: "UserPumpAssignment", dependent: :destroy, inverse_of: :user
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

  # A7 — Aadhaar encrypted at rest (non-deterministic; never queried by it);
  # KYC images as ActiveStorage attachments (purged on hard-delete).
  encrypts :aadhaar_number
  has_one_attached :profile_photo, dependent: :purge_later
  has_one_attached :id_card_photo, dependent: :purge_later

  before_validation :normalize_aadhaar_number
  before_save :sync_aadhaar_last4
  validate :aadhaar_number_must_be_valid
  validate :kyc_images_must_be_valid

  before_validation :normalize_name
  before_validation :normalize_username
  before_validation :normalize_email
  before_validation :normalize_phone_number, if: :phone_number_attribute_available?
  before_validation :sync_internal_email_from_phone_number, if: :phone_number_attribute_available?
  before_validation :clear_assigned_nozzles_without_pump, on: :pump_assignment
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
  validate :assigned_fuel_pump_must_be_active, on: :pump_assignment
  validate :assigned_fuel_pump_nozzles_required_when_pump_selected, on: :pump_assignment
  validate :assigned_fuel_pump_nozzles_must_belong_to_selected_pump, on: :pump_assignment
  validate :assigned_fuel_pump_nozzles_must_be_active, on: :pump_assignment

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

  # ---- A7 KYC ----
  def aadhaar_present?
    aadhaar_number.present?
  end

  def masked_aadhaar_number
    aadhaar_last4.present? ? "XXXX-XXXX-#{aadhaar_last4}" : nil
  end

  def id_card_present?
    id_card_photo.attached?
  end

  # Admin "purge KYC": drop the Aadhaar + ID card while keeping the account
  # shell. Works on a soft-deleted operator too.
  def purge_kyc!
    id_card_photo.purge_later if id_card_photo.attached?
    update_columns(aadhaar_number: nil, aadhaar_last4: nil) # rubocop:disable Rails/SkipsModelValidations
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

  def pump_assignment_for(on: Date.current)
    daily_pump_assignments.find_by(assigned_on: normalize_assignment_date(on))
  end

  def transaction_fuel_pump(on: Date.current)
    assignment_date = normalize_assignment_date(on)
    daily_assignment = pump_assignment_for(on: assignment_date)
    pump = if daily_assignment.present?
      daily_assignment.fuel_pump
    elsif assignment_date == Date.current
      assigned_fuel_pump
    end
    pump if pump&.active?
  end

  # Every pump this user has ever been posted to — their standing assignment
  # plus each dated one. Used to decide which settlements they may read: an FSM
  # needs to see the day's sheet for their own pump, including the shift they
  # didn't record themselves.
  def settlement_pump_ids
    ([ fuel_pump_id ] + daily_pump_assignments.pluck(:fuel_pump_id)).compact.uniq
  end

  def transaction_fuel_pump_nozzles(on: Date.current)
    assignment_date = normalize_assignment_date(on)
    daily_assignment = pump_assignment_for(on: assignment_date)
    pump = transaction_fuel_pump(on: assignment_date)
    return FuelPumpNozzle.none unless pump

    selected_ids = daily_assignment ? daily_assignment.assigned_fuel_pump_nozzle_ids : assigned_fuel_pump_nozzle_ids
    FuelPumpNozzle
      .includes(:fuel_type_record)
      .where(id: selected_ids, fuel_pump_id: pump.id, active: true)
      .ordered
  end

  def transaction_pump_ready?(on: Date.current)
    transaction_fuel_pump(on:).present? && transaction_fuel_pump_nozzles(on:).exists?
  end

  # Atomically apply a date-specific pump/nozzle override from request params.
  # The legacy fuel_pump_id and UserPumpNozzleAssignment rows are the protected
  # default assignment and are intentionally never changed by this method.
  def update_pump_assignment(attrs, on: Date.current, assigned_by: nil)
    assignment_date = normalize_assignment_date(on)
    pump_id = attrs[:fuel_pump_id].presence
    nozzle_ids = Array(attrs[:assigned_fuel_pump_nozzle_ids]).filter_map { |id| Integer(id, exception: false) }.uniq
    saved = false
    transaction do
      daily_assignment = daily_pump_assignments.find_or_initialize_by(assigned_on: assignment_date)
      daily_assignment.assign_attributes(
        fuel_pump_id: pump_id,
        assigned_fuel_pump_nozzle_ids: nozzle_ids,
        assigned_by: assigned_by,
      )
      unless daily_assignment.save
        daily_assignment.errors.each { |error| errors.add(error.attribute, error.message) }
        raise ActiveRecord::Rollback
      end

      # Daily assignments are overrides only. Never mutate the legacy pump
      # columns here: they remain the protected default configured by an admin.
      saved = true
    end
    saved
  end

  # Admin-only default assignment writer. Daily overrides must use
  # update_pump_assignment so they cannot replace this fallback assignment.
  def update_default_pump_assignment(attrs)
    saved = false
    transaction do
      assign_attributes(attrs.slice(:fuel_pump_id, :assigned_fuel_pump_nozzle_ids))
      saved = save_pump_assignment
      raise ActiveRecord::Rollback unless saved
    end
    saved
  end

  def save_pump_assignment
    clear_assigned_nozzles_without_pump
    errors.clear
    assigned_fuel_pump_must_be_active
    assigned_fuel_pump_nozzles_required_when_pump_selected
    assigned_fuel_pump_nozzles_must_belong_to_selected_pump
    assigned_fuel_pump_nozzles_must_be_active

    return false if errors.any?

    save(validate: false)
  end

  private

  def normalize_assignment_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    Date.current
  end

  # ---- A7 KYC ----
  def normalize_aadhaar_number
    return unless has_attribute?(:aadhaar_number)

    self.aadhaar_number = aadhaar_number.to_s.gsub(/[\s-]/, "").presence
  end

  def sync_aadhaar_last4
    return unless has_attribute?(:aadhaar_last4)

    self.aadhaar_last4 = aadhaar_number.present? ? aadhaar_number.last(4) : nil
  end

  def aadhaar_number_must_be_valid
    return if aadhaar_number.blank?
    return if aadhaar_number.match?(AADHAAR_FORMAT) && Verhoeff.valid?(aadhaar_number)

    errors.add(:aadhaar_number, "is not a valid Aadhaar number")
  end

  def kyc_images_must_be_valid
    { profile_photo: profile_photo, id_card_photo: id_card_photo }.each do |name, attachment|
      next unless attachment.attached?

      blob = attachment.blob
      errors.add(name, "must be a JPEG, PNG or WEBP image") unless KYC_IMAGE_TYPES.include?(blob.content_type)
      errors.add(name, "must be 8 MB or smaller") if blob.byte_size.to_i > KYC_IMAGE_MAX_BYTES
    end
  end

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
    self[:name] = name.to_s.squish.split.map(&:capitalize).join(" ").presence
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

  def clear_assigned_nozzles_without_pump
    self.assigned_fuel_pump_nozzle_ids = [] if fuel_pump_id.blank?
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

  def assigned_fuel_pump_must_be_active
    return if fuel_pump_id.blank?
    return if assigned_fuel_pump&.active?

    errors.add(:fuel_pump_id, "must be active")
  end

  def assigned_fuel_pump_nozzles_required_when_pump_selected
    return if fuel_pump_id.blank?
    return if assigned_fuel_pump_nozzles.any?

    errors.add(:assigned_fuel_pump_nozzle_ids, "must include at least one nozzle")
  end

  def assigned_fuel_pump_nozzles_must_belong_to_selected_pump
    return if fuel_pump_id.blank?

    invalid_nozzles = assigned_fuel_pump_nozzles.reject { |nozzle| nozzle.fuel_pump_id == fuel_pump_id }
    return if invalid_nozzles.empty?

    errors.add(:assigned_fuel_pump_nozzle_ids, "must belong to the selected pump")
  end

  def assigned_fuel_pump_nozzles_must_be_active
    inactive_nozzles = assigned_fuel_pump_nozzles.reject(&:active?)
    return if inactive_nozzles.empty?

    errors.add(:assigned_fuel_pump_nozzle_ids, "must all be active")
  end
end
