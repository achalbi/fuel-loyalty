class FuelRewardRate < ApplicationRecord
  DEFAULT_POINTS_PER_100 = {
    "petrol" => 2,
    "diesel" => 1,
    "cng_lpg" => 1
  }.freeze

  enum :fuel_type, Vehicle::FUEL_TYPE_OPTIONS.to_h.values.index_with(&:itself), validate: true

  validates :fuel_type, presence: true, uniqueness: true
  validates :points_per_100, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.points_per_100_for(fuel_type)
    normalized_fuel_type = fuel_type.to_s
    return 0 if normalized_fuel_type.blank?

    find_by(fuel_type: normalized_fuel_type)&.points_per_100 || DEFAULT_POINTS_PER_100.fetch(normalized_fuel_type, 0)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    DEFAULT_POINTS_PER_100.fetch(normalized_fuel_type, 0)
  end

  def self.for_settings
    Vehicle::FUEL_TYPE_OPTIONS.map do |label, fuel_type|
      find_or_initialize_by(fuel_type: fuel_type).tap do |rate|
        rate.points_per_100 ||= DEFAULT_POINTS_PER_100.fetch(fuel_type)
        rate.define_singleton_method(:display_name) { label }
      end
    end
  end
end
