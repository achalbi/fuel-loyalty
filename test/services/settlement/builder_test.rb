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

      assert_equal BigDecimal("5500"), petrol_row.prior_closing_reading
      assert_equal Date.new(2026, 7, 20), petrol_row.prior_closing_date

      diesel_row = result.settlement.nozzle_readings.find { |r| r.fuel_pump_nozzle_id == fuel_pump_nozzles(:two).id }
      assert_nil diesel_row.opening_reading
      assert_nil diesel_row.prior_closing_reading
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

    test "a back-dated draft uses the pump the caller was on that day, not today's" do
      other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
      # Worked `other_pump` on the 21st, moved back to their default pump today.
      @staff.update_pump_assignment(
        { fuel_pump_id: other_pump.id, assigned_fuel_pump_nozzle_ids: [other_pump.nozzles.first.id] },
        on: Date.new(2026, 7, 21), assigned_by: @staff
      )
      @staff.update_pump_assignment(
        { fuel_pump_id: @pump.id, assigned_fuel_pump_nozzle_ids: [@petrol.id] },
        on: Date.current, assigned_by: @staff
      )
      # A discount captured on the 21st belongs to the pump worked that day.
      VisitEntry.create!(
        user: @staff, fuel_pump: other_pump, entry_date: Date.new(2026, 7, 21),
        vehicle_number: "TN01AA9999", litres: 30, discount_amount: 75, transport_name: "Backdated Lines"
      )

      result = Builder.call(user: @staff, business_date: "2026-07-21")

      assert_equal other_pump.id, result.fuel_pump.id
      assert_equal ["Backdated Lines"], result.settlement.discount_lines.map(&:transport_name)
    end

    test "a back-dated draft falls back to the standing default when no override was recorded" do
      @staff.update_pump_assignment(
        { fuel_pump_id: @pump.id, assigned_fuel_pump_nozzle_ids: [@petrol.id] },
        on: Date.current, assigned_by: @staff
      )

      result = Builder.call(user: @staff, business_date: "2026-07-21")

      assert_equal @pump.id, result.fuel_pump.id
    end

    test "an explicit pump still wins over the assignment for the date" do
      other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])

      result = Builder.call(user: @staff, fuel_pump_id: other_pump.id, business_date: "2026-07-21")

      assert_equal other_pump.id, result.fuel_pump.id
    end

    # The pump kept selling on the days nobody settled, so the offer is stale by
    # exactly that gap — carry the date it came from rather than let a week-old
    # figure read as yesterday's.
    test "auto-pops across a gap of unsettled days and reports how wide the gap is" do
      DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 15), recorded_by: @staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 4000, closing_reading: 5500, unit_price: 100 }]
      )

      result = Builder.call(user: @staff, business_date: "2026-07-21")

      petrol_row = result.settlement.nozzle_readings.find { |r| r.fuel_pump_nozzle_id == @petrol.id }
      assert_equal BigDecimal("5500"), petrol_row.opening_reading
      assert_equal Date.new(2026, 7, 15), petrol_row.prior_closing_date
      assert_equal 5, petrol_row.unsettled_days_before(Date.new(2026, 7, 21))
      assert_equal 0, petrol_row.unsettled_days_before(Date.new(2026, 7, 16))
    end

    # A draft is not a settled figure — the pump may still be selling against it.
    test "ignores a draft settlement when auto-popping" do
      DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 20), recorded_by: @staff, status: "draft",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 4000, closing_reading: 4900, unit_price: 100 }]
      )

      result = Builder.call(user: @staff, business_date: "2026-07-21")

      petrol_row = result.settlement.nozzle_readings.find { |r| r.fuel_pump_nozzle_id == @petrol.id }
      assert_nil petrol_row.opening_reading
      assert_equal "manual", petrol_row.opening_source
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
