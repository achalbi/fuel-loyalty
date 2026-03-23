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
      assert_select "[data-customer-max-redeemable]"
      assert_select "[data-customer-vehicles-count]"
    end

    test "staff can redeem points for an existing customer" do
      sign_in users(:two)
      customer = Customer.create!(name: "Redeem Controller User", phone_number: "9777777777")
      customer.points_ledgers.create!(points: 500, entry_type: :earn)

      assert_difference -> { customer.points_ledgers.count }, 1 do
        post staff_redemptions_path, params: { redemption: { phone_number: customer.phone_number, points: 500 } }
      end

      assert_redirected_to customer_path(customer)
      follow_redirect!
      assert_match "500 points redeemed successfully", response.body
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
  end
end
