require "test_helper"

module Admin
  class PointsAdjustmentsControllerTest < ActionDispatch::IntegrationTest
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
