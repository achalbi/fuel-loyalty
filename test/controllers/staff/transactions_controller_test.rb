require "test_helper"

module Staff
  class TransactionsControllerTest < ActionDispatch::IntegrationTest
    test "renders separate phone and vehicle transaction forms" do
      sign_in users(:two)

      get new_staff_transaction_path

      assert_response :success
      assert_select ".transaction-entry-titlebar__heading h1", text: "Record Fuel Transaction"
      assert_select ".transaction-entry-titlebar__hint-toggle[data-bs-toggle='collapse'][data-bs-target='#transactionEntryHeadingHint'][aria-controls='transactionEntryHeadingHint']", 1
      assert_select "#transactionEntryHeadingHint.collapse .transaction-entry-titlebar__hint-card", text: /Find the customer for this visit using a phone number or vehicle number/
      assert_select "#transactionEntryTabs"
      assert_select "#transaction-phone-tab[data-lookup-tab-focus-target='phone'][data-lookup-tab-description='Find the customer first, then choose a vehicle.']", 1
      assert_select "#transaction-vehicle-tab[data-lookup-tab-focus-target='vehicle'][data-lookup-tab-description='Match the vehicle plate to the right customer profile.']", 1
      assert_select ".transaction-entry-tabs__meta", 0
      assert_select "[data-lookup-tab-description-target]", text: "Match the vehicle plate to the right customer profile."
      assert_select "#transaction-phone-pane form[action='#{staff_transactions_path}']"
      assert_select "#transaction-vehicle-pane form[action='#{staff_transactions_path}']"
      assert_select "#transaction-phone-pane .transaction-entry-titlebar__heading h2", text: "Lookup by Phone"
      assert_select "#transaction-phone-pane .transaction-entry-titlebar__hint-toggle[data-bs-toggle='collapse'][data-bs-target='#transactionPhoneLookupHint'][aria-controls='transactionPhoneLookupHint']", 1
      assert_select "#transactionPhoneLookupHint.collapse .transaction-entry-titlebar__hint-card", text: /Enter the customer's phone number to load the profile.*Customer must already exist/m
      assert_select "#transaction-phone-pane .form-text", text: /Customer must already exist/, count: 0
      assert_select "#transaction-vehicle-pane .transaction-entry-titlebar__heading h2", text: "Lookup by Vehicle"
      assert_select "#transaction-vehicle-pane .transaction-entry-titlebar__hint-toggle[data-bs-toggle='collapse'][data-bs-target='#transactionVehicleLookupHint'][aria-controls='transactionVehicleLookupHint']", 1
      assert_select "#transactionVehicleLookupHint.collapse .transaction-entry-titlebar__hint-card", text: /Enter the vehicle number to find the customer/
      assert_select "input[name='transaction[lookup_mode]'][value='phone']", 1
      assert_select "input[name='transaction[lookup_mode]'][value='vehicle']", 1
      assert_select "#transaction-vehicle-tab.active[aria-selected='true']"
      assert_select "#transaction-vehicle-pane.show.active"
      assert_select "#transaction-phone-tab:not(.active)[aria-selected='false']"
      assert_select "#transaction-phone-pane input[name='transaction[phone_number]'].transaction-entry-lookup-input[data-lookup-focus-input='phone']"
      assert_select "#transaction-phone-pane .transaction-entry-lookup-prefix", text: "+91"
      assert_select "#transaction-vehicle-pane input[name='transaction[vehicle_number]'].transaction-entry-lookup-input[data-lookup-focus-input='vehicle']"
      assert_select "#transaction-vehicle-pane input[name='transaction[vehicle_number]'].transaction-entry-lookup-input[autofocus]", 1
      assert_select "[data-transaction-phone-root]"
      assert_select "[data-transaction-vehicle-root]"
      assert_select "[data-customer-placeholder]", minimum: 2
      assert_select "[data-customer-panel].d-none", minimum: 2
      assert_select "[data-customer-points]", minimum: 2
      assert_select "[data-customer-note]", minimum: 2
      assert_select "[data-customer-vehicles-count]", minimum: 2
      assert_select "[data-customer-selected-vehicle]", minimum: 2
      assert_select "[data-customer-vehicles-list]", minimum: 2
      assert_select ".transaction-customer-error[data-customer-error]", minimum: 2
      assert_select "#transactionAddCustomerModal[data-transaction-registration-modal]"
      assert_select "#transactionAddCustomerModal form[action='#{register_customer_staff_transactions_path}']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[lookup_mode]']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[phone_number]']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[vehicle_number]']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[fuel_amount]']"
      assert_select "[data-push-opt-in-panel]", 0
      assert_select "a.nav-link[href='#{staff_notifications_path}']", text: /Notifications/
      assert_match(/data-transaction-phone-root.*data-customer-error.*Lookup by Phone/m, response.body)
      assert_match(/data-transaction-vehicle-root.*data-customer-error.*Lookup by Vehicle/m, response.body)
      assert_includes response.body, "registerCustomerPath: payload.register_customer_path"
      assert_includes response.body, "registrationModal.openNow(registrationPayload)"
      assert_includes response.body, "shown.bs.tab"
      assert_includes response.body, "event.relatedTarget === vehicleSelect || suppressVehicleSelectBlurLookup"
      assert_includes response.body, "event.relatedTarget === matchSelect || suppressMatchSelectBlurLookup"
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

    test "returns register customer link when a vehicle number is not found" do
      sign_in users(:two)

      get lookup_staff_transactions_path, params: { vehicle_number: "TN 99 AB 9999" }, as: :json

      assert_response :not_found
      payload = JSON.parse(response.body)

      assert_equal false, payload["found"]
      assert_equal "No customer was found for that vehicle number.", payload["message"]
      assert_equal new_staff_customer_path(vehicle_number: "TN99AB9999"), payload["register_customer_path"]
    end

    test "staff can register a customer from vehicle lookup and return to transaction entry" do
      sign_in users(:two)

      assert_difference -> { Customer.count }, 1 do
        assert_difference -> { Vehicle.count }, 1 do
          post register_customer_staff_transactions_path, params: {
            customer: {
              name: "Lookup Driver",
              phone_number: "98888 77777",
              vehicle_number: "TN 30 AB 1234",
              fuel_type: "petrol",
              vehicle_kind: "two_wheeler"
            },
            transaction_lookup: {
              lookup_mode: "vehicle",
              vehicle_number: "TN30AB1234",
              fuel_amount: "650"
            }
          }
        end
      end

      customer = Customer.find_by!(phone_number: "9888877777")
      vehicle = customer.vehicles.first

      assert_redirected_to new_staff_transaction_path(
        transaction: {
          lookup_mode: "vehicle",
          vehicle_number: vehicle.vehicle_number,
          vehicle_id: vehicle.id,
          fuel_amount: "650"
        }
      )
    end

    test "register customer failure re-renders transaction page and reopens modal" do
      sign_in users(:two)

      assert_no_difference -> { Customer.count } do
        post register_customer_staff_transactions_path, params: {
          customer: {
            name: "",
            phone_number: "123",
            vehicle_number: "TN 30 AB 1234",
            fuel_type: "",
            vehicle_kind: ""
          },
          transaction_lookup: {
            lookup_mode: "phone",
            phone_number: "1234567890",
            fuel_amount: "500"
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "#transactionAddCustomerModal[data-auto-open-modal='true']"
      assert_select "#transactionAddCustomerModal .alert.alert-danger"
      assert_select "#transactionAddCustomerModal input[name='customer[phone_number]'][value='123']"
      assert_select "#transaction-phone-pane.show.active"
      assert_select "#transaction-phone-pane input[name='transaction[phone_number]'][value='1234567890']"
    end
  end
end
