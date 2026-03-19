require "test_helper"

module Staff
  class RedemptionsControllerTest < ActionDispatch::IntegrationTest
    test "staff can redeem points for an existing customer" do
      sign_in users(:two)

      assert_difference -> { customers(:one).points_ledgers.count }, 1 do
        post staff_redemptions_path, params: { redemption: { phone_number: customers(:one).phone_number, points: 2 } }
      end

      assert_redirected_to customer_path(customers(:one))
      follow_redirect!
      assert_match "2 points redeemed successfully", response.body
    end

    test "shows validation feedback when customer has insufficient points" do
      sign_in users(:two)

      post staff_redemptions_path, params: { redemption: { phone_number: customers(:one).phone_number, points: 10 } }

      assert_response :unprocessable_entity
      assert_match "cannot exceed available points", response.body
    end
  end
end
