require "test_helper"

module Settlement
  class BuilderTest < ActiveSupport::TestCase
    setup do
      @pump = fuel_pumps(:one)
      @petrol = fuel_pump_nozzles(:one)
      @staff = users(:two)
      @staff.update!(fuel_pump_id: @pump.id)
      Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 105.5)
      Product.create!(name: "HSD", category: "fuel", fuel_type_code: "diesel", pack_unit: "litre", mrp: 90, selling_price: 90)
      @lube = Product.create!(name: "10W30", category: "lubricant", pack_size: 1, pack_unit: "L", mrp: 500, selling_price: 500)
    end

    # A settlement is filed the morning after, and an on-behalf one later still,
    # so the pump must come from the day being settled — not from wherever the
    # FSM happens to stand now. Resolving on Date.current would pull the wrong
    # pump's opening readings and corrupt the whole day's math.
    test "resolves the pump the FSM was posted to on the business date" do
      other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
      UserPumpAssignment.create!(user: @staff, fuel_pump: other_pump, assigned_on: Date.new(2026, 7, 21),
                                 assigned_by: @staff, assigned_fuel_pump_nozzle_ids: [other_pump.nozzles.first.id])

      result = Builder.call(user: @staff, business_date: Date.new(2026, 7, 21))
      assert_equal other_pump.id, result.fuel_pump.id,
        "the dated posting for the business date wins over the standing pump"

      # A day with no dated posting still falls back to their standing pump.
      assert_equal @pump.id, Builder.call(user: @staff, business_date: Date.new(2026, 7, 22)).fuel_pump.id
    end

    test "auto-pops opening readings, snapshots catalog price, and pulls same-day discounts" do
      DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 20), recorded_by: @staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 5000, closing_reading: 5500, unit_price: 100 }]
      )
      VisitEntry.create!(
        user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 7, 21),
        vehicle_number: "TN01AA1111", litres: 40, discount_amount: 120, transport_name: "NL Roadways", driver_name: "Rao"
      )
      VisitEntry.create!(
        user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 7, 21),
        vehicle_number: "TN01AA1112", litres: 10, discount_amount: 0
      ) # no discount → not pulled

      result = Builder.call(user: @staff, business_date: "2026-07-21")

      petrol_row = result.settlement.nozzle_readings.find { |r| r.fuel_pump_nozzle_id == @petrol.id }
      assert_equal BigDecimal("5500"), petrol_row.opening_reading
      assert_equal "prior_settlement", petrol_row.opening_source
      assert_equal BigDecimal("105.5"), petrol_row.unit_price

      diesel_row = result.settlement.nozzle_readings.find { |r| r.fuel_pump_nozzle_id == fuel_pump_nozzles(:two).id }
      assert_nil diesel_row.opening_reading
      assert_equal "manual", diesel_row.opening_source

      assert_equal 1, result.settlement.discount_lines.size
      assert_equal "NL Roadways", result.settlement.discount_lines.first.transport_name
      assert_equal BigDecimal("120"), result.settlement.discount_lines.first.discount_amount

      assert_includes result.lube_products.map(&:id), @lube.id
      assert_equal SettlementCashDenomination::DENOMINATIONS, result.denominations
      assert_nil result.existing
    end

    test "defaults the business date to yesterday" do
      # Staff record a day's transactions as they happen and settle the next
      # morning, so a draft with no date asked for is yesterday's sheet.
      result = Builder.call(user: @staff)

      assert_equal Date.yesterday, result.settlement.business_date
    end

    test "falls back to yesterday when the business date is unparseable" do
      result = Builder.call(user: @staff, business_date: "not-a-date")

      assert_equal Date.yesterday, result.settlement.business_date
    end

    test "offers ₹1 and ₹2 in the denomination grid" do
      result = Builder.call(user: @staff)

      assert_includes result.denominations, 2
      assert_includes result.denominations, 1
    end

    # --- record on behalf of (staff feedback item 3) ------------------------

    test "recorded_for resolves the FSM's pump, nozzles and history — not the admin's" do
      # The admin is posted to a DIFFERENT pump. Every default on the draft must
      # come from the FSM's pump: leaking the admin's would build a sheet for the
      # wrong forecourt and attribute it to the FSM.
      admin = users(:one)
      admin_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
      admin.update!(fuel_pump_id: admin_pump.id)

      DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 20), recorded_by: @staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 5000, closing_reading: 5750, unit_price: 100 }]
      )
      VisitEntry.create!(
        user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 7, 21),
        vehicle_number: "TN01AA2222", litres: 30, discount_amount: 90, transport_name: "Behalf Roadways"
      )

      result = Builder.call(user: admin, recorded_for: @staff, business_date: "2026-07-21")

      assert_equal @pump, result.fuel_pump, "the draft must be built against the FSM's pump"
      assert_equal @staff, result.recorded_for
      assert_equal @staff, result.settlement.recorded_by
      assert_equal @staff.display_name, result.settlement.fsm_name_snapshot

      # The FSM's nozzles, with THEIR pump's yesterday-closing auto-popped.
      assert_equal @pump.nozzles.active.count, result.settlement.nozzle_readings.size
      petrol_row = result.settlement.nozzle_readings.find { |r| r.fuel_pump_nozzle_id == @petrol.id }
      assert_equal BigDecimal("5750"), petrol_row.opening_reading
      assert_equal "prior_settlement", petrol_row.opening_source
      assert_equal BigDecimal("105.5"), petrol_row.unit_price
      assert_not_includes result.settlement.nozzle_readings.map(&:fuel_pump_nozzle_id), admin_pump.nozzles.first.id

      # And the FSM's pump's same-day discounts, not the admin's.
      assert_equal ["Behalf Roadways"], result.settlement.discount_lines.map(&:transport_name)
    end

    test "an explicit pump still wins over the FSM's assignment" do
      admin = users(:one)
      other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "diesel", active: true }])

      result = Builder.call(user: admin, recorded_for: @staff, fuel_pump_id: other_pump.id, business_date: "2026-07-21")

      assert_equal other_pump, result.fuel_pump
      assert_equal @staff, result.settlement.recorded_by
    end

    test "omitting recorded_for keeps the caller as the recorder" do
      result = Builder.call(user: @staff, business_date: "2026-07-21")

      assert_equal @staff, result.recorded_for
      assert_equal @staff, result.settlement.recorded_by
      assert_equal @pump, result.fuel_pump
    end

    test "reports an existing settlement for the pump/date/shift" do
      existing = DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }]
      )
      result = Builder.call(user: @staff, fuel_pump_id: @pump.id, business_date: "2026-07-21")
      assert_equal existing.id, result.existing.id
    end
  end
end
