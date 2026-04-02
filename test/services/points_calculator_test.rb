require "test_helper"

class PointsCalculatorTest < ActiveSupport::TestCase
  test "calculates points based on fuel amount and fuel type rate" do
    assert_equal 0, PointsCalculator.call(99, fuel_type: :petrol)
    assert_equal 2, PointsCalculator.call(100, fuel_type: :petrol)
    assert_equal 5, PointsCalculator.call(550, fuel_type: :diesel)
  end

  test "uses the configured rupee unit when calculating points" do
    RewardSetting.current.update!(rupees_per_reward_unit: 50)

    assert_equal 4, PointsCalculator.call(100, fuel_type: :petrol)
  end

  test "uses customized reward rate when present" do
    fuel_reward_rates(:petrol).update!(points_per_100: 3)

    assert_equal 6, PointsCalculator.call(200, fuel_type: :petrol)
  end

  test "uses vehicle type reward rate per Rs100 when present" do
    vehicle_types(:two_wheeler).update!(reward_points_per_100: 4)

    assert_equal 20, PointsCalculator.call(550, fuel_type: :petrol, vehicle_kind: :two_wheeler)
  end
end
