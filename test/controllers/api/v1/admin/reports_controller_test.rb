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
          assert_equal %w[key label period litres amount discount gifts visits], body["columns"]
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
          assert_includes response.body, "key,label,period,litres,amount,discount,gifts,visits"
        end

        test "staff cannot access reports" do
          get api_v1_admin_reports_path, headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
