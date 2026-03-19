require "test_helper"

module Admin
  class FuelRewardRatesControllerTest < ActionDispatch::IntegrationTest
    test "admin can update reward rates" do
      sign_in users(:one)

      patch admin_fuel_reward_rates_path, params: {
        fuel_reward_rates: {
          petrol: { points_per_100: 4 },
          diesel: { points_per_100: 2 },
          cng_lpg: { points_per_100: 1 }
        }
      }

      assert_redirected_to admin_fuel_reward_rates_path
      assert_equal 4, fuel_reward_rates(:petrol).reload.points_per_100
      assert_equal 2, fuel_reward_rates(:diesel).reload.points_per_100
    end
  end
end
