require "test_helper"

module Api
  module V1
    module Admin
      # Staff feedback item 4 — GET /api/v1/admin/customers, the threshold cohort.
      class CustomersControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
          @pump = fuel_pumps(:one)

          # Heavy: three visits, one contact, points earned and redeemed.
          @heavy = Customer.create!(name: "Heavy Hitter", phone_number: "9444400001")
          3.times do |index|
            VisitEntry.create!(customer: @heavy, user: @staff, fuel_pump: @pump,
                               entry_date: Date.new(2026, 7, 1) + index.days,
                               vehicle_number: "TN44AA0001", litres: 50, discount_amount: 30)
          end
          ContactLog.create!(customer: @heavy, user: @staff, channel: "call", outcome: "reached",
                             contacted_at: Time.zone.local(2026, 7, 6, 10))
          @heavy.points_ledgers.create!(points: 500, entry_type: :earn, created_at: Time.zone.local(2026, 7, 2))
          @heavy.points_ledgers.create!(points: -200, entry_type: :redeem, created_at: Time.zone.local(2026, 7, 3))

          # Light: one visit, nothing else.
          @light = Customer.create!(name: "Light Touch", phone_number: "9444400002")
          VisitEntry.create!(customer: @light, user: @staff, fuel_pump: @pump,
                             entry_date: Date.new(2026, 7, 4), vehicle_number: "TN44BB0002", litres: 5)
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        def ids_for(params = {})
          get api_v1_admin_customers_path, params: params, headers: auth_headers(@admin)
          assert_response :ok
          response.parsed_body["customers"].map { |customer| customer["id"] }
        end

        test "returns the cohort with each customer's metrics" do
          get api_v1_admin_customers_path, headers: auth_headers(@admin)

          assert_response :ok
          body = response.parsed_body
          row = body["customers"].find { |customer| customer["id"] == @heavy.id }

          assert_equal "Heavy Hitter", row["name"]
          assert_equal "9444400001", row["phone_number"]
          assert_equal 3, row["metrics"]["visit_count"]
          assert_in_delta 150.0, row["metrics"]["litres_total"], 0.001
          assert_in_delta 90.0, row["metrics"]["discount_total"], 0.001
          assert_equal 1, row["metrics"]["contact_count"]
          assert_equal 500, row["metrics"]["points_earned"]
          assert_equal 300, row["metrics"]["points_balance"], "balance is the net figure, not the earned one"
          assert_equal "drive_in", row["customer_type"]
          assert_equal "Drive-In", row["customer_type_label"]
          assert body.key?("page")
          assert body.key?("total")
          assert body.key?("has_more")
        end

        test "a customer exactly at the threshold is returned" do
          assert_includes ids_for(min_visits: 3), @heavy.id
          assert_not_includes ids_for(min_visits: 4), @heavy.id
          assert_not_includes ids_for(min_visits: 3), @light.id
        end

        test "thresholds are AND-combined and echoed back" do
          get api_v1_admin_customers_path,
            params: { min_visits: 3, min_contacts: 1, min_points_balance: 300 },
            headers: auth_headers(@admin)

          assert_response :ok
          body = response.parsed_body
          assert_includes body["customers"].map { |customer| customer["id"] }, @heavy.id
          assert_equal({ "visit_count" => 3, "contact_count" => 1, "points_balance" => 300 }, body["thresholds"])

          # One unmet threshold removes the customer.
          assert_not_includes ids_for(min_visits: 3, min_contacts: 2), @heavy.id
        end

        test "an unset threshold keeps customers with none of that metric" do
          ids = ids_for
          assert_includes ids, @light.id, "no contacts and no points must not exclude a customer"
        end

        test "a visit-entry-only customer survives a date range" do
          # The transacted_between regression: with a period selected, a customer
          # whose fuelling exists only as a visit_entry used to disappear.
          ids = ids_for(start_date: "2026-07-01", end_date: "2026-07-31")

          assert_includes ids, @heavy.id
          assert_includes ids, @light.id
          assert_equal({ "start_date" => "2026-07-01", "end_date" => "2026-07-31" },
                       response.parsed_body["period"])
        end

        test "the period windows the metrics as well as the cohort" do
          get api_v1_admin_customers_path,
            params: { start_date: "2026-07-01", end_date: "2026-07-02" },
            headers: auth_headers(@admin)

          assert_response :ok
          row = response.parsed_body["customers"].find { |customer| customer["id"] == @heavy.id }
          assert_equal 2, row["metrics"]["visit_count"]
          assert_equal 500, row["metrics"]["points_earned"]
          assert_equal 300, row["metrics"]["points_balance"], "balance stays lifetime inside a window"
        end

        test "results are paginated" do
          get api_v1_admin_customers_path, params: { per_page: 1 }, headers: auth_headers(@admin)

          assert_response :ok
          body = response.parsed_body
          assert_equal 1, body["customers"].size
          assert_equal 1, body["per_page"]
          assert_equal 1, body["page"]
          assert body["total"] > 1
          assert body["has_more"]
        end

        test "staff cannot read the admin cohort" do
          get api_v1_admin_customers_path, headers: auth_headers(@staff)

          assert_response :forbidden
        end
      end
    end
  end
end
