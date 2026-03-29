class Vehicle < ApplicationRecord
  STANDARD_VEHICLE_NUMBER_REGEX = /\A[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}\z/
  BH_VEHICLE_NUMBER_REGEX = /\A[0-9]{2}BH[0-9]{4}[A-Z]{2}\z/

  belongs_to :customer
  has_many :transactions, dependent: :restrict_with_exception

  before_validation :normalize_fuel_type
  before_validation :normalize_vehicle_kind
  before_validation :normalize_vehicle_number

  validates :fuel_type, presence: true
  validates :vehicle_kind, presence: true
  validates :vehicle_number, presence: true, uniqueness: { scope: :customer_id, case_sensitive: false }
  validate :fuel_type_must_exist_for_new_selection
  validate :fuel_type_must_be_active_for_new_selection
  validate :vehicle_kind_must_exist_for_new_selection
  validate :vehicle_kind_must_be_active_for_new_selection
  validate :vehicle_number_format

  def self.normalize_vehicle_number(value)
    value.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def self.valid_vehicle_number?(value)
    normalized_value = normalize_vehicle_number(value)
    normalized_value.match?(STANDARD_VEHICLE_NUMBER_REGEX) || normalized_value.match?(BH_VEHICLE_NUMBER_REGEX)
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
end
