class Vehicle < ApplicationRecord
  STANDARD_VEHICLE_NUMBER_REGEX = /\A[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}\z/
  BH_VEHICLE_NUMBER_REGEX = /\A[0-9]{2}BH[0-9]{4}[A-Z]{2}\z/

  FUEL_TYPE_OPTIONS = [
    ["Petrol", "petrol"],
    ["Diesel", "diesel"],
    ["CNG / LPG", "cng_lpg"]
  ].freeze

  VEHICLE_KIND_OPTIONS = [
    ["Two-Wheeler", "two_wheeler"],
    ["Three-Wheeler", "three_wheeler"],
    ["LMV", "lmv"],
    ["LCV", "lcv"],
    ["MCV", "mcv"],
    ["HCV", "hcv"]
  ].freeze

  belongs_to :customer
  has_many :transactions, dependent: :restrict_with_exception

  before_validation :normalize_vehicle_number

  enum :fuel_type, FUEL_TYPE_OPTIONS.to_h.invert, validate: true
  enum :vehicle_kind, VEHICLE_KIND_OPTIONS.to_h.invert, validate: true

  validates :fuel_type, presence: true
  validates :vehicle_kind, presence: true
  validates :vehicle_number, presence: true, uniqueness: { scope: :customer_id, case_sensitive: false }
  validate :vehicle_number_format

  def self.normalize_vehicle_number(value)
    value.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def self.valid_vehicle_number?(value)
    normalized_value = normalize_vehicle_number(value)
    normalized_value.match?(STANDARD_VEHICLE_NUMBER_REGEX) || normalized_value.match?(BH_VEHICLE_NUMBER_REGEX)
  end

  def display_fuel_type
    display_value_for(FUEL_TYPE_OPTIONS, fuel_type)
  end

  def display_vehicle_kind
    display_value_for(VEHICLE_KIND_OPTIONS, vehicle_kind)
  end

  def display_name
    "#{vehicle_number} | #{display_fuel_type} | #{display_vehicle_kind}"
  end

  private

  def display_value_for(options, value)
    options.to_h.invert[value.presence] || "Not Set"
  end

  def normalize_vehicle_number
    self.vehicle_number = self.class.normalize_vehicle_number(vehicle_number)
  end

  def vehicle_number_format
    return if vehicle_number.blank?
    return if vehicle_number.match?(STANDARD_VEHICLE_NUMBER_REGEX) || vehicle_number.match?(BH_VEHICLE_NUMBER_REGEX)

    errors.add(:vehicle_number, "is invalid")
  end
end
