require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  test "staff can edit customer details" do
    sign_in users(:two)

    get edit_customer_path(customers(:one))
    assert_response :success

    patch customer_path(customers(:one)), params: {
      customer: {
        name: "Arun Kumar",
        phone_number: "90000 00011"
      }
    }

    assert_redirected_to customer_path(customers(:one))
    assert_equal "Arun Kumar", customers(:one).reload.name
    assert_equal "9000000011", customers(:one).reload.phone_number
  end

  test "staff customer page previews three ledger entries and lazy loads more in modal" do
    sign_in users(:two)
    customer = Customer.create!(name: "Ledger Customer", phone_number: "9000000099")

    12.times do |index|
      customer.points_ledgers.create!(
        points: index + 1,
        entry_type: :earn,
        created_at: Time.current + index.minutes
      )
    end

    get customer_path(customer)
    assert_response :success
    assert_select ".customer-details-ledger-item", 3
    assert_select "[data-bs-target='#pointsLedgerModal']"
    assert_select "[data-points-ledger-panel][data-points-ledger-url='#{points_ledger_customer_path(customer, page: 1)}']"

    get points_ledger_customer_path(customer, page: 1)
    assert_response :success
    assert_select ".customer-details-ledger-item", 5
    assert_match "Showing <strong>1-5</strong> of <strong>9</strong> more entries", response.body

    get points_ledger_customer_path(customer, page: 2)
    assert_response :success
    assert_select ".customer-details-ledger-item", 4
    assert_match "Showing <strong>6-9</strong> of <strong>9</strong> more entries", response.body
  end

  test "staff customer page uses the compact customer actions menu" do
    sign_in users(:two)

    get customer_path(customers(:one))
    assert_response :success
    assert_select ".customer-details-hero__menu .customer-details-vehicle-row__menu-toggle", 1
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Edit Customer"
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Mark Inactive"
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Delete Customer", count: 0
    assert_select "#editCustomerModal"
  end

  test "staff update failure re-renders customer page and reopens edit modal" do
    sign_in users(:two)

    patch customer_path(customers(:one)), params: {
      customer: {
        name: "",
        phone_number: "123"
      }
    }

    assert_response :unprocessable_entity
    assert_select "#editCustomerModal[data-auto-open-modal='true']"
    assert_select "#editCustomerModal .alert.alert-danger"
  end

  test "staff customer page previews three transactions and lazy loads more in modal" do
    sign_in users(:two)
    customer = Customer.create!(name: "Transaction Customer", phone_number: "9000000077")
    user = users(:two)
    vehicle = customer.vehicles.create!(vehicle_number: "TN01AB1234", fuel_type: :petrol, vehicle_kind: :lmv)

    8.times do |index|
      customer.transactions.create!(
        user:,
        vehicle:,
        fuel_amount: 100 + index,
        created_at: Time.current + index.minutes
      )
    end

    get customer_path(customer)
    assert_response :success
    assert_select ".customer-details-history-row", 3
    assert_select "[data-bs-target='#transactionHistoryModal']"
    assert_select "[data-transaction-history-panel][data-transaction-history-url='#{transaction_history_customer_path(customer, page: 1)}']"

    get transaction_history_customer_path(customer, page: 1)
    assert_response :success
    assert_select ".customer-details-history-row", 5
    assert_match "Showing <strong>1-5</strong> of <strong>5</strong> more transactions", response.body
  end
end
