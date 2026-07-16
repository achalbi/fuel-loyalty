class Vehicle < ApplicationRecord
  STANDARD_VEHICLE_NUMBER_REGEX = VehiclePlateText::STANDARD_REGEX
  BH_VEHICLE_NUMBER_REGEX = VehiclePlateText::BH_REGEX
  COMMERCIAL_VEHICLE_KINDS = %w[lcv mcv hcv].freeze
  COMMERCIAL_REGISTRATION_FIELDS = %w[
    commercial_company_name
    commercial_contact_name
    commercial_contact_phone_number
    commercial_address
    commercial_notes
  ].freeze

  belongs_to :customer
  has_many :transactions, dependent: :restrict_with_exception

  before_validation :normalize_fuel_type
  before_validation :normalize_vehicle_kind
  before_validation :normalize_vehicle_number
  before_validation :normalize_commercial_registration_fields
  before_validation :clear_commercial_registration_fields_unless_commercial

  validates :fuel_type, presence: true
  validates :vehicle_kind, presence: true
  validates :vehicle_number, presence: true, uniqueness: { scope: :customer_id, case_sensitive: false }
  validate :fuel_type_must_exist_for_new_selection
  validate :fuel_type_must_be_active_for_new_selection
  validate :vehicle_kind_must_exist_for_new_selection
  validate :vehicle_kind_must_be_active_for_new_selection
  validate :vehicle_number_format
  validate :commercial_contact_phone_number_format

  def self.normalize_vehicle_number(value)
    VehiclePlateText.normalize(value)
  end

  def self.commercial_vehicle_kind?(value)
    COMMERCIAL_VEHICLE_KINDS.include?(VehicleType.normalize_code(value))
  end

  def self.valid_vehicle_number?(value)
    VehiclePlateText.valid?(value)
  end

  def self.normalize_detected_vehicle_number(value)
    VehiclePlateText.normalize_detected(value)
  end

  def display_fuel_type
    FuelType.label_for(fuel_type).presence || fuel_type.to_s.humanize
  end

  def display_vehicle_kind
    VehicleType.label_for(vehicle_kind).presence || vehicle_kind.to_s.humanize
  end

  def display_name
    "#{vehicle_number} | #{display_fuel_type} | #{display_vehicle_kind}"
  end

  def commercial_vehicle?
    self.class.commercial_vehicle_kind?(vehicle_kind)
  end

  COMMERCIAL_REGISTRATION_FIELDS.each do |field_name|
    define_method(field_name) do
      commercial_registration_fields_supported? ? self[field_name] : nil
    end

    define_method("#{field_name}=") do |value|
      return value unless commercial_registration_fields_supported?

      self[field_name] = value
    end
  end

  def commercial_registration_present?
    [
      commercial_company_name,
      commercial_contact_name,
      commercial_contact_phone_number,
      commercial_address,
      commercial_notes
    ].any?(&:present?)
  end

  def commercial_contact_summary
    return if commercial_company_name.blank? && commercial_contact_name.blank?

    [commercial_company_name, commercial_contact_name].compact.join(" · ")
  end

  private

  def normalize_fuel_type
    self.fuel_type = fuel_type.to_s.parameterize(separator: "_").presence
  end

  def normalize_vehicle_kind
    self.vehicle_kind = VehicleType.normalize_code(vehicle_kind)
  end

  def normalize_vehicle_number
    self.vehicle_number = self.class.normalize_vehicle_number(vehicle_number)
  end

  def normalize_commercial_registration_fields
    self.commercial_company_name = commercial_company_name.to_s.squish.presence
    self.commercial_contact_name = commercial_contact_name.to_s.squish.presence
    self.commercial_contact_phone_number = Customer.normalize_phone_number(commercial_contact_phone_number).presence
    self.commercial_address = commercial_address.to_s.strip.presence
    self.commercial_notes = commercial_notes.to_s.strip.presence
  end

  def clear_commercial_registration_fields_unless_commercial
    return if commercial_vehicle?

    self.commercial_company_name = nil
    self.commercial_contact_name = nil
    self.commercial_contact_phone_number = nil
    self.commercial_address = nil
    self.commercial_notes = nil
  end

  def vehicle_number_format
    return if vehicle_number.blank?
    return if vehicle_number.match?(STANDARD_VEHICLE_NUMBER_REGEX) || vehicle_number.match?(BH_VEHICLE_NUMBER_REGEX)

    errors.add(:vehicle_number, "is invalid")
  end

  def fuel_type_must_exist_for_new_selection
    return if fuel_type.blank?
    return if FuelType.exists?(code: fuel_type)
    return if persisted? && fuel_type == fuel_type_in_database

    errors.add(:fuel_type, "is not available")
  end

  def fuel_type_must_be_active_for_new_selection
    return if fuel_type.blank?
    return unless FuelType.exists?(code: fuel_type)
    return if FuelType.active_code?(fuel_type)
    return if persisted? && fuel_type == fuel_type_in_database

    errors.add(:fuel_type, "is not currently active")
  end

  def vehicle_kind_must_exist_for_new_selection
    return if vehicle_kind.blank?
    return if VehicleType.exists?(code: vehicle_kind)
    return if persisted? && vehicle_kind == vehicle_kind_in_database

    errors.add(:vehicle_kind, "is not available")
  end

  def vehicle_kind_must_be_active_for_new_selection
    return if vehicle_kind.blank?
    return unless VehicleType.exists?(code: vehicle_kind)
    return if VehicleType.active_code?(vehicle_kind)
    return if persisted? && vehicle_kind == vehicle_kind_in_database

    errors.add(:vehicle_kind, "is not currently active")
  end

  def commercial_contact_phone_number_format
    return if commercial_contact_phone_number.blank?
    return if Customer.valid_phone_number?(commercial_contact_phone_number)

    errors.add(:commercial_contact_phone_number, Customer::PHONE_NUMBER_ERROR_MESSAGE)
  end

  def commercial_registration_fields_supported?
    COMMERCIAL_REGISTRATION_FIELDS.all? { |field_name| self.class.attribute_names.include?(field_name) }
  end
end
