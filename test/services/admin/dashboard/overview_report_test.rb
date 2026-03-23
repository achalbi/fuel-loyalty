require "test_helper"

module Admin
  module Dashboard
    class OverviewReportTest < ActiveSupport::TestCase
      test "builds repeat-customer metrics for the selected range" do
        travel_to Time.zone.local(2026, 6, 1, 10, 0, 0) do
          customer = Customer.create!(name: "Repeat Driver", phone_number: "9000012345", created_at: 45.days.ago)
          vehicle = customer.vehicles.create!(vehicle_number: "TN09AB1234", fuel_type: :diesel, vehicle_kind: :lmv)

          first_transaction = customer.transactions.create!(user: users(:two), vehicle: vehicle, fuel_amount: 600, created_at: 20.days.ago)
          customer.points_ledgers.create!(fuel_transaction: first_transaction, points: 6, entry_type: :earn, created_at: 20.days.ago)

          second_transaction = customer.transactions.create!(user: users(:two), vehicle: vehicle, fuel_amount: 900, created_at: 2.days.ago)
          customer.points_ledgers.create!(fuel_transaction: second_transaction, points: 9, entry_type: :earn, created_at: 2.days.ago)

          new_customer = Customer.create!(name: "New Driver", phone_number: "9000012346", created_at: 3.days.ago)
          new_vehicle = new_customer.vehicles.create!(vehicle_number: "TN10CD5678", fuel_type: :petrol, vehicle_kind: :lmv)
          new_transaction = new_customer.transactions.create!(user: users(:two), vehicle: new_vehicle, fuel_amount: 500, created_at: 1.day.ago)
          new_customer.points_ledgers.create!(fuel_transaction: new_transaction, points: 5, entry_type: :earn, created_at: 1.day.ago)

          report = OverviewReport.new(
            start_date: 7.days.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            segment: "repeat"
          )

          payload = report.as_json
          total_customers = payload.fetch(:summary).find { |item| item[:key] == "total_customers" }
          total_transactions = payload.fetch(:summary).find { |item| item[:key] == "total_transactions" }

          assert_equal 1, total_customers[:value]
          assert_equal 1, total_transactions[:value]
          assert_equal [0, 1], payload.dig(:charts, :repeat_vs_new, :values)
        end
      end

      test "includes fuel-type revenue breakdown on total revenue metric" do
        travel_to Time.zone.local(2026, 6, 1, 10, 0, 0) do
          customer = Customer.create!(name: "Revenue Driver", phone_number: "9111111111", created_at: 12.days.ago)
          petrol_vehicle = customer.vehicles.create!(vehicle_number: "TN11AA1111", fuel_type: :petrol, vehicle_kind: :lmv)
          diesel_vehicle = customer.vehicles.create!(vehicle_number: "TN11BB2222", fuel_type: :diesel, vehicle_kind: :lmv)

          customer.transactions.create!(user: users(:two), vehicle: petrol_vehicle, fuel_amount: 1200, created_at: 3.days.ago)
          customer.transactions.create!(user: users(:two), vehicle: diesel_vehicle, fuel_amount: 800, created_at: 2.days.ago)

          report = OverviewReport.new(
            start_date: 7.days.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            segment: "all"
          )

          total_revenue = report.as_json.fetch(:summary).find { |item| item[:key] == "total_revenue" }

          assert_equal 2000.0, total_revenue[:value]
          assert_equal ["Petrol", "Diesel"], total_revenue.fetch(:breakdown).map { |item| item[:label] }
          assert_equal [1200.0, 800.0], total_revenue.fetch(:breakdown).map { |item| item[:value] }
        end
      end

      test "filters summary by selected fuel type" do
        travel_to Time.zone.local(2026, 6, 1, 10, 0, 0) do
          customer = Customer.create!(name: "Filter Driver", phone_number: "9222222222", created_at: 12.days.ago)
          petrol_vehicle = customer.vehicles.create!(vehicle_number: "TN12AA1111", fuel_type: :petrol, vehicle_kind: :lmv)
          diesel_vehicle = customer.vehicles.create!(vehicle_number: "TN12BB2222", fuel_type: :diesel, vehicle_kind: :lmv)

          customer.transactions.create!(user: users(:two), vehicle: petrol_vehicle, fuel_amount: 1100, created_at: 3.days.ago)
          customer.transactions.create!(user: users(:two), vehicle: diesel_vehicle, fuel_amount: 700, created_at: 2.days.ago)

          report = OverviewReport.new(
            start_date: 7.days.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            segment: "all",
            fuel_type: "diesel"
          )

          payload = report.as_json
          total_transactions = payload.fetch(:summary).find { |item| item[:key] == "total_transactions" }
          total_revenue = payload.fetch(:summary).find { |item| item[:key] == "total_revenue" }

          assert_equal "diesel", payload.dig(:filters, :fuel_type)
          assert_equal "Diesel", payload.dig(:meta, :fuel_type_label)
          assert_equal 1, total_transactions[:value]
          assert_equal 700.0, total_revenue[:value]
          assert_equal ["Diesel"], total_revenue.fetch(:breakdown).map { |item| item[:label] }
        end
      end

      test "groups redeemed points into 100-point slabs for the rewards chart" do
        travel_to Time.zone.local(2026, 6, 1, 10, 0, 0) do
          customer = Customer.create!(name: "Rewards Driver", phone_number: "9333333333", created_at: 20.days.ago)

          customer.points_ledgers.create!(points: -100, entry_type: :redeem, created_at: 3.days.ago)
          customer.points_ledgers.create!(points: -100, entry_type: :redeem, created_at: 2.days.ago)
          customer.points_ledgers.create!(points: -200, entry_type: :redeem, created_at: 1.day.ago)
          customer.points_ledgers.create!(points: -75, entry_type: :redeem, created_at: 1.day.ago)
          customer.points_ledgers.create!(points: 600, entry_type: :earn, created_at: 4.days.ago)

          report = OverviewReport.new(
            start_date: 7.days.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            segment: "all"
          )

          payload = report.as_json

          assert_equal ["100 pts", "200 pts", "Other / Legacy"], payload.dig(:charts, :top_rewards_redeemed, :labels)
          assert_equal [2, 1, 1], payload.dig(:charts, :top_rewards_redeemed, :values)
          assert_match(/100-point slabs/i, payload.dig(:rewards, :note))
        end
      end

      test "uses the full previous calendar month for the last month preset" do
        travel_to Time.zone.local(2026, 6, 15, 10, 0, 0) do
          report = OverviewReport.new(
            start_date: Date.current.iso8601,
            end_date: Date.current.iso8601,
            segment: "all",
            preset: "last_month"
          )

          payload = report.as_json

          assert_equal "last_month", payload.dig(:filters, :preset)
          assert_equal Date.new(2026, 5, 1).iso8601, payload.dig(:filters, :start_date)
          assert_equal Date.new(2026, 5, 31).iso8601, payload.dig(:filters, :end_date)
        end
      end

      test "builds top customer leaderboards with previous-period comparison" do
        travel_to Time.zone.local(2026, 6, 15, 10, 0, 0) do
          [
            ["Alpha Fleet", "9444444441", [300, 300, 300], [500]],
            ["Beta Movers", "9444444442", [600, 600], [400]],
            ["Charlie Cabs", "9444444443", [800], [300]],
            ["Delta Diesel", "9444444444", [400], [200]],
            ["Echo Logistics", "9444444445", [200], []],
            ["Foxtrot Fuels", "9444444446", [100], []]
          ].each_with_index do |(name, phone_number, current_amounts, previous_amounts), index|
            customer = Customer.create!(name:, phone_number:, created_at: 45.days.ago)
            vehicle = customer.vehicles.create!(vehicle_number: "TN20AA1#{index}#{index}", fuel_type: :diesel, vehicle_kind: :lmv)

            current_amounts.each_with_index do |amount, amount_index|
              customer.transactions.create!(user: users(:two), vehicle:, fuel_amount: amount, created_at: (amount_index + 1).days.ago)
            end

            previous_amounts.each_with_index do |amount, amount_index|
              customer.transactions.create!(user: users(:two), vehicle:, fuel_amount: amount, created_at: (12 + amount_index).days.ago)
            end
          end

          report = OverviewReport.new(
            start_date: 9.days.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            segment: "all"
          )

          payload = report.as_json

          assert_equal [3, 2, 1, 1, 1], payload.dig(:charts, :top_customers_by_transactions, :values)
          assert_equal "+100% vs previous 10-day period", payload.dig(:charts, :top_customers_by_transactions, :comparison, :label)
          assert_equal "3 visits", payload.dig(:charts, :top_customers_by_transactions, :items, 0, :display_value)
          assert_equal "+200%", payload.dig(:charts, :top_customers_by_transactions, :items, 0, :change_label)
          assert_equal 10, payload.dig(:charts, :top_customers_by_transactions, :items, 0, :trend_values).length
          assert_equal [1200.0, 900.0, 800.0, 400.0, 200.0], payload.dig(:charts, :top_customers_by_revenue, :values)
          assert_equal "+150% vs previous 10-day period", payload.dig(:charts, :top_customers_by_revenue, :comparison, :label)
          assert_equal "₹1,200", payload.dig(:charts, :top_customers_by_revenue, :items, 0, :display_value)
        end
      end
    end
  end
end
