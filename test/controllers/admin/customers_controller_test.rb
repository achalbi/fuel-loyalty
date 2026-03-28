require "test_helper"

module Admin
  class CustomersControllerTest < ActionDispatch::IntegrationTest
    test "admin can view customer management screens" do
      sign_in users(:one)

      get admin_customers_path
      assert_response :success
      assert_select "h1", text: "Customers"
      assert_select "button.admin-customers-create-action[data-bs-toggle='modal'][data-bs-target='#addCustomerModal'][aria-label='Add Customer']", text: /\+ Add Customer/
      assert_select "form.admin-customers-filter__form[action='#{admin_customers_path}']"
      assert_select ".admin-customers-filter__input[placeholder='Search by name, phone, or vehicle']"
      assert_select ".dashboard-filter-chip", text: "All"
      assert_select ".dashboard-filter-chip", text: "Active"
      assert_select ".dashboard-filter-chip", text: "Inactive"
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
      assert_select "button[data-cancel-back-button='true'][data-fallback-path='#{admin_customers_path}']", text: "Cancel"
      assert_includes response.body, "window.history.back()"

      get admin_customer_path(customers(:one))
      assert_response :success
      assert_select ".customer-details-vehicle-list.customer-details-vehicle-list--allow-overflow"
      assert_select ".customer-details-hero__menu .customer-details-vehicle-row__menu-toggle", 1
      assert_select "#editCustomerModal"
      assert_select ".customer-details-hero__menu .dropdown-item", text: "Delete Customer"
      assert_select "form[action='#{admin_customer_path(customers(:one))}']"
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

    test "admin can preview three ledger entries and fetch more in modal" do
      sign_in users(:one)
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
      assert_select ".customer-details-ledger-item", 3
      assert_select "[data-bs-target='#pointsLedgerModal']"
      assert_select "[data-points-ledger-panel][data-points-ledger-url='#{points_ledger_admin_customer_path(customer, page: 1)}']"

      get points_ledger_admin_customer_path(customer, page: 2)
      assert_response :success
      assert_select ".customer-details-ledger-item", 4
      assert_match "Showing <strong>6-9</strong> of <strong>9</strong> more entries", response.body
    end

    test "admin can fetch paginated transaction history for a customer" do
      sign_in users(:one)
      customer = Customer.create!(name: "Admin Transactions", phone_number: "9000000066")
      vehicle = customer.vehicles.create!(vehicle_number: "TN02CD5678", fuel_type: :diesel, vehicle_kind: :lmv)

      10.times do |index|
        customer.transactions.create!(
          user: users(:one),
          vehicle:,
          fuel_amount: 200 + index,
          created_at: Time.current + index.minutes
        )
      end

      get admin_customer_path(customer)
      assert_response :success
      assert_select ".customer-details-history-row", 3
      assert_select "[data-transaction-history-panel][data-transaction-history-url='#{transaction_history_admin_customer_path(customer, page: 1)}']"

      get transaction_history_admin_customer_path(customer, page: 2)
      assert_response :success
      assert_select ".customer-details-history-row", 2
      assert_match "Showing <strong>6-7</strong> of <strong>7</strong> more transactions", response.body
    end
  end
end
