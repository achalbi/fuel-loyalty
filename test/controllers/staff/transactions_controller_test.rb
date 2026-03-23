require "test_helper"

module Staff
  class TransactionsControllerTest < ActionDispatch::IntegrationTest
    test "renders separate phone and vehicle transaction forms" do
      sign_in users(:two)

      get new_staff_transaction_path

      assert_response :success
      assert_select "#transactionEntryTabs"
      assert_select "#transaction-phone-pane form[action='#{staff_transactions_path}']"
      assert_select "#transaction-vehicle-pane form[action='#{staff_transactions_path}']"
      assert_select "input[name='transaction[lookup_mode]'][value='phone']", 1
      assert_select "input[name='transaction[lookup_mode]'][value='vehicle']", 1
      assert_select "[data-transaction-phone-root]"
      assert_select "[data-transaction-vehicle-root]"
      assert_select "[data-customer-placeholder]", minimum: 2
      assert_select "[data-customer-panel].d-none", minimum: 2
      assert_select "[data-customer-points]", minimum: 2
      assert_select "[data-customer-note]", minimum: 2
      assert_select "[data-customer-vehicles-count]", minimum: 2
      assert_select "[data-customer-selected-vehicle]", minimum: 2
      assert_select "[data-customer-vehicles-list]", minimum: 2
    end

    test "looks up a customer by vehicle number" do
      sign_in users(:two)

      get lookup_staff_transactions_path, params: { vehicle_number: vehicles(:one).vehicle_number }, as: :json

      assert_response :success
      payload = JSON.parse(response.body)

      assert_equal true, payload["found"]
      assert_equal 1, payload["matches"].size
      assert_equal vehicles(:one).id, payload["matches"].first["vehicle_id"]
      assert_equal vehicles(:one).vehicle_number, payload["matches"].first["vehicle_number"]
      assert_equal customers(:one).phone_number, payload["matches"].first.dig("customer", "phone_number")
    end

    test "returns multiple matches when a vehicle number belongs to more than one customer" do
      sign_in users(:two)
      other_customer = Customer.create!(name: "Shared Plate", phone_number: "9777777777")
      duplicate_vehicle = other_customer.vehicles.create!(
        vehicle_number: vehicles(:one).vehicle_number,
        fuel_type: :diesel,
        vehicle_kind: :lmv
      )

      get lookup_staff_transactions_path, params: { vehicle_number: vehicles(:one).vehicle_number }, as: :json

      assert_response :success
      payload = JSON.parse(response.body)

      assert_equal true, payload["found"]
      assert_equal 2, payload["matches"].size
      assert_equal [customers(:one).id, other_customer.id].sort, payload["matches"].map { |match| match.dig("customer", "id") }.sort
      assert_includes payload["matches"].map { |match| match["vehicle_id"] }, duplicate_vehicle.id
    end

    test "rejects invalid vehicle numbers during lookup" do
      sign_in users(:two)

      get lookup_staff_transactions_path, params: { vehicle_number: "bad-number" }, as: :json

      assert_response :unprocessable_entity
      payload = JSON.parse(response.body)
      assert_equal false, payload["found"]
      assert_equal "Vehicle number is invalid.", payload["message"]
    end
  end
end
