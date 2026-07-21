class PointsCalculator
  def self.call(fuel_amount, fuel_type:, vehicle_kind: nil, litres: nil)
    new(fuel_amount, fuel_type: fuel_type, vehicle_kind: vehicle_kind, litres: litres).call
  end

  def initialize(fuel_amount, fuel_type:, vehicle_kind: nil, litres: nil)
    @fuel_amount = BigDecimal(fuel_amount.to_s)
    @fuel_type = fuel_type
    @vehicle_kind = vehicle_kind
    @litres = litres.nil? ? nil : BigDecimal(litres.to_s)
  end

  def call
    if reward_setting.by_litres? && @litres&.positive?
      (@litres / litres_per_reward_unit).floor * points_per_100
    else
      (fuel_amount / rupees_per_reward_unit).floor * points_per_100
    end
  end

  private

  attr_reader :fuel_amount

  def reward_setting
    @reward_setting ||= RewardSetting.current
  end

  def points_per_100
    vehicle_type_points_per_100.nil? ? FuelRewardRate.points_per_100_for(@fuel_type) : vehicle_type_points_per_100
  end

  def vehicle_type_points_per_100
    @vehicle_type_points_per_100 ||= VehicleType.reward_points_per_100_for(@vehicle_kind)
  end

  def rupees_per_reward_unit
    @rupees_per_reward_unit ||= BigDecimal(reward_setting.rupees_per_reward_unit.to_s)
  end

  def litres_per_reward_unit
    value = BigDecimal(reward_setting.litres_per_reward_unit.to_s)
    value.positive? ? value : BigDecimal(RewardSetting::DEFAULT_LITRES_PER_REWARD_UNIT.to_s)
  end
end
