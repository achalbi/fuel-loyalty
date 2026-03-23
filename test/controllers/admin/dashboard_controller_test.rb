require "test_helper"

module Admin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    test "admin can view the overview dashboard shell" do
      sign_in users(:one)

      get admin_dashboard_path

      assert_response :success
      assert_select "[data-dashboard-root]", 1
      assert_select ".dashboard-root.is-loading", 0
      assert_select "form[data-dashboard-filters]", 1
      assert_select "[data-dashboard-preset-button='today']", 1
      assert_select "[data-dashboard-preset-button='this_week']", 1
      assert_select "[data-dashboard-preset-button='this_month']", 1
      assert_select "[data-dashboard-preset-button='last_month']", 1
      assert_select "[data-dashboard-fuel-button='all']", 1
      assert_select "[data-dashboard-fuel-button='petrol']", 1
      assert_select "[data-dashboard-download]", text: /Download PDF/
      assert_select "[data-dashboard-export-summary]", 1
      assert_select "input[type='submit'][value='Apply']", 0
      assert_select "[data-kpi-card='total_customers']", 1
      assert_select "[data-dashboard-chart='transactions_trend']", 1
      assert_select "[data-dashboard-leaderboard='top_customers_by_transactions']", 1
      assert_select "[data-dashboard-leaderboard='top_customers_by_revenue']", 1
      assert_select "[data-dashboard-payload]", 1
    end

    test "admin can fetch dashboard data as json" do
      sign_in users(:one)

      travel_to Time.zone.local(2026, 6, 1, 10, 0, 0) do
        customer = Customer.create!(name: "Dashboard User", phone_number: "9876543210", created_at: 20.days.ago)
        petrol_vehicle = customer.vehicles.create!(vehicle_number: "TN01ZZ9999", fuel_type: :petrol, vehicle_kind: :lmv)
        diesel_vehicle = customer.vehicles.create!(vehicle_number: "TN01YY8888", fuel_type: :diesel, vehicle_kind: :lmv)
        petrol_transaction = customer.transactions.create!(user: users(:two), vehicle: petrol_vehicle, fuel_amount: 750, created_at: 2.days.ago)
        customer.transactions.create!(user: users(:two), vehicle: diesel_vehicle, fuel_amount: 300, created_at: 1.day.ago)
        customer.points_ledgers.create!(fuel_transaction: petrol_transaction, points: 200, entry_type: :earn, created_at: 2.days.ago)
        customer.points_ledgers.create!(points: -100, entry_type: :redeem, created_at: 1.day.ago)

        get data_admin_dashboard_path, params: {
          start_date: 7.days.ago.to_date.iso8601,
          end_date: Date.current.iso8601,
          segment: "all"
        }, as: :json

        assert_response :success

        payload = JSON.parse(response.body)
        assert_equal "all", payload.dig("filters", "segment")
        assert_equal "all", payload.dig("filters", "fuel_type")
        assert_equal 8, payload.fetch("summary").length
        assert_equal 50.0, payload.dig("rewards", "redemption_rate")
        total_revenue = payload.fetch("summary").find { |metric| metric["key"] == "total_revenue" }
        assert_equal ["Petrol", "Diesel"], total_revenue.fetch("breakdown").map { |item| item["label"] }
        assert_equal [750.0, 300.0], total_revenue.fetch("breakdown").map { |item| item["value"] }
        assert_equal ["New", "Repeat"], payload.dig("charts", "repeat_vs_new", "labels")
        assert_equal [2], payload.dig("charts", "top_customers_by_transactions", "values")
        assert_equal "2 visits", payload.dig("charts", "top_customers_by_transactions", "items", 0, "display_value")
        assert_equal "New", payload.dig("charts", "top_customers_by_transactions", "items", 0, "change_label")
        assert_equal "New baseline", payload.dig("charts", "top_customers_by_transactions", "comparison", "label")
        assert_equal [1050.0], payload.dig("charts", "top_customers_by_revenue", "values")
        assert_equal "₹1,050", payload.dig("charts", "top_customers_by_revenue", "items", 0, "display_value")
        assert_equal ["100 pts"], payload.dig("charts", "top_rewards_redeemed", "labels")
        assert_equal [1], payload.dig("charts", "top_rewards_redeemed", "values")
        assert_match(/100-point slabs/i, payload.dig("rewards", "note"))
        assert_includes payload.dig("charts", "transactions_by_hour", "labels"), "10:00"
      end
    end

    test "admin can filter dashboard data by fuel type" do
      sign_in users(:one)

      travel_to Time.zone.local(2026, 6, 1, 10, 0, 0) do
        customer = Customer.create!(name: "Fuel Filter User", phone_number: "9876500000", created_at: 12.days.ago)
        petrol_vehicle = customer.vehicles.create!(vehicle_number: "TN02AA2222", fuel_type: :petrol, vehicle_kind: :lmv)
        diesel_vehicle = customer.vehicles.create!(vehicle_number: "TN02BB3333", fuel_type: :diesel, vehicle_kind: :lmv)

        customer.transactions.create!(user: users(:two), vehicle: petrol_vehicle, fuel_amount: 650, created_at: 3.days.ago)
        customer.transactions.create!(user: users(:two), vehicle: diesel_vehicle, fuel_amount: 450, created_at: 1.day.ago)

        get data_admin_dashboard_path, params: {
          start_date: 7.days.ago.to_date.iso8601,
          end_date: Date.current.iso8601,
          segment: "all",
          fuel_type: "diesel"
        }, as: :json

        assert_response :success

        payload = JSON.parse(response.body)
        total_transactions = payload.fetch("summary").find { |metric| metric["key"] == "total_transactions" }
        total_revenue = payload.fetch("summary").find { |metric| metric["key"] == "total_revenue" }

        assert_equal "diesel", payload.dig("filters", "fuel_type")
        assert_equal "Diesel", payload.dig("meta", "fuel_type_label")
        assert_equal 1, total_transactions["value"]
        assert_equal 450.0, total_revenue["value"]
        assert_equal ["Diesel"], total_revenue.fetch("breakdown").map { |item| item["label"] }
      end
    end
  end
end
