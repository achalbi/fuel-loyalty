require "test_helper"

module Admin
  class FuelRewardRatesControllerTest < ActionDispatch::IntegrationTest
    test "admin sees vehicle type overrides and active fuel fallback rates" do
      sign_in users(:one)
      fuel_types(:diesel).update!(active: false)

      get admin_fuel_reward_rates_path

      assert_response :success
      assert_select "h1", "Reward Rates"
      assert_select "input[name='reward_setting[rupees_per_reward_unit]']", 1
      assert_select "input[name='reward_setting[minimum_redeemable_points]']", 1
      assert_select "input[name='reward_setting[cash_value_per_point]']", 1
      assert_select "h2", "Vehicle Type Reward Overrides"
      assert_select "input[name='vehicle_type_reward_rates[two_wheeler][reward_points_per_100]']", 1
      assert_select "input[name='vehicle_type_reward_rates[lmv][reward_points_per_100]']", 1
      assert_select "h2", "Fuel-Type Fallback Rates"
      assert_select "input[name='fuel_reward_rates[petrol][points_per_100]']", 1
      assert_select "input[name='fuel_reward_rates[diesel][points_per_100]']", 0
      assert_select "a.nav-link.active[href='#{admin_fuel_reward_rates_path}']", text: /Reward Rates/
    end

    test "admin sees reward rates for newly added active fuel types" do
      sign_in users(:one)
      FuelType.create!(name: "Premium Diesel", active: true)

      get admin_fuel_reward_rates_path

      assert_response :success
      assert_select "input[name='fuel_reward_rates[premium_diesel][points_per_100]']", 1
    end

    test "admin can update the reward unit" do
      sign_in users(:one)

      patch admin_fuel_reward_rates_path, params: {
        reward_setting: {
          rupees_per_reward_unit: 50,
          minimum_redeemable_points: 250,
          cash_value_per_point: "0.50"
        }
      }

      assert_redirected_to admin_fuel_reward_rates_path
      assert_equal 50, RewardSetting.current.rupees_per_reward_unit
      assert_equal 250, RewardSetting.current.minimum_redeemable_points
      assert_equal BigDecimal("0.5"), RewardSetting.current.cash_value_per_point
    end

    test "admin can update vehicle type reward overrides" do
      sign_in users(:one)

      patch admin_fuel_reward_rates_path, params: {
        vehicle_type_reward_rates: {
          two_wheeler: { reward_points_per_100: 4 },
          lmv: { reward_points_per_100: 2 },
          hcv: { reward_points_per_100: "" }
        }
      }

      assert_redirected_to admin_fuel_reward_rates_path
      assert_equal 4, vehicle_types(:two_wheeler).reload.reward_points_per_100
      assert_equal 2, vehicle_types(:lmv).reload.reward_points_per_100
      assert_nil vehicle_types(:hcv).reload.reward_points_per_100
    end

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

    test "admin cannot update reward rates for inactive fuel types" do
      sign_in users(:one)
      fuel_types(:diesel).update!(active: false)

      patch admin_fuel_reward_rates_path, params: {
        fuel_reward_rates: {
          petrol: { points_per_100: 4 },
          diesel: { points_per_100: 9 }
        }
      }

      assert_redirected_to admin_fuel_reward_rates_path
      assert_equal 4, fuel_reward_rates(:petrol).reload.points_per_100
      assert_equal 1, fuel_reward_rates(:diesel).reload.points_per_100
    end
  end
end
