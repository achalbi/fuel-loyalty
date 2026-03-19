require "test_helper"

module Staff
  class CustomersLookupControllerTest < ActionDispatch::IntegrationTest
    test "returns customer details and vehicles for a valid phone number" do
      sign_in users(:two)

      get lookup_staff_customers_path, params: { phone_number: customers(:one).phone_number }, as: :json

      assert_response :success

      payload = JSON.parse(response.body)
      assert payload["found"]
      assert_equal "Arun", payload.dig("customer", "name")
      assert_equal true, payload.dig("customer", "active")
      assert_equal "Active", payload.dig("customer", "status_label")
      assert_equal 2, payload.dig("customer", "vehicles").size
      assert_equal "Petrol", payload.dig("customer", "vehicles", 0, "fuel_type")
      assert_equal "Two-Wheeler", payload.dig("customer", "vehicles", 0, "vehicle_kind")
    end

    test "returns not found for an unknown phone number" do
      sign_in users(:two)

      get lookup_staff_customers_path, params: { phone_number: "9999999999" }, as: :json

      assert_response :not_found
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
  end
end
