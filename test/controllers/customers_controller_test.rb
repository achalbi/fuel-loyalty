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

  test "staff can set the account type and transport fields" do
    sign_in users(:two)
    customer = customers(:one)

    patch customer_path(customer), params: {
      customer: {
        name: customer.name,
        phone_number: customer.phone_number,
        customer_type: "otp",
        transport_name: "Ace Transport",
        approx_vehicle_count: 12
      }
    }

    assert_redirected_to customer_path(customer)
    customer.reload
    assert_equal "otp", customer.customer_type
    assert_equal "Ace Transport", customer.transport_name
    assert_equal 12, customer.approx_vehicle_count
  end

  test "staff can set marketing opt-ins" do
    sign_in users(:two)
    customer = customers(:one)
    patch customer_path(customer), params: {
      customer: { name: customer.name, phone_number: customer.phone_number, whatsapp_opt_in: "1", sms_opt_in: "1" },
    }
    customer.reload
    assert customer.whatsapp_opt_in?
    assert customer.sms_opt_in?
  end

  test "staff can add contacts via nested attributes and blanks are dropped" do
    sign_in users(:two)
    customer = customers(:one)

    patch customer_path(customer), params: {
      customer: {
        name: customer.name,
        phone_number: customer.phone_number,
        customer_contacts_attributes: {
          "0" => { role: "driver", name: "Ravi", phone_number: "9000011122", contacted: "1" },
          "1" => { role: "owner", name: "", phone_number: "" }
        }
      }
    }

    assert_redirected_to customer_path(customer)
    contacts = customer.reload.customer_contacts
    assert_equal 1, contacts.count, "the all-blank owner row should be rejected"
    contact = contacts.first
    assert_equal "driver", contact.role
    assert_equal "Ravi", contact.name
    assert contact.contacted?
    assert_not_nil contact.contacted_at
  end

  test "rejects two contacts sharing a phone with a 422 instead of a 500" do
    sign_in users(:two)
    customer = customers(:one)

    assert_no_difference -> { customer.customer_contacts.count } do
      patch customer_path(customer), params: {
        customer: {
          name: customer.name,
          phone_number: customer.phone_number,
          customer_contacts_attributes: {
            "0" => { role: "driver", name: "A", phone_number: "9000012345" },
            "1" => { role: "owner", name: "B", phone_number: "9000012345" }
          }
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "staff can remove a customer contact via _destroy" do
    sign_in users(:two)
    customer = customers(:one)
    contact = customer.customer_contacts.create!(role: "driver", name: "Ravi", phone_number: "9000011122")

    patch customer_path(customer), params: {
      customer: {
        name: customer.name,
        phone_number: customer.phone_number,
        customer_contacts_attributes: { "0" => { id: contact.id, _destroy: "1" } }
      }
    }

    assert_redirected_to customer_path(customer)
    assert_equal 0, customer.reload.customer_contacts.count
  end

  test "staff customer page shows the account type chip and contacts" do
    sign_in users(:two)
    customer = customers(:one)
    customer.update!(customer_type: "otp")
    customer.customer_contacts.create!(role: "driver", name: "Ravi", phone_number: "9000011122", contacted: true)

    get customer_path(customer)

    assert_response :success
    assert_select ".customer-details-hero__chip", text: "OTP / Fleet"
    assert_select ".customer-details-section h2", text: "Contacts"
    assert_select ".customer-details-vehicle-row__number", text: /Ravi/
  end

  test "staff customer page keeps points ledger collapsed and loads the full ledger inline" do
    sign_in users(:two)
    RewardSetting.current.update!(cash_value_per_point: 0.5)
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
    assert_select "#pointsLedgerCollapse.collapse[data-points-ledger-collapse]"
    assert_select "[data-points-ledger-toggle][data-bs-target='#pointsLedgerCollapse'][aria-expanded='false']"
    assert_select "[data-points-ledger-panel][data-points-ledger-url='#{points_ledger_customer_path(customer, page: 1)}']"
    assert_select ".customer-details-ledger-item", 0

    get points_ledger_customer_path(customer, page: 1)
    assert_response :success
    assert_select ".customer-details-ledger-item", 5
    assert_select ".customer-details-ledger-item__cash", 5
    assert_match "Showing <strong>1-5</strong> of <strong>12</strong> entries", response.body

    get points_ledger_customer_path(customer, page: 2)
    assert_response :success
    assert_select ".customer-details-ledger-item", 5
    assert_select ".customer-details-ledger-item__cash", 5
    assert_match "Showing <strong>6-10</strong> of <strong>12</strong> entries", response.body
  end

  test "staff customer page shows recorded cash values even after the reward setting changes" do
    sign_in users(:two)
    RewardSetting.current.update!(cash_value_per_point: 0.5)
    customer = Customer.create!(name: "Frozen Ledger Customer", phone_number: "9000000100")
    customer.points_ledgers.create!(points: 10, entry_type: :earn)
    RewardSetting.current.update!(cash_value_per_point: 1.0)

    get points_ledger_customer_path(customer, page: 1)

    assert_response :success
    assert_select ".customer-details-ledger-item__cash", text: /₹5\.00/
    assert_select ".customer-details-ledger-item__cash", text: /₹10\.00/, count: 0
  end

  test "staff customer page uses the compact customer actions menu" do
    sign_in users(:two)
    expected_transaction_path = new_staff_transaction_path(transaction: {
      lookup_mode: "vehicle",
      phone_number: customers(:one).phone_number,
      vehicle_number: vehicles(:one).vehicle_number,
      vehicle_id: vehicles(:one).id
    })

    get customer_path(customers(:one))
    assert_response :success
    assert_select "a[href='#{new_staff_redemption_path(redemption: { phone_number: customers(:one).phone_number })}']", text: /Redeem Points/
    assert_select ".customer-details-vehicle-list.customer-details-vehicle-list--allow-overflow"
    assert_select ".customer-details-hero__menu .customer-details-vehicle-row__menu-toggle", 1
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Edit Customer"
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Mark Inactive"
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Pause Rewards", count: 0
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Delete Customer", count: 0
    assert_select "#editCustomerModal"
    assert_select "a.customer-details-vehicle-row__transaction-link[aria-label=?][title=?][href=?]",
      "New transaction for #{vehicles(:one).vehicle_number}",
      "New transaction for #{vehicles(:one).vehicle_number}",
      expected_transaction_path,
      1
  end

  test "staff customer page shows rewards paused state but hides the resume action" do
    sign_in users(:two)
    customers(:one).update!(rewards_paused: true)

    get customer_path(customers(:one))

    assert_response :success
    assert_select ".customer-details-hero__chip--warning", text: "Rewards Paused"
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Resume Rewards", count: 0
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Pause Rewards", count: 0
  end

  test "admin customer page offers pause and resume reward actions" do
    sign_in users(:one)

    get customer_path(customers(:one))
    assert_response :success
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Pause Rewards"

    customers(:one).update!(rewards_paused: true)
    get customer_path(customers(:one))
    assert_response :success
    assert_select ".customer-details-hero__menu .dropdown-item", text: "Resume Rewards"
  end

  test "staff cannot pause rewards via the action" do
    sign_in users(:two)
    assert_not customers(:one).rewards_paused?

    patch pause_rewards_staff_customer_path(customers(:one))

    assert_redirected_to root_path
    assert_not customers(:one).reload.rewards_paused?
  end

  test "admin can pause and resume rewards via the action" do
    sign_in users(:one)

    patch pause_rewards_staff_customer_path(customers(:one))
    assert customers(:one).reload.rewards_paused?

    patch resume_rewards_staff_customer_path(customers(:one))
    assert_not customers(:one).reload.rewards_paused?
  end

  test "staff customer page shows the cash equivalent when cash reward is configured" do
    sign_in users(:two)
    RewardSetting.current.update!(cash_value_per_point: 0.5)

    get customer_path(customers(:one))

    assert_response :success
    assert_select ".customer-details-hero__chip", text: /₹2\.50 cash value/
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
    RewardSetting.current.update!(cash_value_per_point: 0.5)
    customer = Customer.create!(name: "Transaction Customer", phone_number: "9000000077")
    user = users(:two)
    vehicle = customer.vehicles.create!(vehicle_number: "TN01AB1234", fuel_type: :petrol, vehicle_kind: :lmv)

    8.times do |index|
      transaction = customer.transactions.create!(
        user:,
        vehicle:,
        fuel_amount: 100 + index,
        fuel_pump: fuel_pumps(:one),
        fuel_pump_nozzle: fuel_pump_nozzles(:one),
        created_at: Time.current + index.minutes
      )
      customer.points_ledgers.create!(fuel_transaction: transaction, points: index + 3, entry_type: :earn, created_at: transaction.created_at)
    end

    get customer_path(customer)
    assert_response :success
    assert_select ".customer-details-history-row", 3
    assert_select ".customer-details-history-row__location", text: /Pump 1.*Nozzle 1.*Petrol/m, count: 3
    assert_select ".customer-details-history-row__reward-points", text: /Reward Points:.*\+/, count: 3
    assert_select ".customer-details-history-row__reward-cash", text: /Cash Reward:.*₹/, count: 3
    assert_select "[data-bs-target='#transactionHistoryModal']"
    assert_select "[data-transaction-history-panel][data-transaction-history-url='#{transaction_history_customer_path(customer, page: 1)}']"

    get transaction_history_customer_path(customer, page: 1)
    assert_response :success
    assert_select ".customer-details-history-row", 5
    assert_select ".customer-details-history-row__location", text: /Pump 1.*Nozzle 1.*Petrol/m, count: 5
    assert_select ".customer-details-history-row__reward-points", count: 5
    assert_select ".customer-details-history-row__reward-cash", count: 5
    assert_match "Showing <strong>1-5</strong> of <strong>5</strong> more transactions", response.body
  end
end
