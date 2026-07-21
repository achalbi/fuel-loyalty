require "test_helper"

class DailySettlementTest < ActiveSupport::TestCase
  setup do
    @pump = fuel_pumps(:one)
    @petrol = fuel_pump_nozzles(:one)
    @diesel = fuel_pump_nozzles(:two)
    @staff = users(:two)
    Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 100, selling_price: 100)
    Product.create!(name: "HSD", category: "fuel", fuel_type_code: "diesel", pack_unit: "litre", mrp: 90, selling_price: 90)
    @lube = Product.create!(name: "10W30", category: "lubricant", pack_size: 1, pack_unit: "L", mrp: 500, selling_price: 500)
  end

  def base_attrs(**overrides)
    {
      fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
      nozzle_readings_attributes: [
        { fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, testing_litres: 0, unit_price: 100 },
      ],
    }.merge(overrides)
  end

  test "final amount and shortage follow the D6/D7 formulas" do
    settlement = DailySettlement.new(base_attrs(
      phonepe_pos_amount: 2000, phonepe_scanner_amount: 1000,
      lube_lines_attributes: [{ product_id: @lube.id, quantity: 2, unit_price: 500 }],
      discount_lines_attributes: [{ litres: 10, discount_amount: 300 }],
      credit_lines_attributes: [{ credit_type: "fleet_otp", amount: 1500 }],
      cash_denominations_attributes: [{ denomination: 500, quantity: 12 }]
    ))
    assert settlement.save, settlement.errors.full_messages.to_sentence

    assert_equal BigDecimal("10000"), settlement.total_fuel_amount   # 100L * 100
    assert_equal BigDecimal("1000"), settlement.total_lube_amount    # 2 * 500
    assert_equal BigDecimal("300"), settlement.total_discount_amount
    assert_equal BigDecimal("1500"), settlement.total_credit_amount
    assert_equal BigDecimal("6000"), settlement.counted_cash_amount  # 12 * 500
    # (10000 + 1000) - (300 + 1500 + 2000 + 1000) = 6200
    assert_equal BigDecimal("6200"), settlement.final_amount_to_settle
    assert_equal BigDecimal("200"), settlement.shortage_amount       # 6200 - 6000
  end

  test "a second settlement for the same pump/date/shift is rejected" do
    assert DailySettlement.new(base_attrs).save
    dup = DailySettlement.new(base_attrs)
    assert_not dup.save
    assert_includes dup.errors[:base].to_sentence, "already been recorded"
  end

  test "submitting requires a closing reading and a resolved price on every nozzle" do
    settlement = DailySettlement.new(base_attrs(
      status: "submitted",
      nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, unit_price: 100 }]
    ))
    assert_not settlement.save
    assert_includes settlement.errors[:base].to_sentence, "Enter today's reading"
  end

  test "a submitted nozzle with no catalog price is blocked" do
    settlement = DailySettlement.new(base_attrs(
      status: "submitted",
      nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: nil }]
    ))
    assert_not settlement.save
    assert_includes settlement.errors[:base].to_sentence, "No active catalog price"
  end

  test "prior_closing_reading auto-pops from the latest financial settlement" do
    DailySettlement.create!(base_attrs(
      status: "submitted",
      nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1250, unit_price: 100 }]
    ))
    assert_equal BigDecimal("1250"), DailySettlement.prior_closing_reading(@petrol.id, Date.new(2026, 7, 22))
    assert_nil DailySettlement.prior_closing_reading(@petrol.id, Date.new(2026, 7, 21)) # same day, not < date
  end
end
