require "test_helper"

module Api
  module V1
    module Admin
      # GET /api/v1/admin/customers — the threshold cohort (docs/acefuels/20-api-contracts.md §14).
      # The per-customer insight action on the same controller is covered by
      # customers_insight_controller_test.rb.
      class CustomersControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
          @pump = fuel_pumps(:one)

          @heavy = Customer.create!(name: "Cohort Heavy", phone_number: "9555500001")
          @heavy_vehicle = @heavy.vehicles.create!(vehicle_number: "TN55CH0001", fuel_type: :petrol,
                                                   vehicle_kind: :two_wheeler)
          @light = Customer.create!(name: "Cohort Light", phone_number: "9555500002")
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        def transaction_for(customer, vehicle, at, litres:, discount: 0)
          Transaction.create!(customer: customer, user: @staff, vehicle: vehicle, fuel_amount: 1000,
                              litres: litres, discount_amount: discount, created_at: at)
        end

        # Scoped to the two customers this test file creates, so the fixtures do
        # not have to be counted alongside them.
        def cohort(params = {})
          get api_v1_admin_customers_path(params.merge(q: "Cohort")), headers: auth_headers(@admin)
          assert_response :ok
          response.parsed_body
        end

        def metrics_for(customer, params = {})
          cohort(params)["customers"].find { |row| row["id"] == customer.id }["metrics"]
        end

        test "returns the cohort with each customer's metrics and the applied thresholds" do
          transaction_for(@heavy, @heavy_vehicle, Time.zone.local(2026, 7, 10, 9, 0), litres: 40, discount: 30)
          @heavy.contact_logs.create!(user: @staff, channel: "call", outcome: "reached", contacted_at: 2.days.ago)
          @heavy.points_ledgers.create!(entry_type: :earn, points: 400, cash_reward_amount: 0)
          VisitEntry.create!(customer: @light, user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 7, 10),
                             vehicle_number: "TN55CL0001", litres: 5, discount_amount: 1)

          body = cohort

          assert_equal 2, body["total"]
          assert_equal 1, body["page"]
          assert_equal 25, body["per_page"]
          assert_not body["has_more"]
          assert_empty body["thresholds"]
          assert_nil body.dig("period", "start_date"), "period is always present, and null without one"

          heavy = body["customers"].find { |row| row["id"] == @heavy.id }
          assert_equal "Cohort Heavy", heavy["name"]
          assert_equal "9555500001", heavy["phone_number"]
          assert_equal ["TN55CH0001"], heavy["vehicle_numbers"]
          assert heavy["active"]
          assert_equal 1, heavy.dig("metrics", "visits")
          assert_in_delta 40.0, heavy.dig("metrics", "litres")
          assert_in_delta 30.0, heavy.dig("metrics", "discount")
          assert_equal 1, heavy.dig("metrics", "contacts")
          assert_equal 400, heavy.dig("metrics", "points")
          assert_equal 400, heavy.dig("metrics", "points_earned")
        end

        test "each threshold narrows the cohort and comes back echoed" do
          # Heavy: 2 fuellings, 40 L, ₹30 off, 3 contacts, 400 points.
          # Light: 1 capture, 5 L, ₹1 off, no contacts, no points.
          transaction_for(@heavy, @heavy_vehicle, Time.zone.local(2026, 7, 10, 9, 0), litres: 20, discount: 15)
          transaction_for(@heavy, @heavy_vehicle, Time.zone.local(2026, 7, 12, 9, 0), litres: 20, discount: 15)
          3.times { @heavy.contact_logs.create!(user: @staff, channel: "call", outcome: "reached", contacted_at: 2.days.ago) }
          @heavy.points_ledgers.create!(entry_type: :earn, points: 400, cash_reward_amount: 0)
          VisitEntry.create!(customer: @light, user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 7, 10),
                             vehicle_number: "TN55CL0001", litres: 5, discount_amount: 1)

          { min_visits: 2, min_litres: "20.5", min_discount: "10.25", min_contacts: 2,
            min_points: 100, min_points_earned: 100 }.each do |threshold, value|
            body = cohort(threshold => value)

            assert_equal [@heavy.id], body["customers"].map { |row| row["id"] },
              "#{threshold} should keep the customer above it and drop the one below"
            assert_equal 1, body["total"]
            assert_equal value.to_f, body.dig("thresholds", threshold.to_s).to_f
          end
        end

        # The whole point of shipping two point thresholds instead of one.
        test "points earned and the points balance are separate filters, not aliases" do
          @heavy.points_ledgers.create!(entry_type: :earn, points: 5_000, cash_reward_amount: 0)
          @heavy.points_ledgers.create!(entry_type: :redeem, points: -4_800, cash_reward_amount: 2_400)

          assert_equal [@heavy.id], cohort(min_points_earned: 5_000)["customers"].map { |row| row["id"] }
          assert_empty cohort(min_points: 5_000)["customers"],
            "the balance filter cannot see points that have since been redeemed"

          metrics = metrics_for(@heavy)
          assert_equal 5_000, metrics["points_earned"]
          assert_equal 200, metrics["points"]
        end

        test "visits are days served, so the filter agrees with the customer's profile" do
          transaction_for(@heavy, @heavy_vehicle, Time.zone.local(2026, 7, 10, 8, 0), litres: 10)
          transaction_for(@heavy, @heavy_vehicle, Time.zone.local(2026, 7, 10, 20, 0), litres: 10)

          metrics = metrics_for(@heavy)

          assert_equal 1, metrics["visits"], "two fuellings on one day are one day served"
          assert_in_delta 20.0, metrics["litres"].to_f, 0.001, "litres still sum both fuellings"
          assert_empty cohort(min_visits: 2)["customers"].map { |row| row["id"] },
            "a customer whose profile reads 1 visit must not match a 2-visit filter"
        end

        # Back-dated capture, transaction written after midnight: one fuelling,
        # reported once by all three figures.
        test "a linked capture and its transaction are one visit even across a date boundary" do
          linked = transaction_for(@heavy, @heavy_vehicle, Time.zone.local(2026, 7, 1, 0, 20), litres: 20, discount: 100)
          VisitEntry.create!(customer: @heavy, user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 6, 30),
                             vehicle_number: "TN55CH0001", litres: 20, discount_amount: 100,
                             fuel_transaction: linked)

          metrics = metrics_for(@heavy)

          assert_equal 1, metrics["visits"]
          assert_in_delta 20.0, metrics["litres"]
          assert_in_delta 100.0, metrics["discount"]
        end

        test "a period windows the figures and lists only customers active in it" do
          transaction_for(@heavy, @heavy_vehicle, Time.zone.local(2026, 7, 10, 9, 0), litres: 40, discount: 30)
          transaction_for(@heavy, @heavy_vehicle, Time.zone.local(2026, 8, 10, 9, 0), litres: 10, discount: 5)

          body = cohort(start_date: "2026-07-01", end_date: "2026-07-31")

          assert_equal "2026-07-01", body.dig("period", "start_date")
          assert_equal "2026-07-31", body.dig("period", "end_date")
          assert_equal [@heavy.id], body["customers"].map { |row| row["id"] },
            "the customer with no July fuelling is not active in the period"
          assert_in_delta 40.0, body["customers"].first.dig("metrics", "litres")
        end

        test "status and account type filter the cohort the same way the web list does" do
          @light.update!(active: false, customer_type: "otp")

          assert_equal [@light.id], cohort(status: "inactive")["customers"].map { |row| row["id"] }
          assert_equal [@heavy.id], cohort(status: "active")["customers"].map { |row| row["id"] }
          assert_equal [@light.id], cohort(type: "otp")["customers"].map { |row| row["id"] }
          assert_equal 2, cohort(status: "all", type: "nonsense")["total"], "unknown values mean no filter"
        end

        # A customer with two vehicles must be ONE row however the search reached
        # them, or `total` and the paging built on it are both wrong.
        test "a customer with several vehicles is one row, and is still findable by plate" do
          @heavy.vehicles.create!(vehicle_number: "TN55CH0002", fuel_type: :petrol, vehicle_kind: :two_wheeler)

          get api_v1_admin_customers_path(q: "Cohort Heavy"), headers: auth_headers(@admin)
          assert_response :ok
          by_name = response.parsed_body

          assert_equal 1, by_name["total"]
          assert_equal [@heavy.id], by_name["customers"].map { |row| row["id"] }
          assert_equal %w[TN55CH0001 TN55CH0002], by_name["customers"].first["vehicle_numbers"].sort

          get api_v1_admin_customers_path(q: "TN55CH0002"), headers: auth_headers(@admin)
          assert_response :ok
          by_plate = response.parsed_body

          assert_equal 1, by_plate["total"]
          assert_equal [@heavy.id], by_plate["customers"].map { |row| row["id"] }
        end

        test "a blank or unparseable threshold is ignored rather than emptying the cohort" do
          body = cohort(min_visits: "-5", min_litres: "not-a-number", min_points_earned: "")

          assert_equal 2, body["total"]
          assert_empty body["thresholds"]
        end

        test "the cohort pages server-side" do
          first = cohort(per_page: 1)

          assert_equal 1, first["customers"].size
          assert_equal 1, first["per_page"]
          assert_equal 2, first["total"]
          assert first["has_more"]

          second = cohort(per_page: 1, page: 2)

          assert_equal 2, second["page"]
          assert_not second["has_more"]
          assert_not_equal first["customers"].first["id"], second["customers"].first["id"]
        end

        test "staff cannot read the admin cohort" do
          get api_v1_admin_customers_path, headers: auth_headers(@staff)

          assert_response :forbidden
        end
      end
    end
  end
end
