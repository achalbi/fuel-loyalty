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

        test "staff cannot access reports" do
          get api_v1_admin_reports_path, headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
