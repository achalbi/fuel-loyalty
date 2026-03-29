class FuelRewardRate < ApplicationRecord
  DEFAULT_POINTS_PER_100 = {
    "petrol" => 2,
    "diesel" => 1,
    "cng_lpg" => 1
  }.freeze

  before_validation :normalize_fuel_type

  validates :fuel_type, presence: true, uniqueness: true
  validates :points_per_100, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :fuel_type_must_exist

  def self.points_per_100_for(fuel_type)
    normalized_fuel_type = fuel_type.to_s.parameterize(separator: "_").presence
    return 0 if normalized_fuel_type.blank?

    find_by(fuel_type: normalized_fuel_type)&.points_per_100 || DEFAULT_POINTS_PER_100.fetch(normalized_fuel_type, 0)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    DEFAULT_POINTS_PER_100.fetch(normalized_fuel_type, 0)
  end

  def self.label_for(fuel_type)
    FuelType.label_for(fuel_type)
  end

  def self.for_settings
    FuelType.active_for_settings.map do |fuel_type_record|
      find_or_initialize_by(fuel_type: fuel_type_record.code).tap do |rate|
        rate.points_per_100 ||= DEFAULT_POINTS_PER_100.fetch(fuel_type_record.code, 0)
      end
    end
  end

  def self.setting_fuel_type_values
    FuelType.active_for_settings.map(&:code)
  end

  def display_name
    self.class.label_for(fuel_type)
  end

  private

  def normalize_fuel_type
    self.fuel_type = fuel_type.to_s.parameterize(separator: "_").presence
  end

  def fuel_type_must_exist
    return if fuel_type.blank?
    return if FuelType.exists?(code: fuel_type)

    errors.add(:fuel_type, "is not available")
  end
end
