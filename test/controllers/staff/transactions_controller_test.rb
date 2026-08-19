require "test_helper"

module Staff
  class TransactionsControllerTest < ActionDispatch::IntegrationTest
    test "renders separate phone and vehicle transaction forms" do
      sign_in users(:two)

      get new_staff_transaction_path

      assert_response :success
      assert_select "#topbar button.btn-icon[aria-label='Scan Vehicle Plate'][data-topbar-plate-scanner-toggle]", 1
      assert_select "#topbar a.btn-icon[href='#{new_staff_transaction_path}'][aria-label='New Entry']", 1
      assert_select "#topbar a.btn-icon[href='#{new_loyalty_path}'][aria-label='Loyalty Lookup']", 1
      assert_select ".transaction-entry-titlebar__heading h1", text: "Record Fuel Transaction"
      assert_select ".transaction-entry-titlebar__hint-toggle[data-bs-toggle='collapse'][data-bs-target='#transactionEntryHeadingHint'][aria-controls='transactionEntryHeadingHint']", 1
      assert_select "#transactionEntryHeadingHint.collapse .transaction-entry-titlebar__hint-card [data-lookup-tab-description-target]", text: "Match the vehicle plate to the right customer profile."
      assert_select "#transactionEntryTabs"
      assert_select "#transaction-phone-tab[data-lookup-tab-focus-target='phone'][data-lookup-tab-description='Find the customer first, then choose a vehicle.']", 1
      assert_select "#transaction-vehicle-tab[data-lookup-tab-focus-target='vehicle'][data-lookup-tab-description='Match the vehicle plate to the right customer profile.']", 1
      assert_select ".transaction-entry-tabs__meta", 0
      assert_select ".transaction-entry-tabs__description", 0
      assert_select "#transaction-phone-pane form[action='#{staff_transactions_path}']"
      assert_select "#transaction-vehicle-pane form[action='#{staff_transactions_path}']"
      assert_select ".transaction-pump-card", 2
      assert_select ".transaction-pump-card .transaction-entry-titlebar__heading h2.h4", text: "My Pump", count: 2
      assert_select ".transaction-pump-card__pump-value", text: "Pump 1", count: 2
      assert_select ".transaction-pump-card__nozzles", 2
      assert_select ".transaction-pump-card__nozzle-option[data-transaction-nozzle-option]", minimum: 4
      assert_select ".transaction-pump-card__nozzle", minimum: 4
      assert_select "input.transaction-pump-card__nozzle-input[type='radio'][name='transaction[fuel_pump_nozzle_id]'][value='#{fuel_pump_nozzles(:one).id}']", 2
      assert_select "input.transaction-pump-card__nozzle-input[type='radio'][name='transaction[fuel_pump_nozzle_id]'][value='#{fuel_pump_nozzles(:two).id}']", 2
      assert_select "input.transaction-pump-card__nozzle-input[data-nozzle-fuel-type='petrol'][value='#{fuel_pump_nozzles(:one).id}']", 2
      assert_select "input.transaction-pump-card__nozzle-input[data-nozzle-fuel-type='diesel'][value='#{fuel_pump_nozzles(:two).id}']", 2
      assert_select "input[type='radio'][name='transaction[payment_mode]'][value='cash'][checked='checked']", 2
      assert_select "input[type='radio'][name='transaction[payment_mode]'][value='credit']", 2
      assert_select "input#phone_transaction_transaction_payment_mode_cash + label[for='phone_transaction_transaction_payment_mode_cash']", text: "Cash", count: 1
      assert_select "input#phone_transaction_transaction_payment_mode_credit + label[for='phone_transaction_transaction_payment_mode_credit']", text: "Credit", count: 1
      assert_select "input#vehicle_transaction_transaction_payment_mode_cash + label[for='vehicle_transaction_transaction_payment_mode_cash']", text: "Cash", count: 1
      assert_select "input#vehicle_transaction_transaction_payment_mode_credit + label[for='vehicle_transaction_transaction_payment_mode_credit']", text: "Credit", count: 1
      assert_select "[data-transaction-nozzle-status]", 2
      # S-MYPUMP — staff can't reassign their own pump, so the edit link is
      # replaced by read-only text. Nozzle choice below stays: it's per-transaction.
      assert_select "a.transaction-pump-card__change-link[href='#{my_pump_path}']", count: 0
      assert_select ".transaction-pump-card__change-link .ti.ti-edit", count: 0
      assert_select ".transaction-pump-card [data-transaction-pump-assigned-note]", text: "Assigned by your manager", count: 2
      assert_select ".transaction-pump-card .transaction-entry-titlebar__hint-toggle[data-bs-toggle='collapse'][data-bs-target='#phone_transaction_pump_hint'][aria-controls='phone_transaction_pump_hint'][aria-label='Show My Pump help']", 1
      assert_select ".transaction-pump-card .transaction-entry-titlebar__hint-toggle[data-bs-toggle='collapse'][data-bs-target='#vehicle_transaction_pump_hint'][aria-controls='vehicle_transaction_pump_hint'][aria-label='Show My Pump help']", 1
      assert_select "#phone_transaction_pump_hint.collapse .transaction-entry-titlebar__hint-card", text: /Your pump is assigned by your manager/
      assert_select "#vehicle_transaction_pump_hint.collapse .transaction-entry-titlebar__hint-card", text: /Your pump is assigned by your manager/
      assert_select "#transaction-phone-pane [data-transaction-step-section='lookup'] .transaction-entry-step-card__title-row h2", text: "Lookup by Phone"
      assert_select "#transaction-phone-pane .transaction-entry-titlebar__hint-toggle[data-bs-toggle='collapse'][data-bs-target='#transactionPhoneLookupHint'][aria-controls='transactionPhoneLookupHint']", 1
      assert_select "#transactionPhoneLookupHint.collapse .transaction-entry-titlebar__hint-card", text: /Enter the customer's phone number to load the profile.*Customer must already exist/m
      assert_select "#transaction-phone-pane .form-text", text: /Customer must already exist/, count: 0
      assert_select "#transaction-vehicle-pane [data-transaction-step-section='lookup'] .transaction-entry-step-card__title-row h2", text: "Lookup by Vehicle"
      assert_select "#transaction-vehicle-pane .transaction-entry-titlebar__hint-toggle[data-bs-toggle='collapse'][data-bs-target='#transactionVehicleLookupHint'][aria-controls='transactionVehicleLookupHint']", 1
      assert_select "#transactionVehicleLookupHint.collapse .transaction-entry-titlebar__hint-card", text: /Scan or enter the vehicle number to find the customer/
      assert_select "#transaction-vehicle-pane [data-transaction-step-section='review'] .transaction-entry-step-card__header-actions [data-transaction-register-customer-trigger][aria-label='Add Customer']", 1
      assert_select "[data-plate-scanner-root][data-auto-open='false'][data-recognize-url='#{recognize_plate_staff_transactions_path}']", 1
      assert_select "[data-plate-scanner-root][data-server-recognizer-available]", 1
      assert_select ".transaction-plate-scanner__field-header .transaction-entry-titlebar__hint-toggle[data-bs-toggle='collapse'][data-bs-target='#transactionVehicleNumberFieldHint'][aria-controls='transactionVehicleNumberFieldHint']", 1
      assert_select "#transactionVehicleNumberFieldHint.collapse .transaction-entry-titlebar__hint-card", text: /Use the full vehicle number as printed on the plate, or capture it with the camera\./
      assert_select "button.transaction-plate-scanner__toggle[data-plate-scanner-open][aria-controls='transactionPlateScannerPanel']", 0
      assert_select "input[name='transaction[vehicle_number]'][data-plate-scanner-input='true'][data-vehicle-number-input='true']", 1
      assert_select "button[data-plate-scanner-start]", text: /Live Preview/
      assert_select "input[type='file'][data-plate-scanner-file-input][accept='image/*'][capture='environment']", 1
      assert_select "button[data-plate-scanner-file-trigger]", text: /Open Camera/
      assert_select ".transaction-plate-scanner__result.d-none[data-plate-scanner-result]", 1
      assert_select "[data-plate-scanner-cleaned]", 1
      assert_select "[data-plate-scanner-note]", 1
      assert_select "[data-plate-scanner-raw]", 1
      assert_select "[data-plate-scanner-confidence]", 1
      assert_select "#transactionPlateScannerPanel.transaction-plate-scanner[hidden][data-plate-scanner-panel]", 1
      assert_select "[data-plate-scanner-video]", 1
      assert_select "canvas[data-plate-scanner-canvas][hidden]", 1
      assert_select "[data-plate-scanner-guide]", 1
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
      assert_select "#transactionAddCustomerModal[data-customer-lookup-url='#{lookup_staff_customers_path}']"
      assert_select "#transactionAddCustomerModal form[action='#{register_customer_staff_transactions_path}']"
      assert_select "#transactionAddCustomerModal [data-transaction-registration-existing-customer].d-none"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[lookup_mode]']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[phone_number]']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[vehicle_number]']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[fuel_amount]']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[fuel_pump_id]']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[fuel_pump_nozzle_id]']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[payment_mode]'][value='cash']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[lock_vehicle_details]'][value='0']"
      assert_select "#transactionAddCustomerModal input[name='customer[vehicle_number]'][required]"
      assert_select "#transactionAddCustomerModal input[type='radio'][name='customer[fuel_type]'][value='petrol']", 1
      assert_select "#transactionAddCustomerModal input[type='radio'][name='customer[fuel_type]'][value='petrol'][required]"
      assert_select "#transactionAddCustomerModal input[type='radio'][name='customer[vehicle_kind]'][value='two_wheeler'][required]"
      assert_select "#transactionAddCustomerModal [data-commercial-vehicle-fields].d-none", 1
      assert_select "#transactionAddCustomerModal input[name='customer[commercial_company_name]']", 1
      assert_select "#transactionAddCustomerModal input[name='customer[commercial_contact_name]']", 1
      assert_select "#transactionAddCustomerModal input[name='customer[commercial_contact_phone_number]'][data-phone-number-field='true']", 1
      assert_select "#transactionAddCustomerModal textarea[name='customer[commercial_address]']", 1
      assert_select "#transactionAddCustomerModal textarea[name='customer[commercial_notes]']", 1
      assert_select "#transactionAddCustomerModal select[name='customer[fuel_type]']", 0
      assert_select "[data-push-opt-in-panel]", 0
      assert_select "a.nav-link[href='#{staff_notifications_path}']", text: /Notifications/
      assert_match(/data-transaction-phone-root.*data-customer-error.*Lookup by Phone/m, response.body)
      assert_match(/data-transaction-vehicle-root.*data-customer-error.*Lookup by Vehicle/m, response.body)
      assert_match(/vehicle_plate_scanner(?:-[^"]+)?\.js/, response.body)
      assert_includes response.body, "registerCustomerPath: payload.register_customer_path"
      assert_includes response.body, "registrationModal.openNow(registrationPayload)"
      assert_includes response.body, "const bindTransactionNozzleOptions = (root, onChange) => {"
      assert_includes response.body, "fuelPumpId: selectedPumpInput()?.value || \"\""
      assert_includes response.body, "fuelPumpNozzleId: selectedNozzleInput()?.value || \"\""
      assert_includes response.body, "paymentMode: selectedPaymentMode()"
      assert_includes response.body, "lookupPaymentModeField"
      assert_includes response.body, "resolveExistingCustomerByPhone"
      assert_includes response.body, "This vehicle will be added to that customer."
      assert_includes response.body, "shown.bs.tab"
      assert_includes response.body, "const scannerTopbarTogglePendingActive = () => {"
      assert_includes response.body, "if (scannerTopbarTogglePendingActive()) return true;"
      assert_includes response.body, "return targetKey === \"vehicle\" && vehicleScannerFocusLockActive();"
      assert_includes response.body, "event.relatedTarget === vehicleSelect || suppressVehicleSelectBlurLookup"
      assert_includes response.body, "event.relatedTarget === matchSelect || suppressMatchSelectBlurLookup"

      phone_fuel_amount_index = response.body.index('id="phone_transaction_transaction_fuel_amount"')
      phone_pump_hint_index = response.body.index('id="phone_transaction_pump_hint"')
      vehicle_fuel_amount_index = response.body.index('id="vehicle_transaction_transaction_fuel_amount"')
      vehicle_pump_hint_index = response.body.index('id="vehicle_transaction_pump_hint"')

      refute_nil phone_fuel_amount_index
      refute_nil phone_pump_hint_index
      refute_nil vehicle_fuel_amount_index
      refute_nil vehicle_pump_hint_index
      assert_operator phone_fuel_amount_index, :<, phone_pump_hint_index
      assert_operator vehicle_fuel_amount_index, :<, vehicle_pump_hint_index
    end

    test "renders pump selection instead of nozzles when nozzle feature is disabled" do
      RewardSetting.current.update!(nozzle_feature_enabled: false)
      sign_in users(:two)

      get new_staff_transaction_path

      assert_response :success
      assert_select ".transaction-pump-card[data-transaction-pump-mode='pump']", 2
      assert_select ".transaction-pump-card .transaction-entry-titlebar__heading h2.h4", text: "Pump", count: 2
      assert_select "input.transaction-pump-card__nozzle-input[type='radio'][name='transaction[fuel_pump_id]'][data-transaction-pump-input]", 2
      assert_select "input.transaction-pump-card__nozzle-input[type='radio'][name='transaction[fuel_pump_nozzle_id]']", 0
      assert_select "a.transaction-pump-card__change-link[href='#{my_pump_path}']", 0
      assert_select "[data-transaction-pump-assigned-note]", 0
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[fuel_pump_id]']", 1
    end

    # S-MYPUMP applies to staff only — an admin may still reassign their own pump.
    test "admins keep the change my pump link on the transaction form" do
      sign_in users(:one)

      get new_staff_transaction_path

      assert_response :success
      assert_select "a.transaction-pump-card__change-link[href='#{my_pump_path}'][aria-label='Change My Pump']", minimum: 1
      assert_select "[data-transaction-pump-assigned-note]", 0
    end

    test "scanner shortcut auto opens the vehicle plate capture panel" do
      sign_in users(:two)

      get new_staff_transaction_path, params: { plate_scanner: "1" }

      assert_response :success
      assert_select "#transaction-vehicle-tab.active[aria-selected='true']", 1
      assert_select "#transaction-vehicle-pane.show.active", 1
      assert_select "[data-plate-scanner-root][data-auto-open='true']", 1
      assert_select "#transaction-vehicle-pane input[name='transaction[vehicle_number]'][autofocus]", 0
    end

    test "new transaction page restores vehicle lookup prefills from a customer vehicle link" do
      sign_in users(:two)

      get new_staff_transaction_path, params: {
        transaction: {
          lookup_mode: "vehicle",
          phone_number: customers(:one).phone_number,
          vehicle_number: vehicles(:one).vehicle_number,
          vehicle_id: vehicles(:one).id
        }
      }

      assert_response :success
      assert_select "#transaction-vehicle-tab.active[aria-selected='true']"
      assert_select "#transaction-vehicle-pane.show.active"
      assert_select "[data-transaction-vehicle-root][data-selected-vehicle-id='#{vehicles(:one).id}']"
      assert_select "#transaction-vehicle-pane input[name='transaction[vehicle_number]'][value='#{vehicles(:one).vehicle_number}']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[lookup_mode]'][value='vehicle']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[phone_number]'][value='#{customers(:one).phone_number}']"
      assert_select "#transactionAddCustomerModal input[name='transaction_lookup[vehicle_number]'][value='#{vehicles(:one).vehicle_number}']"
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
      assert_equal vehicles(:one).fuel_type, payload["matches"].first["fuel_type_code"]
      assert_equal vehicles(:one).vehicle_kind, payload["matches"].first["vehicle_kind_code"]
      assert_equal customers(:one).phone_number, payload["matches"].first.dig("customer", "phone_number")
    end

    test "recognizes a vehicle plate through the server-side service" do
      sign_in users(:two)

      original_call = VehiclePlateRecognizer.method(:call)
      VehiclePlateRecognizer.singleton_class.define_method(:call) do |image_data:|
        raise "unexpected image data" unless image_data.match?(%r{\Adata:image/jpeg;base64,})
        VehiclePlateRecognizer::Result.new(
          found: true,
          plate: "TN01AA1234",
          raw: "TN01AA1234",
          confidence: 94,
          valid: true,
          corrected: false,
          provider: "plate_recognizer",
          candidates: []
        )
      end

      post recognize_plate_staff_transactions_path,
        params: { plate_scan: { image_data: "data:image/jpeg;base64,ZmFrZQ==" } },
        as: :json

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal true, payload["found"]
      assert_equal "TN01AA1234", payload["plate"]
      assert_equal 94, payload["confidence"]
    ensure
      VehiclePlateRecognizer.singleton_class.define_method(:call, original_call)
    end

    test "returns service unavailable when the server-side recognizer is not configured" do
      sign_in users(:two)

      original_call = VehiclePlateRecognizer.method(:call)
      VehiclePlateRecognizer.singleton_class.define_method(:call) do |image_data:|
        raise "unexpected image data" unless image_data.match?(%r{\Adata:image/jpeg;base64,})
        raise VehiclePlateRecognizer::ConfigurationError, "Plate recognition service is not configured."
      end

      post recognize_plate_staff_transactions_path,
        params: { plate_scan: { image_data: "data:image/jpeg;base64,ZmFrZQ==" } },
        as: :json

      assert_response :service_unavailable
      payload = JSON.parse(response.body)
      assert_equal false, payload["found"]
      assert_equal "Plate recognition service is not configured.", payload["message"]
    ensure
      VehiclePlateRecognizer.singleton_class.define_method(:call, original_call)
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

    test "vehicle lookup follows the new-customer path immediately for a scanned plate" do
      sign_in users(:two)

      get new_staff_transaction_path

      assert_response :success
      # The plate scanner signals a committed capture via this event...
      assert_includes response.body, "vehicleNumberInput.addEventListener(\"vehicle-plate:scanned\", () => {"
      # ...which triggers a forced lookup flagged as scanner-originated...
      assert_includes response.body, "loadMatches({ force: true, viaScanner: true })"
      # ...so an unregistered scanned plate opens the registration modal right away,
      # while a typed plate still waits for the debounced auto-open.
      assert_includes response.body, "if (viaScanner) {"
      assert_includes response.body, "registrationModal.openNow(registrationPayload)"
      assert_includes response.body, "registrationModal.scheduleOpen(registrationPayload)"
    end

    test "plate scanner closes the camera and commits the plate once a number is recognized" do
      scanner_js = Rails.root.join("app/assets/javascripts/vehicle_plate_scanner.js").read

      # A recognized, valid plate closes the live camera so the lookup outcome is not
      # hidden behind the scanner...
      assert_includes scanner_js, "setPanelOpen(false);"
      # ...and dispatches the commit event the vehicle lookup listens for.
      assert_includes scanner_js, "input.dispatchEvent(new CustomEvent(\"vehicle-plate:scanned\", {"
    end

    test "staff can record a transaction and see earned plus current points below the customer balance" do
      sign_in users(:two)

      assert_difference -> { Transaction.count }, 1 do
        assert_difference -> { PointsLedger.count }, 1 do
          post staff_transactions_path, params: {
            transaction: {
              lookup_mode: "phone",
              phone_number: customers(:one).phone_number,
              vehicle_id: vehicles(:one).id,
              fuel_amount: "300",
              fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id
            }
          }
        end
      end

      assert_equal "cash", Transaction.order(:created_at).last.payment_mode
      assert_redirected_to customer_path(customers(:one))
      follow_redirect!

      assert_response :success
      assert_select ".customer-details-hero__transaction-summary-copy", text: /\+6 reward points added\.\s*Balance updated to 11\./
      assert_select ".alert.alert-success", 0
    end

    test "staff can record a transaction by selecting a pump when nozzle feature is disabled" do
      RewardSetting.current.update!(nozzle_feature_enabled: false)
      sign_in users(:two)

      assert_difference -> { Transaction.count }, 1 do
        assert_difference -> { PointsLedger.count }, 1 do
          post staff_transactions_path, params: {
            transaction: {
              lookup_mode: "phone",
              phone_number: customers(:one).phone_number,
              vehicle_id: vehicles(:one).id,
              fuel_amount: "300",
              fuel_pump_id: fuel_pumps(:one).id
            }
          }
        end
      end

      transaction = Transaction.order(:created_at).last
      assert_equal fuel_pumps(:one), transaction.fuel_pump
      assert_nil transaction.fuel_pump_nozzle
      assert_redirected_to customer_path(customers(:one))
    end

    test "one capture records both the transaction and the visit entry" do
      # Item 2 — New Transaction and Capture Visit are one screen now, so a
      # single submit feeds both the points ledger and the CRM / settlement
      # discount pipeline.
      Product.create!(name: "MS", category: "fuel", fuel_type_code: vehicles(:one).fuel_type,
                      pack_unit: "litre", mrp: 110, selling_price: 100)
      sign_in users(:two)

      assert_difference -> { Transaction.count }, 1 do
        assert_difference -> { VisitEntry.count }, 1 do
          post staff_transactions_path, params: {
            transaction: {
              lookup_mode: "phone",
              phone_number: customers(:one).phone_number,
              vehicle_id: vehicles(:one).id,
              fuel_amount: "500",
              discount_amount: "50",
              fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id,
              transport_name: "NL Roadways",
              driver_name: "Ravi",
              fleet_otp: "1"
            }
          }
        end
      end

      visit = VisitEntry.order(:id).last
      txn = Transaction.order(:id).last
      assert_equal txn.id, visit.transaction_id
      assert_equal vehicles(:one).vehicle_number, visit.vehicle_number
      assert_equal "NL Roadways", visit.transport_name
      assert visit.fleet_otp
      assert_equal BigDecimal("5"), visit.litres # ₹500 at the ₹100 catalog price
      assert_redirected_to customer_path(customers(:one))
    end

    test "with no catalog price the sale is still recorded and the skipped visit is explained" do
      sign_in users(:two)

      assert_difference -> { Transaction.count }, 1 do
        assert_no_difference -> { VisitEntry.count } do
          post staff_transactions_path, params: {
            transaction: {
              lookup_mode: "phone",
              phone_number: customers(:one).phone_number,
              vehicle_id: vehicles(:one).id,
              fuel_amount: "300",
              fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id
            }
          }
        end
      end

      assert_redirected_to customer_path(customers(:one))
      assert_match(/set the price in Products/i, flash[:alert])
    end

    test "staff can record a credit transaction" do
      sign_in users(:two)

      assert_difference -> { Transaction.count }, 1 do
        post staff_transactions_path, params: {
          transaction: {
            lookup_mode: "phone",
            phone_number: customers(:one).phone_number,
            vehicle_id: vehicles(:one).id,
            fuel_amount: "300",
            fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id,
            payment_mode: "credit"
          }
        }
      end

      assert_equal "credit", Transaction.order(:created_at).last.payment_mode
      assert_redirected_to customer_path(customers(:one))
    end

    test "staff can record a transaction while rewards are paused without adding points" do
      sign_in users(:two)
      customers(:one).update!(rewards_paused: true)

      assert_difference -> { Transaction.count }, 1 do
        assert_no_difference -> { PointsLedger.count } do
          post staff_transactions_path, params: {
            transaction: {
              lookup_mode: "phone",
              phone_number: customers(:one).phone_number,
              vehicle_id: vehicles(:one).id,
              fuel_amount: "300",
              fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id
            }
          }
        end
      end

      assert_redirected_to customer_path(customers(:one))
      follow_redirect!

      assert_response :success
      assert_select ".alert.alert-success", text: /Rewards are paused for this customer, so no points were added/
      assert_select ".customer-details-hero__transaction-summary-copy", count: 0
    end

    test "staff cannot record a transaction with a nozzle that does not match the selected vehicle fuel type" do
      sign_in users(:two)

      assert_no_difference -> { Transaction.count } do
        assert_no_difference -> { PointsLedger.count } do
          post staff_transactions_path, params: {
            transaction: {
              lookup_mode: "phone",
              phone_number: customers(:one).phone_number,
              vehicle_id: vehicles(:one).id,
              fuel_amount: "300",
              fuel_pump_nozzle_id: fuel_pump_nozzles(:two).id
            }
          }
        end
      end

      assert_response :unprocessable_entity
      assert_select ".transaction-entry-page-error", text: /Transaction could not be saved\..*Review the highlighted step in the transaction modal and try again\./m
      assert_select "[data-transaction-phone-root][data-transaction-error-step='fuel']"
      assert_select "#transaction-phone-pane [data-transaction-step-section='fuel'] .alert.alert-danger", text: /Fuel pump nozzle must match the selected vehicle's fuel type/
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
              fuel_amount: "650",
              fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id,
              payment_mode: "credit"
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
          fuel_amount: "650",
          fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id,
          payment_mode: "credit"
        }
      )
    end

    test "transaction add customer stores commercial vehicle details for commercial vehicle kinds" do
      sign_in users(:two)

      assert_difference -> { Customer.count }, 1 do
        assert_difference -> { Vehicle.count }, 1 do
          post register_customer_staff_transactions_path, params: {
            customer: {
              name: "Commercial Driver",
              phone_number: "95555 44444",
              vehicle_number: "TN 40 AB 1234",
              fuel_type: "diesel",
              vehicle_kind: "lcv",
              commercial_company_name: "Fast Freight",
              commercial_contact_name: "Selvam",
              commercial_contact_phone_number: "98888 77777",
              commercial_address: "Erode Yard",
              commercial_notes: "Invoice every Friday"
            },
            transaction_lookup: {
              lookup_mode: "vehicle",
              vehicle_number: "TN40AB1234",
              fuel_amount: "650",
              fuel_pump_nozzle_id: fuel_pump_nozzles(:two).id,
              payment_mode: "cash"
            }
          }
        end
      end

      customer = Customer.find_by!(phone_number: "9555544444")
      vehicle = customer.vehicles.first

      assert_equal "Fast Freight", vehicle.commercial_company_name
      assert_equal "Selvam", vehicle.commercial_contact_name
      assert_equal "9888877777", vehicle.commercial_contact_phone_number
      assert_equal "Erode Yard", vehicle.commercial_address
      assert_equal "Invoice every Friday", vehicle.commercial_notes
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
              fuel_amount: "500",
              fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id
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

    test "register customer requires initial vehicle details" do
      sign_in users(:two)

      assert_no_difference -> { Customer.count } do
        post register_customer_staff_transactions_path, params: {
          customer: {
            name: "Lookup Driver",
            phone_number: "9888877777",
            vehicle_number: "",
            fuel_type: "",
            vehicle_kind: ""
          },
          transaction_lookup: {
            lookup_mode: "vehicle",
            vehicle_number: "TN30AB1234",
            fuel_amount: "500",
            fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "#transactionAddCustomerModal[data-auto-open-modal='true']"
      assert_select "#transactionAddCustomerModal .alert.alert-danger", text: /Vehicle number can't be blank/
      assert_select "#transactionAddCustomerModal .alert.alert-danger", text: /Fuel type can't be blank/
      assert_select "#transactionAddCustomerModal .alert.alert-danger", text: /Vehicle kind can't be blank/
    end

    test "transaction add customer can attach a new vehicle to an existing customer" do
      sign_in users(:two)
      existing_customer = customers(:one)

      assert_no_difference -> { Customer.count } do
        assert_difference -> { Vehicle.count }, 1 do
        post register_customer_staff_transactions_path, params: {
          customer: {
            name: "Changed Name",
            phone_number: existing_customer.phone_number,
            vehicle_number: "TN 66 AB 1234",
            fuel_type: "petrol",
            vehicle_kind: "two_wheeler"
          },
          transaction_lookup: {
            lookup_mode: "vehicle",
            vehicle_number: "TN66AB1234",
            fuel_amount: "500",
            fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id
          }
        }
        end
      end

      vehicle = existing_customer.vehicles.find_by!(vehicle_number: "TN66AB1234")

      assert_redirected_to new_staff_transaction_path(
        transaction: {
          lookup_mode: "vehicle",
          vehicle_number: vehicle.vehicle_number,
          vehicle_id: vehicle.id,
          fuel_amount: "500",
          fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id,
          payment_mode: "cash"
        }
      )
      assert_equal "Vehicle added to the existing customer. Continue recording the transaction.", flash[:notice]
      assert_equal "Arun", existing_customer.reload.name
    end
  end
end
