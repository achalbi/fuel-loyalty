require "test_helper"

module Api
  module V1
    module Admin
      class ReportsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
          Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 100)
          VisitEntry.create!(user: @staff, fuel_pump: fuel_pumps(:one), entry_date: Date.new(2026, 7, 5),
                             vehicle_number: "KA01AA0001", litres: 40, discount_amount: 100, fuel_type_code: "petrol",
                             transport_name: "NL Roadways", driver_name: "Rao")
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        # Row keys for a July report with whatever filters the test cares about.
        def report_keys(**filters)
          get api_v1_admin_reports_path,
            params: { grain: "month", start_date: "2026-07-01", end_date: "2026-07-31", **filters },
            headers: auth_headers(@admin)
          assert_response :ok
          response.parsed_body["rows"].map { |r| r["key"] }
        end

        test "returns aggregated JSON rows and totals" do
          get api_v1_admin_reports_path, params: { dimension: "transporter", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31" },
            headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body
          assert_equal "transporter", body["dimension"]
          assert_equal %w[key label period litres amount discount gifts gift_count visits], body["columns"]
          row = body["rows"].first
          assert_equal "NL Roadways", row["key"]
          assert_equal 40.0, row["litres"]
          assert_equal 4000.0, row["amount"]
          assert_equal 40.0, body.dig("totals", "litres")
        end

        test "csv format streams an attachment" do
          get api_v1_admin_reports_path(format: :csv), params: { dimension: "vehicle", grain: "day", start_date: "2026-07-05", end_date: "2026-07-05" },
            headers: auth_headers(@admin)
          assert_response :ok
          assert_match %r{text/csv}, response.media_type
          assert_match(/attachment/, response.headers["Content-Disposition"])
          # The CSV carries human labels, not the machine column keys, and is
          # BOM-prefixed — force UTF-8 before matching the non-ASCII ₹ headers.
          assert_includes response.body.dup.force_encoding("UTF-8"),
            "Key,Label,Period,Litres,Amount ₹,Discount ₹,Reward ₹,Gifts,Visits"
        end

        # The Android client renders "—" instead of "₹0.00" off this one flag, so a
        # renamed/missing key would degrade silently back to the misleading zero.
        test "reward_value_configured reports whether a cash-per-point rate exists" do
          get api_v1_admin_reports_path, params: { dimension: "customer", grain: "month" }, headers: auth_headers(@admin)
          assert_equal false, response.parsed_body["reward_value_configured"],
            "no rate configured — every redemption stored a NULL cash value"

          RewardSetting.current.update!(cash_value_per_point: 0.5)
          get api_v1_admin_reports_path, params: { dimension: "customer", grain: "month" }, headers: auth_headers(@admin)
          assert_equal true, response.parsed_body["reward_value_configured"]
        end

        test "customer_id narrows the report to a single customer" do
          customer = Customer.create!(name: "Fleet One", phone_number: "9800000011")
          other = Customer.create!(name: "Fleet Two", phone_number: "9800000012")
          [customer, other].each_with_index do |c, index|
            VisitEntry.create!(user: @staff, fuel_pump: fuel_pumps(:one), entry_date: Date.new(2026, 7, 6),
                               customer: c, vehicle_number: "KA01BB000#{index}", litres: 25,
                               discount_amount: 0, fuel_type_code: "petrol")
          end

          get api_v1_admin_reports_path,
            params: { dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31",
                      customer_id: customer.id },
            headers: auth_headers(@admin)
          assert_response :ok
          keys = response.parsed_body["rows"].map { |r| r["key"] }
          assert_equal [customer.id.to_s], keys, "only the requested customer's rows survive the filter"
        end

        # Android reads gift_count off BOTH the row and the totals to render its
        # "Gifts" stat, and reads gifts as a separate ₹ "Reward" stat. A missing or
        # renamed key on either would silently degrade to a zero count.
        test "rows and totals both carry gift_count alongside the ₹ reward" do
          customer = Customer.create!(name: "Fleet One", phone_number: "9800000011")
          VisitEntry.create!(user: @staff, fuel_pump: fuel_pumps(:one), entry_date: Date.new(2026, 7, 6),
                             customer: customer, vehicle_number: "KA01BB0002", litres: 25,
                             discount_amount: 0, fuel_type_code: "petrol")
          campaign = Campaign.create!(name: "Monsoon gift", reward_kind: :gift, gift_description: "Steel bottle",
                                      min_purchase_litres: 20, period: :monthly, status: :active)
          campaign.campaign_qualifications.create!(customer: customer, period_start: Date.new(2026, 7, 1),
                                                   period_end: Date.new(2026, 7, 31),
                                                   reward_granted_at: Time.zone.local(2026, 7, 12))

          get api_v1_admin_reports_path,
            params: { dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31",
                      customer_id: customer.id },
            headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body

          assert_equal 1, body["rows"].first["gift_count"], "the physical gift handed over"
          assert_equal 0.0, body["rows"].first["gifts"], "no redemption, so no ₹ reward — a different unit"
          assert_equal 1, body.dig("totals", "gift_count")
          assert_equal false, body["reward_value_configured"],
            "no cash-per-point rate, so that ₹0 is structural and both surfaces must render it as —"
        end

        test "the free-text lookups narrow the rows" do
          VisitEntry.create!(user: @staff, fuel_pump: fuel_pumps(:one), entry_date: Date.new(2026, 7, 6),
                             vehicle_number: "KA01BB0002", litres: 25, discount_amount: 50, fuel_type_code: "petrol",
                             transport_name: "Fleet Co", driver_name: "Iyer", driver_phone_number: "9876543210")

          assert_equal ["Fleet Co"], report_keys(dimension: "transporter", transporter: "fleet")
          assert_equal %w[Iyer], report_keys(dimension: "driver", driver_name: "iye")
          assert_equal %w[Iyer], report_keys(dimension: "driver", driver_phone: "98765 43210")
          assert_equal %w[KA01BB0002], report_keys(dimension: "vehicle", vehicle_number: "ka 01 bb 0002")
          assert_empty report_keys(dimension: "vehicle", vehicle_number: "MH12AB1234")
        end

        # AND, not OR — the operator is narrowing one report, not searching.
        test "the lookups combine" do
          assert_equal %w[KA01AA0001], report_keys(dimension: "vehicle", transporter: "NL", driver_name: "Rao")
          assert_empty report_keys(dimension: "vehicle", transporter: "NL", driver_name: "Iyer")
        end

        # Android renders one dismissible chip per lookup off this block, showing
        # the NORMALIZED value so the chip says what actually matched.
        test "the payload echoes the normalized lookups it queried with" do
          get api_v1_admin_reports_path,
            params: { dimension: "vehicle", grain: "month", vehicle_number: "ka 01 aa 0001",
                      driver_phone: "+91 98765-43210", transporter: " NL Roadways " },
            headers: auth_headers(@admin)
          assert_response :ok

          filters = response.parsed_body["filters"]
          assert_equal "KA01AA0001", filters["vehicle_number"]
          assert_equal "9876543210", filters["driver_phone"], "the +91 dialling prefix is dropped, not searched for"
          assert_equal "NL Roadways", filters["transporter"]
          assert_nil filters["driver_name"]
        end

        test "staff cannot access reports" do
          get api_v1_admin_reports_path, headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
