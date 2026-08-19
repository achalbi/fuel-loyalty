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
                digital_receipts_attributes: [{ label: "PhonePe POS", amount: "500" }],
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

        test "an admin filing through the staff API must name the FSM it is for" do
          admin = users(:one)

          assert_no_difference -> { DailySettlement.count } do
            post api_v1_staff_settlements_path, params: {
              settlement: {
                fuel_pump_id: @pump.id, business_date: "2026-07-22", status: "submitted",
                nozzle_readings_attributes: [
                  { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
                ],
              },
            }, headers: auth_headers(admin), as: :json
          end

          assert_response :unprocessable_entity
          assert_equal "on_behalf_of_required", response.parsed_body.dig("error", "code")
        end

        test "an admin naming himself is rejected the same way" do
          admin = users(:one)

          post api_v1_staff_settlements_path, params: {
            settlement: {
              fuel_pump_id: @pump.id, business_date: "2026-07-22", status: "submitted",
              recorded_by_id: admin.id,
              nozzle_readings_attributes: [
                { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
              ],
            },
          }, headers: auth_headers(admin), as: :json

          assert_response :unprocessable_entity
          assert_equal "on_behalf_of_required", response.parsed_body.dig("error", "code")
        end

        test "an admin naming a staff member files it under that staff member" do
          admin = users(:one)

          assert_difference -> { DailySettlement.count }, 1 do
            post api_v1_staff_settlements_path, params: {
              settlement: {
                fuel_pump_id: @pump.id, business_date: "2026-07-22", status: "submitted",
                recorded_by_id: @staff.id,
                nozzle_readings_attributes: [
                  { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
                ],
              },
            }, headers: auth_headers(admin), as: :json
          end

          settlement = DailySettlement.order(:id).last
          assert_equal @staff, settlement.recorded_by
          assert_equal admin, settlement.entered_by
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

        test "index lists the caller's own settlements and their pump's, but not other pumps'" do
          mine = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                         nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
          # A colleague's shift on the same pump: readable, so the FSM can see
          # the day's sheet even when someone else recorded it (feedback item 6).
          same_pump = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 22), recorded_by: users(:one),
                                              nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
          other_pump = FuelPump.create!(sequence_number: 99, active: true,
                                        nozzles_attributes: [{ sequence_number: 1, fuel_type_code: "petrol", active: true }])
          elsewhere = DailySettlement.create!(fuel_pump: other_pump, business_date: Date.new(2026, 7, 23), recorded_by: users(:one))

          get api_v1_staff_settlements_path, headers: auth_headers(@staff)
          assert_response :ok
          ids = response.parsed_body["settlements"].map { |s| s["id"] }
          assert_includes ids, mine.id
          assert_includes ids, same_pump.id
          assert_not_includes ids, elsewhere.id
        end

        # This endpoint calls the Persister without `admin_edit:`, so nothing it
        # writes leaves an audit row — an admin is refused here in exactly the
        # shape a colleague's sheet is refused, and edits through
        # PATCH /api/v1/admin/settlements/:id instead.
        test "an admin cannot update a settlement through the staff API" do
          admin = users(:one)
          settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 24), recorded_by: @staff,
                                               status: "submitted",
                                               nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }])
          reading = settlement.nozzle_readings.first

          assert_no_difference -> { SettlementChange.count } do
            patch api_v1_staff_settlement_path(settlement),
                  params: { settlement: { notes: "silent rewrite",
                                          nozzle_readings_attributes: [{ id: reading.id, closing_reading: "9999" }] } }.to_json,
                  headers: auth_headers(admin).merge("CONTENT_TYPE" => "application/json")
          end

          assert_response :forbidden
          assert_equal "forbidden", response.parsed_body.dig("error", "code")
          assert_nil settlement.reload.notes
          assert_equal 1100, reading.reload.closing_reading.to_i
        end

        # An admin still reads any sheet through this endpoint — only writing moved.
        test "an admin can still read a settlement through the staff API" do
          settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 24), recorded_by: @staff,
                                               nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])

          get api_v1_staff_settlement_path(settlement), headers: auth_headers(users(:one))

          assert_response :ok
          assert_equal settlement.id, response.parsed_body["id"]
        end

        test "a staff member cannot update a settlement recorded by someone else" do
          theirs = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 24), recorded_by: users(:one),
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])

          patch api_v1_staff_settlement_path(theirs),
                params: { settlement: { notes: "not mine to edit" } }.to_json,
                headers: auth_headers(@staff).merge("CONTENT_TYPE" => "application/json")

          assert_response :forbidden
          assert_nil theirs.reload.notes
        end
      end
    end
  end
end
