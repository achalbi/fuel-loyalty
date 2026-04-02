require "test_helper"

module Staff
  class RedemptionsControllerTest < ActionDispatch::IntegrationTest
    test "renders the enhanced customer details panel on the new page" do
      sign_in users(:two)

      get new_staff_redemption_path

      assert_response :success
      assert_select "[data-customer-placeholder]"
      assert_select ".redemption-customer-card--placeholder"
      assert_select "[data-customer-panel].d-none"
      assert_select "[data-customer-points]"
      assert_select "[data-customer-redeem-note]"
      assert_select "[data-customer-minimum-redeemable]"
      assert_select "[data-customer-max-redeemable]"
      assert_select "[data-customer-max-redeemable-cash]"
      assert_select "[data-points-cash-reward]"
      assert_select "[data-customer-vehicles-count]"
    end

    test "shows the configured minimum redemption step on the new page" do
      sign_in users(:two)
      RewardSetting.current.update!(minimum_redeemable_points: 250)

      get new_staff_redemption_path

      assert_response :success
      assert_match "Points can only be redeemed in multiples of 250.", response.body
    end

    test "staff can redeem points for an existing customer" do
      sign_in users(:two)
      RewardSetting.current.update!(cash_value_per_point: 0.5)
      customer = Customer.create!(name: "Redeem Controller User", phone_number: "9777777777")
      customer.points_ledgers.create!(points: 500, entry_type: :earn)

      assert_difference -> { customer.points_ledgers.count }, 1 do
        post staff_redemptions_path, params: { redemption: { phone_number: customer.phone_number, points: 500 } }
      end

      assert_redirected_to customer_path(customer)
      follow_redirect!
      assert_match "500 points redeemed successfully. Cash reward: ₹250.00.", response.body
    end

    test "shows validation feedback when requested points exceed redeemable balance" do
      sign_in users(:two)
      customer = Customer.create!(name: "Redeem Controller Limit User", phone_number: "9888888888")
      customer.points_ledgers.create!(points: 550, entry_type: :earn)

      post staff_redemptions_path, params: { redemption: { phone_number: customer.phone_number, points: 600 } }

      assert_response :unprocessable_entity
      assert_match "cannot exceed 500 redeemable points", response.body
    end

    test "shows validation feedback when points are not in multiples of 100" do
      sign_in users(:two)
      customer = Customer.create!(name: "Redeem Controller Step User", phone_number: "9999999998")
      customer.points_ledgers.create!(points: 500, entry_type: :earn)

      post staff_redemptions_path, params: { redemption: { phone_number: customer.phone_number, points: 150 } }

      assert_response :unprocessable_entity
      assert_match "must be in multiples of 100", response.body
    end

    test "shows validation feedback when the vehicle type requires a higher minimum redemption" do
      sign_in users(:two)
      vehicle_types(:lcv).update!(minimum_redeemable_points: 300)
      customer = Customer.create!(name: "Redeem Controller Threshold User", phone_number: "9999999997")
      customer.vehicles.create!(vehicle_number: "TN20AB1234", fuel_type: :diesel, vehicle_kind: vehicle_types(:lcv).code)
      customer.points_ledgers.create!(points: 450, entry_type: :earn)

      post staff_redemptions_path, params: { redemption: { phone_number: customer.phone_number, points: 200 } }

      assert_response :unprocessable_entity
      assert_match "must be at least 300 points", response.body
    end
  end
end
