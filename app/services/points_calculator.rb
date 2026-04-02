class PointsCalculator
  def self.call(fuel_amount, fuel_type:, vehicle_kind: nil)
    new(fuel_amount, fuel_type: fuel_type, vehicle_kind: vehicle_kind).call
  end

  def initialize(fuel_amount, fuel_type:, vehicle_kind: nil)
    @fuel_amount = BigDecimal(fuel_amount.to_s)
    @fuel_type = fuel_type
    @vehicle_kind = vehicle_kind
  end

  def call
    ((fuel_amount / rupees_per_reward_unit).floor * points_per_100)
  end

  private

  attr_reader :fuel_amount

  def points_per_100
    vehicle_type_points_per_100.nil? ? FuelRewardRate.points_per_100_for(@fuel_type) : vehicle_type_points_per_100
  end

  def vehicle_type_points_per_100
    @vehicle_type_points_per_100 ||= VehicleType.reward_points_per_100_for(@vehicle_kind)
  end

  def rupees_per_reward_unit
    @rupees_per_reward_unit ||= BigDecimal(RewardSetting.current.rupees_per_reward_unit.to_s)
  end
end
