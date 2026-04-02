require "test_helper"

module Staff
  class CustomersLookupControllerTest < ActionDispatch::IntegrationTest
    test "returns customer details and vehicles for a valid phone number" do
      sign_in users(:two)
      RewardSetting.current.update!(cash_value_per_point: 0.5)
      vehicle_types(:two_wheeler).update!(minimum_redeemable_points: 200)
      vehicle_types(:lmv).update!(minimum_redeemable_points: 300)
      customers(:one).points_ledgers.create!(points: 195, entry_type: :earn)

      get lookup_staff_customers_path, params: { phone_number: customers(:one).phone_number }, as: :json

      assert_response :success

      payload = JSON.parse(response.body)
      assert payload["found"]
      assert_equal "Arun", payload.dig("customer", "name")
      assert_equal true, payload.dig("customer", "active")
      assert_equal false, payload.dig("customer", "rewards_paused")
      assert_equal "Rewards Active", payload.dig("customer", "rewards_status_label")
      assert_equal "Active", payload.dig("customer", "status_label")
      assert_equal 0.5, payload.dig("customer", "cash_value_per_point")
      assert_equal 200, payload.dig("customer", "minimum_redeemable_points")
      assert_equal 200, payload.dig("customer", "max_redeemable_points")
      assert_equal 100.0, payload.dig("customer", "max_redeemable_cash_reward")
      assert_equal 2, payload.dig("customer", "vehicles").size
      assert_equal "petrol", payload.dig("customer", "vehicles", 0, "fuel_type_code")
      assert_equal "Petrol", payload.dig("customer", "vehicles", 0, "fuel_type")
      assert_equal "Two-Wheeler", payload.dig("customer", "vehicles", 0, "vehicle_kind")
    end

    test "returns the configured global minimum redemption threshold and increment" do
      sign_in users(:two)
      RewardSetting.current.update!(minimum_redeemable_points: 250)
      customers(:one).points_ledgers.create!(points: 275, entry_type: :earn)

      get lookup_staff_customers_path, params: { phone_number: customers(:one).phone_number }, as: :json

      assert_response :success

      payload = JSON.parse(response.body)
      assert_equal 250, payload.dig("customer", "minimum_redeemable_points")
      assert_equal 250, payload.dig("customer", "redemption_increment")
      assert_equal 250, payload.dig("customer", "max_redeemable_points")
    end

    test "returns not found for an unknown phone number" do
      sign_in users(:two)

      get lookup_staff_customers_path, params: { phone_number: "9999999999" }, as: :json

      assert_response :not_found
      payload = JSON.parse(response.body)
      assert_equal false, payload["found"]
      assert_equal "Customer not found for that phone number.", payload["message"]
      assert_equal new_staff_customer_path(phone_number: "9999999999"), payload["register_customer_path"]
    end

    test "returns validation error for a phone number that is not 10 digits" do
      sign_in users(:two)

      get lookup_staff_customers_path, params: { phone_number: "12345" }, as: :json

      assert_response :unprocessable_entity
      payload = JSON.parse(response.body)
      assert_equal false, payload["found"]
      assert_equal "Phone number must be a 10 digit number.", payload["message"]
    end

    test "staff can toggle customer status" do
      sign_in users(:two)

      patch deactivate_staff_customer_path(customers(:one))
      assert_redirected_to customer_path(customers(:one))
      assert_not customers(:one).reload.active?

      patch activate_staff_customer_path(customers(:one))
      assert_redirected_to customer_path(customers(:one))
      assert customers(:one).reload.active?
    end

    test "staff can pause and resume customer rewards" do
      sign_in users(:two)

      patch pause_rewards_staff_customer_path(customers(:one))
      assert_redirected_to customer_path(customers(:one))
      assert customers(:one).reload.rewards_paused?

      patch resume_rewards_staff_customer_path(customers(:one))
      assert_redirected_to customer_path(customers(:one))
      refute customers(:one).reload.rewards_paused?
    end
  end
end
