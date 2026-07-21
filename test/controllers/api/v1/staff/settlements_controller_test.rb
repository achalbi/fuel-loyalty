require "test_helper"

module Api
  module V1
    module Staff
      class SettlementsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @pump = fuel_pumps(:one)
          @petrol = fuel_pump_nozzles(:one)
          @diesel = fuel_pump_nozzles(:two)
          @staff = users(:two)
          @staff.update!(fuel_pump_id: @pump.id)
          Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 102.75)
          Product.create!(name: "HSD", category: "fuel", fuel_type_code: "diesel", pack_unit: "litre", mrp: 95, selling_price: 90)
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "GET new hydrates a draft with auto-popped readings, catalog price and pulled discounts" do
          DailySettlement.create!(
            fuel_pump: @pump, business_date: Date.new(2026, 7, 20), recorded_by: @staff, status: "submitted",
            nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 100, closing_reading: 640, unit_price: 100 }]
          )
          VisitEntry.create!(user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 7, 21),
                             vehicle_number: "TN01AA1111", litres: 40, discount_amount: 120, transport_name: "NL")

          get api_v1_staff_new_settlement_path, params: { business_date: "2026-07-21" }, headers: auth_headers(@staff)
          assert_response :ok
          body = response.parsed_body

          assert_equal "2026-07-21", body["business_date"]
          assert_equal @pump.id, body.dig("fuel_pump", "id")
          assert_nil body["existing_settlement_id"]

          petrol = body["nozzle_readings"].find { |r| r["fuel_pump_nozzle_id"] == @petrol.id }
          assert_equal 640.0, petrol["opening_reading"]
          assert_equal "prior_settlement", petrol["opening_source"]
          assert_equal 102.75, petrol["unit_price"]

          assert_equal 1, body["discount_lines"].size
          assert_equal "NL", body["discount_lines"].first["transport_name"]
        end

        test "POST create derives amounts server-side and returns totals" do
          assert_difference -> { DailySettlement.count }, 1 do
            post api_v1_staff_settlements_path, params: {
              settlement: {
                fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
                phonepe_pos_amount: "500", phonepe_scanner_amount: "0",
                nozzle_readings_attributes: [
                  { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
                ],
                cash_denominations_attributes: [{ denomination: 500, quantity: 19 }],
              },
            }, headers: auth_headers(@staff)
          end

          assert_response :created
          body = response.parsed_body
          assert_equal "submitted", body["status"]
          reading = body["nozzle_readings"].first
          assert_equal 102.75, reading["unit_price"] # server-derived, not client-supplied
          assert_equal 100.0, reading["net_litres_sold"]
          assert_equal 10275.0, reading["amount"]
          assert_equal 10275.0, body["total_fuel_amount"]
          assert_equal 9500.0, body["counted_cash_amount"]           # 19 * 500
          assert_equal 9775.0, body["final_amount_to_settle"]        # 10275 - 500
          assert_equal 275.0, body["shortage_amount"]               # 9775 - 9500
        end

        test "a duplicate settlement for the same pump/date/shift is rejected" do
          DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                  nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
          post api_v1_staff_settlements_path, params: {
            settlement: { fuel_pump_id: @pump.id, business_date: "2026-07-21",
                          nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: "1", closing_reading: "2" }] },
          }, headers: auth_headers(@staff)
          assert_response :unprocessable_entity
          assert_includes response.parsed_body.dig("error", "message"), "already been recorded"
        end

        test "staff cannot reconcile a settlement" do
          post api_v1_staff_settlements_path, params: {
            settlement: { fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "reconciled",
                          nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: "1", closing_reading: "2" }] },
          }, headers: auth_headers(@staff)
          assert_response :forbidden
        end

        test "updating a locked settlement returns 409" do
          settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                               status: "reconciled", locked: true,
                                               nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
          patch api_v1_staff_settlement_path(settlement), params: {
            settlement: { notes: "late edit" },
          }, headers: auth_headers(@staff)
          assert_response :conflict
          assert_equal "settlement_locked", response.parsed_body.dig("error", "code")
        end

        test "index lists only the caller's own settlements" do
          mine = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                         nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
          other = users(:one)
          DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 22), recorded_by: other,
                                  nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])

          get api_v1_staff_settlements_path, headers: auth_headers(@staff)
          assert_response :ok
          ids = response.parsed_body["settlements"].map { |s| s["id"] }
          assert_includes ids, mine.id
          assert_equal 1, ids.size
        end
      end
    end
  end
end
