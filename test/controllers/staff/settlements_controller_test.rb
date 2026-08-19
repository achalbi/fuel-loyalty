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
      assert_select "tr[data-denom-row]", 9             # full denomination grid, ₹500 down to ₹1
    end

    test "staff can view a colleague's settlement for their pump but not edit it" do
      colleague = users(:one)
      theirs = DailySettlement.create!(
        fuel_pump: fuel_pumps(:one), business_date: Date.new(2026, 7, 21), recorded_by: colleague,
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id, opening_reading: 1, closing_reading: 2, unit_price: 100 }]
      )
      sign_in @staff

      get staff_settlements_path
      assert_response :success
      assert_select "a[href=?]", staff_settlement_path(theirs)
      assert_select "a[href=?]", edit_staff_settlement_path(theirs), count: 0

      get staff_settlement_path(theirs)
      assert_response :success

      get edit_staff_settlement_path(theirs)
      assert_redirected_to staff_settlement_path(theirs)
      assert_match(/view it but not edit it/, flash[:alert])
    end

    test "staff can submit a settlement and amounts are derived server-side" do
      sign_in @staff
      assert_difference -> { DailySettlement.count }, 1 do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            digital_receipts_attributes: { "0" => { label: "PhonePe POS", amount: "0" } },
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
