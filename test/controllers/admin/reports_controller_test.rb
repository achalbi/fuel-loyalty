require "test_helper"

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

    test "renders the report table for an admin" do
      sign_in @admin
      get admin_reports_path, params: { dimension: "transporter", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31" }
      assert_response :success
      assert_select "td", text: "NL Roadways"
    end

    test "csv download returns an attachment" do
      sign_in @admin
      get admin_reports_path(format: :csv), params: { dimension: "vehicle", grain: "day", start_date: "2026-07-05", end_date: "2026-07-05" }
      assert_response :success
      assert_match %r{text/csv}, response.media_type
      assert_includes response.body, "KA01AA0001"
    end

    test "non-admin is bounced" do
      sign_in @staff
      get admin_reports_path
      assert_response :redirect
    end
  end
end
