require "test_helper"

class PointsCalculatorTest < ActiveSupport::TestCase
  test "calculates points based on fuel amount and fuel type rate" do
    assert_equal 0, PointsCalculator.call(99, fuel_type: :petrol)
    assert_equal 2, PointsCalculator.call(100, fuel_type: :petrol)
    assert_equal 5, PointsCalculator.call(550, fuel_type: :diesel)
  end

  test "uses customized reward rate when present" do
    fuel_reward_rates(:petrol).update!(points_per_100: 3)

    assert_equal 6, PointsCalculator.call(200, fuel_type: :petrol)
  end
end
