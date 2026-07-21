require "test_helper"

module Settlement
  class PersisterTest < ActiveSupport::TestCase
    setup do
      @pump = fuel_pumps(:one)
      @petrol = fuel_pump_nozzles(:one)
      @staff = users(:two)
      Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 120, selling_price: 102.75)
    end

    test "snapshots the catalog price server-side when the client omits unit_price" do
      settlement = DailySettlement.new(fuel_pump: @pump, business_date: Date.new(2026, 7, 21))
      attrs = {
        status: "submitted",
        nozzle_readings_attributes: [
          { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1200", testing_litres: "0" },
        ],
        rate_comparisons_attributes: [{ fuel_type_code: "petrol", competitor_name: "JIO-BP", competitor_price: "103.00" }],
      }

      result = Persister.call(settlement: settlement, attributes: attrs, actor: @staff)
      assert result.settlement.persisted?

      reading = result.settlement.nozzle_readings.first
      assert_equal BigDecimal("102.75"), reading.unit_price, "price must be derived, not trusted from client"
      assert_equal "petrol", reading.fuel_type_code_snapshot
      assert_equal BigDecimal("200"), reading.net_litres_sold
      assert_equal BigDecimal("20550"), reading.amount # 200 * 102.75
      assert_equal BigDecimal("20550"), result.settlement.total_fuel_amount

      rate = result.settlement.rate_comparisons.first
      assert_equal BigDecimal("102.75"), rate.own_price # snapshotted from catalog
    end

    test "submitting stamps submitted_at and sets recorded_by" do
      settlement = DailySettlement.new(fuel_pump: @pump, business_date: Date.new(2026, 7, 21))
      result = Persister.call(
        settlement: settlement, actor: @staff,
        attributes: { status: "submitted", nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: "1", closing_reading: "2" }] }
      )
      assert_equal @staff, result.settlement.recorded_by
      assert_not_nil result.settlement.submitted_at
      assert_not result.settlement.locked?
    end
  end
end
