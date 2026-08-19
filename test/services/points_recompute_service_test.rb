require "test_helper"

class PointsRecomputeServiceTest < ActiveSupport::TestCase
  setup do
    @pump = fuel_pumps(:one)
    @petrol = fuel_pump_nozzles(:one)
    @staff = users(:two)
    @admin = users(:one)
    @staff.update!(fuel_pump_id: @pump.id, assigned_fuel_pump_nozzle_ids: [@petrol.id])
    Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 100, selling_price: 100)

    # A B2 capture that links a loyalty transaction (10 L × ₹100 = ₹1000, no discount).
    result = VisitEntryRecorder.call(
      user: @staff,
      attributes: { vehicle_number: vehicles(:one).vehicle_number, litres: 10, discount_amount: 0 },
      create_transaction: true, fuel_pump_nozzle_id: @petrol.id
    )
    @visit = result.visit_entry
    @transaction = result.transaction
  end

  test "an admin discount-line edit propagates to the linked transaction ₹ and re-awards points" do
    settlement = DailySettlement.create!(
      fuel_pump: @pump, business_date: @visit.entry_date, recorded_by: @staff, status: "submitted",
      nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }],
      discount_lines_attributes: [SettlementDiscountLine.from_visit_entry(@visit).attributes.compact]
    )
    line = settlement.discount_lines.first
    assert_equal @visit.id, line.visit_entry_id
    assert_equal BigDecimal("1000"), @transaction.reload.fuel_amount

    result = Settlement::Persister.call(
      settlement: settlement, actor: @admin, admin_edit: true, change_reason: "Applied ₹200 fleet discount",
      attributes: { discount_lines_attributes: [{ id: line.id, discount_amount: "200" }] }
    )

    assert result.points_recomputed, "a customer-linked discount change must recompute points"
    @transaction.reload
    assert_equal BigDecimal("800"), @transaction.fuel_amount   # gross 1000 − 200
    assert_equal BigDecimal("200"), @transaction.discount_amount

    expected_points = PointsCalculator.call(800, fuel_type: "petrol", vehicle_kind: "two_wheeler", litres: 10)
    earn = @transaction.customer.points_ledgers.find_by(fuel_transaction: @transaction, entry_type: :earn)
    assert_equal expected_points, earn.points
    assert settlement.audit_changes.last.recomputed_points
  end

  test "an edit that touches no customer-linked figure does not recompute" do
    settlement = DailySettlement.create!(
      fuel_pump: @pump, business_date: @visit.entry_date, recorded_by: @staff, status: "submitted",
      nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }]
    )
    result = Settlement::Persister.call(
      settlement: settlement, actor: @admin, admin_edit: true, change_reason: "note",
      attributes: { digital_receipts_attributes: [{ label: "PhonePe POS", amount: "50" }] }
    )
    assert_not result.points_recomputed
    assert_equal BigDecimal("1000"), @transaction.reload.fuel_amount
  end
end
