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
    # `opening_source` is the audit answer to "was this meter reading inherited
    # or typed?", so the server derives it from what it offered — a client that
    # names its own source could call every correction an inheritance.
    test "marks an opening taken from the prior settlement as inherited" do
      prior_settlement(closing: "1200", on: Date.new(2026, 7, 20))

      reading = persist(opening: "1200", closing: "1500")

      assert_equal "prior_settlement", reading.opening_source
      assert_equal BigDecimal("1200"), reading.prior_closing_reading
      assert_equal Date.new(2026, 7, 20), reading.prior_closing_date
    end

    test "marks an opening the FSM typed over as corrected, keeping what was offered" do
      prior_settlement(closing: "1200", on: Date.new(2026, 7, 15))

      reading = persist(opening: "1850.500", closing: "2000")

      assert_equal "corrected", reading.opening_source
      assert_equal BigDecimal("1850.5"), reading.opening_reading
      assert_equal BigDecimal("1200"), reading.prior_closing_reading, "the offered figure survives the override"
      assert_equal 5, reading.unsettled_days_before
    end

    test "refuses a client-supplied opening_source" do
      prior_settlement(closing: "1200", on: Date.new(2026, 7, 20))

      reading = persist(opening: "9999", closing: "10000", extra: { opening_source: "prior_settlement" })

      assert_equal "corrected", reading.opening_source
    end

    test "a nozzle with no settled history is manual, not corrected" do
      reading = persist(opening: "500", closing: "700")

      assert_equal "manual", reading.opening_source
      assert_nil reading.prior_closing_reading
      assert_equal 0, reading.unsettled_days_before
    end

    test "re-saving a draft keeps the figure that was offered when it was built" do
      prior_settlement(closing: "1200", on: Date.new(2026, 7, 20))
      reading = persist(opening: "1200", closing: "1500", status: "draft")

      # A colleague files an earlier shift afterwards; what this sheet was shown
      # when it was drafted does not change retroactively.
      DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 20), recorded_by: @staff, status: "submitted",
        shift_template: shift_templates(:night_shift),
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1200, closing_reading: 1400, unit_price: 100 }]
      )
      settlement = reading.daily_settlement
      Persister.call(
        settlement: settlement, actor: @staff,
        attributes: { nozzle_readings_attributes: [{ id: reading.id, opening_reading: "1200", closing_reading: "1600" }] }
      )

      assert_equal BigDecimal("1200"), reading.reload.prior_closing_reading
      assert_equal "prior_settlement", reading.opening_source
    end

    private

    def prior_settlement(closing:, on:)
      DailySettlement.create!(
        fuel_pump: @pump, business_date: on, recorded_by: @staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 0, closing_reading: closing, unit_price: 100 }]
      )
    end

    def persist(opening:, closing:, status: "submitted", extra: {})
      result = Persister.call(
        settlement: DailySettlement.new(fuel_pump: @pump, business_date: Date.new(2026, 7, 21)),
        actor: @staff,
        attributes: {
          status: status,
          nozzle_readings_attributes: [
            { fuel_pump_nozzle_id: @petrol.id, opening_reading: opening, closing_reading: closing }.merge(extra),
          ],
        }
      )
      result.settlement.nozzle_readings.first
    end
  end
end
