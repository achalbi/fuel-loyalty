require "test_helper"

module Admin
  class TransactionsControllerTest < ActionDispatch::IntegrationTest
    test "admin can view transactions index with new transaction action" do
      sign_in users(:one)

      get admin_transactions_path

      assert_response :success
      assert_select "h1", text: "Transactions"
      assert_select "a.customer-details-quick-action.admin-transactions-create-action[href='#{new_staff_transaction_path}'][aria-label='New Transaction']", text: "+"
      assert_select ".admin-transactions-list"
      assert_select ".admin-transaction-item", minimum: 1
      assert_select ".admin-transaction-item__amount", text: /₹/
      assert_select ".admin-transaction-item__view[aria-label=?]", "View details for Arun"
      assert_select ".admin-transaction-modal"
      assert_select ".admin-transactions-filter"
      assert_select ".dashboard-filter-chip", text: "Today"
      assert_select "select[name='sort']"
    end

    test "admin can filter transactions to today" do
      sign_in users(:one)

      create_transaction_for(
        name: "Today Filter User",
        phone_number: "9111111111",
        vehicle_number: "TN09AA1111",
        fuel_amount: 420,
        created_at: Time.zone.now.change(hour: 10, min: 15)
      )

      create_transaction_for(
        name: "Yesterday Filter User",
        phone_number: "9222222222",
        vehicle_number: "TN09AA2222",
        fuel_amount: 510,
        created_at: 1.day.ago.change(hour: 18, min: 45)
      )

      get admin_transactions_path, params: { range: "today" }

      assert_response :success
      assert_select ".dashboard-filter-chip.is-active", text: "Today"
      assert_includes response.body, "Today Filter User"
      refute_includes response.body, "Yesterday Filter User"
    end

    test "admin can sort transactions by amount" do
      sign_in users(:one)

      create_transaction_for(
        name: "Low Sort User",
        phone_number: "9333333333",
        vehicle_number: "TN09AA3333",
        fuel_amount: 120,
        created_at: Time.zone.now.change(hour: 9, min: 30)
      )

      create_transaction_for(
        name: "High Sort User",
        phone_number: "9444444444",
        vehicle_number: "TN09AA4444",
        fuel_amount: 1450,
        created_at: Time.zone.now.change(hour: 11, min: 30)
      )

      get admin_transactions_path, params: { sort: "amount_asc" }

      assert_response :success
      names = css_select(".admin-transaction-item__name").map(&:text)
      assert_operator names.index("Low Sort User"), :<, names.index("High Sort User")
    end

    test "admin can filter transactions by time range" do
      sign_in users(:one)

      create_transaction_for(
        name: "Older Range User",
        phone_number: "9666666661",
        vehicle_number: "TN09AA6661",
        fuel_amount: 300,
        created_at: Time.zone.local(2026, 3, 10, 9, 0, 0)
      )

      create_transaction_for(
        name: "In Range User",
        phone_number: "9666666662",
        vehicle_number: "TN09AA6662",
        fuel_amount: 480,
        created_at: Time.zone.local(2026, 3, 20, 14, 30, 0)
      )

      get admin_transactions_path, params: { start_date: "2026-03-18", end_date: "2026-03-22" }

      assert_response :success
      assert_select "input[name='start_date'][value='2026-03-18']"
      assert_select "input[name='end_date'][value='2026-03-22']"
      assert_includes response.body, "In Range User"
      refute_includes response.body, "Older Range User"
    end

    test "admin transactions are paginated with 10 items per page" do
      sign_in users(:one)

      12.times do |index|
        create_transaction_for(
          name: "Paged User #{index + 1}",
          phone_number: format("95555555%02d", index),
          vehicle_number: format("TN10AA%04d", index),
          fuel_amount: 100 + index,
          created_at: Time.zone.now.beginning_of_day + (index + 1).minutes
        )
      end

      get admin_transactions_path, params: { range: "today" }

      assert_response :success
      assert_select ".admin-transaction-item", count: 10
      assert_select ".customer-details-ledger-pagination__status", text: /Page 1 of 2/
      assert_includes response.body, "Paged User 12"
      refute_includes response.body, "Paged User 2"

      get admin_transactions_path, params: { range: "today", page: 2 }

      assert_response :success
      assert_operator css_select(".admin-transaction-item").size, :<=, 10
      assert_select ".customer-details-ledger-pagination__status", text: /Page 2 of 2/
      assert_includes response.body, "Paged User 2"
      assert_includes response.body, "Paged User 1"
      refute_includes response.body, "Paged User 12"
    end

    private

    def create_transaction_for(name:, phone_number:, vehicle_number:, fuel_amount:, created_at:)
      customer = Customer.create!(name: name, phone_number: phone_number)
      vehicle = customer.vehicles.create!(
        vehicle_number: vehicle_number,
        fuel_type: :petrol,
        vehicle_kind: :two_wheeler
      )

      Transaction.create!(
        customer: customer,
        user: users(:two),
        vehicle: vehicle,
        fuel_amount: fuel_amount,
        created_at: created_at,
        updated_at: created_at
      )
    end
  end
end
