class PointsCalculator
  def self.call(fuel_amount, fuel_type:)
    new(fuel_amount, fuel_type:).call
  end

  def initialize(fuel_amount, fuel_type:)
    @fuel_amount = BigDecimal(fuel_amount.to_s)
    @fuel_type = fuel_type
  end

  def call
    ((fuel_amount / 100).floor * points_per_100)
  end

  private

  attr_reader :fuel_amount

  def points_per_100
    FuelRewardRate.points_per_100_for(@fuel_type)
  end
end
