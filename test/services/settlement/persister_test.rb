require "test_helper"

module Settlement
  class PersisterTest < ActiveSupport::TestCase
    setup do
      @pump = fuel_pumps(:one)
      @petrol = fuel_pump_nozzles(:one)
      @staff = users(:two)
      @admin = users(:one)
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

    # --- record on behalf of (staff feedback item 3) ------------------------

    def on_behalf_attrs(**overrides)
      {
        status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100" }],
      }.merge(overrides)
    end

    def record_on_behalf(recorded_for: @staff, actor: @admin, reason: "FSM on sick leave", **overrides)
      Persister.call(
        settlement: DailySettlement.new(fuel_pump: @pump, business_date: Date.new(2026, 7, 21)),
        attributes: on_behalf_attrs(**overrides), actor: actor,
        recorded_for: recorded_for, change_reason: reason
      )
    end

    test "an on-behalf create attributes the sheet to the FSM and the entry to the admin" do
      result = record_on_behalf

      settlement = result.settlement
      assert settlement.persisted?
      # Authorship does NOT move to the admin who typed it.
      assert_equal @staff, settlement.recorded_by
      assert_equal @staff.display_name, settlement.fsm_name_snapshot
      assert_equal @admin, settlement.entered_by
      assert settlement.entered_on_behalf?
      # And the admin may submit directly — the premise is that the FSM cannot.
      assert settlement.submitted?
      assert_not_nil settlement.submitted_at
    end

    test "an on-behalf create writes an audited settlement_changes row" do
      result = nil
      assert_difference -> { SettlementChange.count }, 1 do
        result = record_on_behalf(reason: "Ravi's phone was dead; sheet dictated at the counter")
      end

      change = result.change
      assert_equal result.settlement, change.daily_settlement
      assert_equal @admin, change.changed_by
      assert_equal "Ravi's phone was dead; sheet dictated at the counter", change.change_reason
      # The create diff records the attribution, not just the money: who it is
      # for, who typed it, and which slot it fills.
      assert_equal [nil, @staff.id.to_s], change.field_diffs["recorded_by_id"]
      assert_equal [nil, @admin.id.to_s], change.field_diffs["entered_by_id"]
      assert_equal [nil, @staff.display_name], change.field_diffs["fsm_name_snapshot"]
      assert_equal [nil, "2026-07-21"], change.field_diffs["business_date"]
      assert_equal ["draft", "submitted"], change.field_diffs["status"]
      assert_equal "10275.0", change.field_diffs["total_fuel_amount"].last # 100 L x 102.75
      assert_not change.recomputed_points
    end

    test "an on-behalf create with a blank reason saves nothing" do
      assert_no_difference [-> { DailySettlement.count }, -> { SettlementChange.count }] do
        assert_raises(ActiveRecord::RecordInvalid) { record_on_behalf(reason: "") }
      end
    end

    test "an admin may enter a sheet under their own name and it is still audited" do
      # Single-admin site: the admin is the operator too. Attribution and entry
      # land on the same person, but the audit row still exists.
      result = record_on_behalf(recorded_for: @admin)

      assert_equal @admin, result.settlement.recorded_by
      assert_equal @admin, result.settlement.entered_by
      assert result.settlement.self_entered_by_admin?
      assert_not result.settlement.entered_on_behalf?
      assert_not_nil result.change
    end

    test "a duplicate slot is refused and leaves no audit row behind" do
      record_on_behalf

      assert_no_difference [-> { DailySettlement.count }, -> { SettlementChange.count }] do
        assert_raises(ActiveRecord::RecordInvalid) { record_on_behalf }
      end
    end

    test "a plain staff save is still unaudited and still claims the sheet" do
      # The regression guard for the normal path: no recorded_for means the old
      # `recorded_by ||= actor` behaviour and NO settlement_changes row.
      settlement = DailySettlement.new(fuel_pump: @pump, business_date: Date.new(2026, 7, 21))

      result = nil
      assert_no_difference -> { SettlementChange.count } do
        result = Persister.call(settlement: settlement, attributes: on_behalf_attrs, actor: @staff)
      end

      assert_equal @staff, result.settlement.recorded_by
      assert_nil result.settlement.entered_by_id
      assert_nil result.change
    end
  end
end
