require "test_helper"

module Admin
  class CustomersControllerTest < ActionDispatch::IntegrationTest
    test "admin can view customer management screens" do
      sign_in users(:one)
      expected_transaction_path = new_staff_transaction_path(transaction: {
        lookup_mode: "vehicle",
        phone_number: customers(:one).phone_number,
        vehicle_number: vehicles(:one).vehicle_number,
        vehicle_id: vehicles(:one).id
      })

      get admin_customers_path
      assert_response :success
      assert_select "h1", text: "Customers"
      assert_select "button.admin-customers-create-action[data-bs-toggle='modal'][data-bs-target='#addCustomerModal'][aria-label='New Customer']", text: /\+ New/
      assert_select "form.admin-customers-filter__form[action='#{admin_customers_path}']"
      assert_select ".admin-customers-filter__input[placeholder='Search by name, phone, or vehicle']"
      assert_select ".dashboard-filter-chip", text: "All"
      assert_select ".dashboard-filter-chip", text: "Active"
      assert_select ".dashboard-filter-chip", text: "Inactive"
      assert_select ".dashboard-filter-chip", text: "Drive-In"
      assert_select ".dashboard-filter-chip", text: "Fleet/OTP"
      assert_select ".dashboard-filter-chip", text: "Credit"
      assert_select "#addCustomerModal"
      assert_select ".admin-customers-list"
      assert_select ".admin-customer-item", minimum: 2
      assert_select ".admin-customer-item__name", text: /Arun/
      assert_select ".admin-customer-item__phone", text: /\+91 9000000001/
      assert_select ".admin-customer-item__vehicles", text: /TN01AA1111/
      assert_select ".admin-customer-item__points", text: /5 pts/
      assert_select ".admin-customer-item__view[aria-label=?]", "View Arun"

      get new_admin_customer_path
      assert_response :success
      assert_select "input[name='customer[name]'][required]", 0
      assert_select "input[name='customer[vehicle_number]'][required]", 0
      assert_select "input[type='radio'][name='customer[fuel_type]'][value='petrol'][required]", 0
      assert_select "input[type='radio'][name='customer[vehicle_kind]'][value='two_wheeler']", 1
      assert_select "input[type='radio'][name='customer[vehicle_kind]'][value='two_wheeler'][required]", 0
      assert_select "select[name='customer[vehicle_kind]']", 0
      assert_select "[data-commercial-vehicle-fields].d-none", 1
      assert_select "input[name='customer[commercial_company_name]']", 1
      assert_select "input[name='customer[commercial_contact_name]']", 1
      assert_select "input[name='customer[commercial_contact_phone_number]'][data-phone-number-field='true']", 1
      assert_select "textarea[name='customer[commercial_address]']", 1
      assert_select "textarea[name='customer[commercial_notes]']", 1
      assert_select "button[data-cancel-back-button='true'][data-fallback-path='#{admin_customers_path}']", text: "Cancel"
      assert_includes response.body, "window.history.back()"

      get admin_customer_path(customers(:one))
      assert_response :success
      assert_select "a[href='#{new_staff_redemption_path(redemption: { phone_number: customers(:one).phone_number })}']", text: /Redeem Points/
      assert_select ".customer-details-vehicle-list.customer-details-vehicle-list--allow-overflow"
      assert_select ".customer-details-hero__menu .customer-details-vehicle-row__menu-toggle", 1
      assert_select "#editCustomerModal"
      assert_select ".customer-details-hero__menu .dropdown-item", text: "Pause Rewards"
      assert_select ".customer-details-hero__menu .dropdown-item", text: "Delete Customer"
      assert_select "form[action='#{admin_customer_path(customers(:one))}']"
      assert_select "a.customer-details-vehicle-row__transaction-link[aria-label=?][title=?][href=?]",
        "New transaction for #{vehicles(:one).vehicle_number}",
        "New transaction for #{vehicles(:one).vehicle_number}",
        expected_transaction_path,
        1
    end

    test "admin customer page shows the cash equivalent when cash reward is configured" do
      sign_in users(:one)
      RewardSetting.current.update!(cash_value_per_point: 0.5)

      get admin_customer_path(customers(:one))

      assert_response :success
      assert_select ".customer-details-hero__chip", text: /₹2\.50 cash value/
    end

    test "admin create failure re-renders index modal with errors" do
      sign_in users(:one)

      assert_no_difference -> { Customer.count } do
        post admin_customers_path, params: {
          customer: {
            name: "",
            phone_number: "123",
            vehicle_number: "TN 22 CD 1234",
            fuel_type: "",
            vehicle_kind: ""
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "#addCustomerModal[data-auto-open-modal='true']"
      assert_select "#addCustomerModal .alert.alert-danger"
      assert_select "#addCustomerModal .alert.alert-danger", text: /Phone number must be a 10 digit number/
    end

    test "admin can add a phone-only customer without vehicle details" do
      sign_in users(:one)

      assert_difference -> { Customer.count }, 1 do
        assert_no_difference -> { Vehicle.count } do
        post admin_customers_path, params: {
          customer: {
            name: "Suresh",
            phone_number: "91234 56789",
            vehicle_number: "",
            fuel_type: "",
            vehicle_kind: ""
          }
        }
        end
      end

      customer = Customer.find_by!(phone_number: "9123456789")
      assert_redirected_to admin_customer_path(customer)
      assert_empty customer.vehicles
    end

    test "admin can create a customer with an initial vehicle" do
      sign_in users(:one)

      assert_difference -> { Customer.count }, 1 do
        assert_difference -> { Vehicle.count }, 1 do
          post admin_customers_path, params: {
            customer: {
              name: "Suresh",
              phone_number: "91234 56789",
              vehicle_number: "TN 22 CD 1234",
              fuel_type: "petrol",
              vehicle_kind: "lmv"
            }
          }
        end
      end

      customer = Customer.find_by!(phone_number: "9123456789")
      assert_redirected_to admin_customer_path(customer)
      assert_equal "Suresh", customer.name
      assert customer.active?
      assert_equal "TN22CD1234", customer.vehicles.first.vehicle_number
    end

    test "admin can create a commercial customer vehicle with company details" do
      sign_in users(:one)

      assert_difference -> { Customer.count }, 1 do
        assert_difference -> { Vehicle.count }, 1 do
          post admin_customers_path, params: {
            customer: {
              name: "Fleet Owner",
              phone_number: "94444 33333",
              vehicle_number: "TN 98 AB 6789",
              fuel_type: "diesel",
              vehicle_kind: "mcv",
              commercial_company_name: "ACE Cargo",
              commercial_contact_name: "Dinesh",
              commercial_contact_phone_number: "91111 22222",
              commercial_address: "Madurai Ring Road",
              commercial_notes: "Regional cargo"
            }
          }
        end
      end

      customer = Customer.find_by!(phone_number: "9444433333")
      vehicle = customer.vehicles.first

      assert_redirected_to admin_customer_path(customer)
      assert_equal "ACE Cargo", vehicle.commercial_company_name
      assert_equal "Dinesh", vehicle.commercial_contact_name
      assert_equal "9111122222", vehicle.commercial_contact_phone_number
    end

    test "admin add customer does not update an existing customer with the same phone number" do
      sign_in users(:one)
      existing_customer = customers(:one)

      assert_no_difference -> { Customer.count } do
        post admin_customers_path, params: {
          customer: {
            name: "Changed Name",
            phone_number: existing_customer.phone_number,
            vehicle_number: "TN 55 AB 1234",
            fuel_type: "petrol",
            vehicle_kind: "lmv"
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "#addCustomerModal[data-auto-open-modal='true']"
      assert_select "#addCustomerModal .alert.alert-danger", text: /Phone number has already been taken/
      assert_equal "Arun", existing_customer.reload.name
      assert_not existing_customer.vehicles.exists?(vehicle_number: "TN55AB1234")
    end

    test "admin can update customer details" do
      sign_in users(:one)

      patch admin_customer_path(customers(:one)), params: {
        customer: {
          name: "Arun Kumar",
          phone_number: "90000 00011"
        }
      }

      assert_redirected_to admin_customer_path(customers(:one))
      assert_equal "Arun Kumar", customers(:one).reload.name
      assert_equal "9000000011", customers(:one).reload.phone_number
    end

    test "admin update failure re-renders customer page and reopens edit modal" do
      sign_in users(:one)

      patch admin_customer_path(customers(:one)), params: {
        customer: {
          name: "",
          phone_number: "123"
        }
      }

      assert_response :unprocessable_entity
      assert_select "#editCustomerModal[data-auto-open-modal='true']"
      assert_select "#editCustomerModal .alert.alert-danger"
    end

    test "admin can search customers by vehicle number without duplicate rows" do
      sign_in users(:one)

      get admin_customers_path, params: { q: "TN01AA111" }

      assert_response :success
      assert_select ".admin-customer-item", 1
      assert_select ".admin-customer-item__name", text: /Arun/
      assert_select ".admin-customer-item__name", text: /Meena/, count: 0
      assert_select ".dashboard-filter-chip.is-active", text: "All"
    end

    test "admin can filter customers by inactive status" do
      sign_in users(:one)
      Customer.create!(name: "Dormant", phone_number: "9000000099", active: false)

      get admin_customers_path, params: { status: "inactive" }

      assert_response :success
      assert_select ".admin-customer-item", 1
      assert_select ".admin-customer-item__name", text: /Dormant/
      assert_select ".admin-customer-item__status", text: "Inactive"
      assert_select ".dashboard-filter-chip.is-active", text: "Inactive"
      assert_select ".admin-customer-item__name", text: /Arun/, count: 0
    end

    test "admin can delete a customer without transaction history" do
      sign_in users(:one)
      customer = Customer.create!(name: "Disposable", phone_number: "9012345678")

      assert_difference -> { Customer.count }, -1 do
        delete admin_customer_path(customer)
      end

      assert_redirected_to admin_customers_path
    end

    test "staff cannot delete a customer" do
      sign_in users(:two)

      delete admin_customer_path(customers(:one))

      assert_redirected_to root_path
      assert Customer.exists?(customers(:one).id)
    end

    test "admin customer page keeps points ledger collapsed and loads the full ledger inline" do
      sign_in users(:one)
      RewardSetting.current.update!(cash_value_per_point: 0.5)
      customer = Customer.create!(name: "Admin Ledger", phone_number: "9000000088")

      12.times do |index|
        customer.points_ledgers.create!(
          points: index + 10,
          entry_type: :earn,
          created_at: Time.current + index.minutes
        )
      end

      get admin_customer_path(customer)
      assert_response :success
      assert_select "#pointsLedgerCollapse.collapse[data-points-ledger-collapse]"
      assert_select "[data-points-ledger-toggle][data-bs-target='#pointsLedgerCollapse'][aria-expanded='false']"
      assert_select "[data-points-ledger-panel][data-points-ledger-url='#{points_ledger_admin_customer_path(customer, page: 1)}']"
      assert_select ".customer-details-ledger-item", 0

      get points_ledger_admin_customer_path(customer, page: 1)
      assert_response :success
      assert_select ".customer-details-ledger-item", 5
      assert_select ".customer-details-ledger-item__cash", 5
      assert_match "Showing <strong>1-5</strong> of <strong>12</strong> entries", response.body

      get points_ledger_admin_customer_path(customer, page: 2)
      assert_response :success
      assert_select ".customer-details-ledger-item", 5
      assert_select ".customer-details-ledger-item__cash", 5
      assert_match "Showing <strong>6-10</strong> of <strong>12</strong> entries", response.body
    end

    test "admin can fetch paginated transaction history for a customer" do
      sign_in users(:one)
      RewardSetting.current.update!(cash_value_per_point: 0.5)
      customer = Customer.create!(name: "Admin Transactions", phone_number: "9000000066")
      vehicle = customer.vehicles.create!(vehicle_number: "TN02CD5678", fuel_type: :diesel, vehicle_kind: :lmv)

      10.times do |index|
        transaction = customer.transactions.create!(
          user: users(:one),
          vehicle:,
          fuel_amount: 200 + index,
          fuel_pump: fuel_pumps(:one),
          fuel_pump_nozzle: fuel_pump_nozzles(:two),
          created_at: Time.current + index.minutes
        )
        customer.points_ledgers.create!(fuel_transaction: transaction, points: index + 4, entry_type: :earn, created_at: transaction.created_at)
      end

      get admin_customer_path(customer)
      assert_response :success
      assert_select ".customer-details-history-row", 3
      assert_select ".customer-details-history-row__location", text: /Pump 1.*Nozzle 2.*Diesel/m, count: 3
      assert_select ".customer-details-history-row__reward-points", count: 3
      assert_select ".customer-details-history-row__reward-cash", count: 3
      assert_select "[data-transaction-history-panel][data-transaction-history-url='#{transaction_history_admin_customer_path(customer, page: 1)}']"

      get transaction_history_admin_customer_path(customer, page: 2)
      assert_response :success
      assert_select ".customer-details-history-row", 2
      assert_select ".customer-details-history-row__location", text: /Pump 1.*Nozzle 2.*Diesel/m, count: 2
      assert_select ".customer-details-history-row__reward-points", count: 2
      assert_select ".customer-details-history-row__reward-cash", count: 2
      assert_match "Showing <strong>6-7</strong> of <strong>7</strong> more transactions", response.body
    end

    test "admin can drill through to customers filtered by a dashboard period" do
      sign_in users(:one)
      recent = Customer.create!(name: "Recent Rita", phone_number: "9812300001")
      recent_vehicle = recent.vehicles.create!(vehicle_number: "TN01ZZ0001", fuel_type: :petrol, vehicle_kind: :two_wheeler)
      recent.transactions.create!(user: users(:two), vehicle: recent_vehicle, fuel_amount: 500, created_at: Time.current)

      stale = Customer.create!(name: "Stale Sam", phone_number: "9812300002")
      stale_vehicle = stale.vehicles.create!(vehicle_number: "TN01ZZ0002", fuel_type: :petrol, vehicle_kind: :two_wheeler)
      stale.transactions.create!(user: users(:two), vehicle: stale_vehicle, fuel_amount: 500, created_at: 40.days.ago)

      get admin_customers_path(preset: "today")

      assert_response :success
      assert_select "[data-customers-period-banner]"
      assert_match "Recent Rita", response.body
      assert_no_match(/Stale Sam/, response.body)
    end

    test "admin can filter customers by how much they have visited, filled, cost and earned" do
      sign_in users(:one)
      staff = users(:two)
      pump = fuel_pumps(:one)

      heavy = Customer.create!(name: "Heavy Hema", phone_number: "9444400001")
      heavy_vehicle = heavy.vehicles.create!(vehicle_number: "TN44HH0001", fuel_type: :petrol, vehicle_kind: :two_wheeler)
      3.times do |day|
        Transaction.create!(customer: heavy, user: staff, vehicle: heavy_vehicle, fuel_amount: 1000,
                            litres: 40, discount_amount: 30, created_at: Time.zone.local(2026, 7, 10 + day, 9, 0))
      end
      2.times { heavy.contact_logs.create!(user: staff, channel: "call", outcome: "reached", contacted_at: 2.days.ago) }
      heavy.points_ledgers.create!(entry_type: :earn, points: 400)

      light = Customer.create!(name: "Light Latha", phone_number: "9444400002")
      VisitEntry.create!(customer: light, user: staff, fuel_pump: pump, entry_date: Date.new(2026, 7, 10),
                         vehicle_number: "TN44LL0001", litres: 5, discount_amount: 1)

      get admin_customers_path

      assert_response :success
      assert_select ".admin-customers-filter__threshold input[name='min_visits']"
      assert_select ".admin-customers-filter__threshold input[name='min_litres']"
      assert_select ".admin-customers-filter__threshold input[name='min_contacts']"
      assert_select ".admin-customers-filter__threshold input[name='min_discount']"
      assert_select ".admin-customers-filter__threshold input[name='min_points']"
      assert_match "Heavy Hema", response.body
      assert_match "Light Latha", response.body

      { min_visits: 3, min_litres: 100, min_contacts: 2, min_discount: 80, min_points: 300 }.each do |filter, value|
        get admin_customers_path(filter => value)

        assert_response :success
        assert_match "Heavy Hema", response.body, "#{filter} should keep the customer above the threshold"
        assert_no_match(/Light Latha/, response.body, "#{filter} should drop the customer below the threshold")
      end
    end

    test "customer rows show the numbers the thresholds filter on" do
      sign_in users(:one)
      staff = users(:two)
      customer = Customer.create!(name: "Shown Shanti", phone_number: "9444400003")
      vehicle = customer.vehicles.create!(vehicle_number: "TN44SS0001", fuel_type: :petrol, vehicle_kind: :two_wheeler)
      Transaction.create!(customer: customer, user: staff, vehicle: vehicle, fuel_amount: 1000,
                          litres: 12.5, discount_amount: 20, created_at: Time.zone.local(2026, 7, 10, 9, 0))
      customer.points_ledgers.create!(entry_type: :redeem, points: -30, cash_reward_amount: 45)

      get admin_customers_path(q: "Shown")

      assert_response :success
      assert_select ".admin-customer-item__metrics", text: /1 visit/
      assert_select ".admin-customer-item__metrics", text: /12\.5 L/
      assert_select ".admin-customer-item__metrics", text: /₹20\.00 discount/
      assert_select ".admin-customer-item__metrics", text: /₹45\.00 gifts/
      assert_select ".admin-customer-item__metrics", text: /0 contacts/
    end

    test "threshold filters survive the quick-filter chips" do
      sign_in users(:one)

      get admin_customers_path(min_visits: 2, min_points: 10)

      assert_response :success
      assert_select "a.dashboard-filter-chip[href*='min_visits=2'][href*='min_points=10']", minimum: 3
    end

    test "an invalid threshold is ignored rather than emptying the list" do
      sign_in users(:one)

      get admin_customers_path(min_visits: "-5", min_litres: "not-a-number")

      assert_response :success
      assert_select ".admin-customer-item", minimum: 2
      assert_select "a.btn-outline-secondary", text: "Clear", count: 0
    end

    test "an absurdly large threshold is ignored rather than erroring the page" do
      sign_in users(:one)

      get admin_customers_path(min_visits: "9223372036854775808", min_points: "99999999999999999999")

      assert_response :success
      assert_select ".admin-customer-item", minimum: 2
    end

    test "a customer profile reports discount given and gifts given" do
      sign_in users(:one)
      staff = users(:two)
      customer = Customer.create!(name: "Profile Priya", phone_number: "9444400004")
      vehicle = customer.vehicles.create!(vehicle_number: "TN44PP0001", fuel_type: :petrol, vehicle_kind: :two_wheeler)
      Transaction.create!(customer: customer, user: staff, vehicle: vehicle, fuel_amount: 2000,
                          litres: 18.25, discount_amount: 60, created_at: Time.zone.local(2026, 7, 10, 9, 0))
      customer.points_ledgers.create!(entry_type: :redeem, points: -40, cash_reward_amount: 90)

      get admin_customer_path(customer)

      assert_response :success
      assert_select "[data-customer-metrics] [data-metric='litres']", text: /18\.25 L/
      assert_select "[data-customer-metrics] [data-metric='discount']", text: "₹60.00"
      assert_select "[data-customer-metrics] [data-metric='gifts']", text: "₹90.00"
      assert_select "[data-customer-lifetime-metrics]", count: 0
    end

    test "a period-filtered profile shows the period totals alongside the lifetime ones" do
      sign_in users(:one)
      staff = users(:two)
      customer = Customer.create!(name: "Period Padma", phone_number: "9444400005")
      vehicle = customer.vehicles.create!(vehicle_number: "TN44QQ0001", fuel_type: :petrol, vehicle_kind: :two_wheeler)
      Transaction.create!(customer: customer, user: staff, vehicle: vehicle, fuel_amount: 2000,
                          litres: 10, discount_amount: 25, created_at: Time.current)
      Transaction.create!(customer: customer, user: staff, vehicle: vehicle, fuel_amount: 2000,
                          litres: 90, discount_amount: 500, created_at: 60.days.ago)

      get admin_customer_path(customer, preset: "today")

      assert_response :success
      assert_select "[data-customer-metrics] [data-metric='discount']", text: "₹25.00"
      assert_select "[data-customer-lifetime-metrics]", text: /₹525\.00 discount/
    end

    test "admin can set a customer's account type and filter the list by it" do
      sign_in users(:one)
      fleet = Customer.create!(name: "Fleet Fred", phone_number: "9811120001", customer_type: "otp")
      Customer.create!(name: "Walkin Will", phone_number: "9811120002")

      patch admin_customer_path(fleet), params: { customer: { name: "Fleet Fred", phone_number: fleet.phone_number, customer_type: "credit" } }
      assert_redirected_to admin_customer_path(fleet)
      assert fleet.reload.credit?

      fleet.update!(customer_type: "otp")
      get admin_customers_path(type: "otp")
      assert_response :success
      assert_match "Fleet Fred", response.body
      assert_no_match(/Walkin Will/, response.body)
    end
  end
end
