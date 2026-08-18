require "test_helper"

module Staff
  class SettlementsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @pump = fuel_pumps(:one)
      @petrol = fuel_pump_nozzles(:one)
      @staff = users(:two)
      @staff.update!(fuel_pump_id: @pump.id)
      Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 102.75)
      Product.create!(name: "HSD", category: "fuel", fuel_type_code: "diesel", pack_unit: "litre", mrp: 95, selling_price: 90)
      Product.create!(name: "10W30", category: "lubricant", pack_size: 1, pack_unit: "L", mrp: 500, selling_price: 500)
    end

    test "staff can open the settlement form with a pre-filled draft and lube grid" do
      sign_in @staff
      get new_staff_settlement_path
      assert_response :success
      assert_select "form[data-settlement-form]"
      assert_select "tr[data-nozzle-row]", minimum: 2   # petrol + diesel nozzles
      assert_select "tr[data-lube-row]"                 # 10W30
      assert_select "tr[data-denom-row]", 7             # full denomination grid
    end

    test "staff can submit a settlement and amounts are derived server-side" do
      sign_in @staff
      assert_difference -> { DailySettlement.count }, 1 do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            phonepe_pos_amount: "0", phonepe_scanner_amount: "0",
            nozzle_readings_attributes: {
              "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
            },
            cash_denominations_attributes: {
              "0" => { denomination: "500", quantity: "20" },
            },
          },
        }
      end
      settlement = DailySettlement.order(:id).last
      assert_redirected_to staff_settlement_path(settlement)
      assert settlement.submitted?
      reading = settlement.nozzle_readings.find_by(fuel_pump_nozzle_id: @petrol.id)
      assert_equal BigDecimal("102.75"), reading.unit_price   # from catalog, not the form
      assert_equal BigDecimal("10275"), settlement.total_fuel_amount
      assert_equal BigDecimal("10000"), settlement.counted_cash_amount
    end

    test "opening new for an existing pump/date redirects to edit" do
      existing = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                         nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      sign_in @staff
      get new_staff_settlement_path, params: { fuel_pump_id: @pump.id, business_date: "2026-07-21" }
      assert_redirected_to edit_staff_settlement_path(existing)
    end

    test "a staff settlement is recorded as its own author and cannot be reassigned" do
      sign_in @staff
      post staff_settlements_path, params: {
        settlement: {
          fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
          recorded_by_id: users(:one).id,
          nozzle_readings_attributes: {
            "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
          },
        },
      }

      settlement = DailySettlement.order(:id).last
      assert_equal @staff, settlement.recorded_by
      assert_equal @staff, settlement.entered_by
      assert_not settlement.entered_on_behalf?
    end

    test "an admin must name the staff member a settlement is entered for" do
      sign_in users(:one)

      assert_no_difference -> { DailySettlement.count } do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            nozzle_readings_attributes: {
              "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
            },
          },
        }
      end

      assert_response :unprocessable_entity
      assert_select ".alert.alert-danger", text: /on behalf of/
    end

    test "an admin entering on behalf of a staff member is recorded on both sides" do
      sign_in users(:one)

      assert_difference -> { DailySettlement.count }, 1 do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            recorded_by_id: @staff.id,
            nozzle_readings_attributes: {
              "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
            },
          },
        }
      end

      settlement = DailySettlement.order(:id).last
      assert_equal @staff, settlement.recorded_by
      assert_equal users(:one), settlement.entered_by
      assert settlement.entered_on_behalf?
      assert_equal @staff.display_name, settlement.fsm_name_snapshot
    end

    test "an admin editing a staff settlement cannot re-point it at anyone, blank or not" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      other_staff = User.create!(name: "Other FSM", username: "fsm-other", phone_number: "9000000044",
                                 password: "password123", password_confirmation: "password123", role: :staff)
      sign_in users(:one)

      patch staff_settlement_path(settlement), params: { settlement: { recorded_by_id: "", notes: "Tidied up" } }
      assert_equal @staff, settlement.reload.recorded_by

      patch staff_settlement_path(settlement), params: { settlement: { recorded_by_id: other_staff.id, notes: "Moved?" } }
      assert_equal @staff, settlement.reload.recorded_by, "ownership is decided at creation and never re-pointed"

      patch staff_settlement_path(settlement), params: { settlement: { recorded_by_id: users(:one).id, notes: "Mine now?" } }
      assert_equal @staff, settlement.reload.recorded_by
    end

    test "an admin cannot file a settlement on behalf of himself" do
      sign_in users(:one)

      assert_no_difference -> { DailySettlement.count } do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            recorded_by_id: users(:one).id,
            nozzle_readings_attributes: {
              "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
            },
          },
        }
      end

      assert_response :unprocessable_entity
      assert_select "select[name='settlement[recorded_by_id]'] option[value=?]", users(:one).id.to_s, count: 0
    end

    test "a pre-existing settlement is not back-stamped as entered by whoever edits it" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      # Simulate a row created before the entered_by column existed.
      settlement.update_column(:entered_by_id, nil)
      sign_in users(:one)

      patch staff_settlement_path(settlement), params: { settlement: { notes: "Admin correction" } }

      settlement.reload
      assert_nil settlement.entered_by_id, "an edit must not claim the editor keyed the settlement in"
      assert_not settlement.entered_on_behalf?
    end

    test "an admin with no staff accounts is told why they cannot record a settlement" do
      @staff.soft_delete! if @staff.update!(active: false) || true
      sign_in users(:one)

      get new_staff_settlement_path

      assert_response :success
      assert_select ".alert.alert-warning", text: /no staff accounts yet/
      assert_select "select[name='settlement[recorded_by_id]']", 0
    end

    test "a locked settlement cannot be edited" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           status: "reconciled", locked: true,
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      sign_in @staff
      get edit_staff_settlement_path(settlement)
      assert_redirected_to staff_settlement_path(settlement)
    end
  end
end
