require "test_helper"

module Admin
  class FuelRewardRatesControllerTest < ActionDispatch::IntegrationTest
    test "admin sees reward rates for active fuel types only" do
      sign_in users(:one)
      fuel_types(:diesel).update!(active: false)

      get admin_fuel_reward_rates_path

      assert_response :success
      assert_select "h1", "Fuel Reward Rates"
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
