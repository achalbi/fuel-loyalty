require "test_helper"

module Admin
  class PointsAdjustmentsControllerTest < ActionDispatch::IntegrationTest
    test "renders the enhanced customer details panel on the new page" do
      sign_in users(:one)

      get new_admin_points_adjustment_path

      assert_response :success
      assert_select "[data-customer-placeholder]"
      assert_select ".redemption-customer-card--placeholder"
      assert_select "[data-customer-panel].d-none"
      assert_select "[data-customer-points]"
      assert_select "[data-customer-note]"
      assert_select "[data-customer-max-redeemable]"
      assert_select "[data-customer-vehicles-count]"
      assert_select "[data-customer-vehicles-list]"
    end

    test "shows validation feedback when the phone number is not 10 digits" do
      sign_in users(:one)

      post admin_points_adjustments_path, params: {
        points_adjustment: {
          phone_number: "12345",
          points: 5
        }
      }

      assert_response :unprocessable_entity
      assert_match "Phone number must be a 10 digit number", response.body
    end
  end
end
