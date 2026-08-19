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

  test "digital receipts and cash taken out reduce the amount to settle" do
    # Items 10 and 12: any means can be recorded, and a salary advance taken
    # from the day's cash means the FSM hands over that much less.
    settlement = DailySettlement.new(base_attrs(
      digital_receipts_attributes: [
        { label: "PhonePe POS", amount: 2000 },
        { label: "PAYTM", amount: 500 }
      ],
      expense_lines_attributes: [{ description: "Salary advance — Ravi", amount: 1000 }],
      cash_denominations_attributes: [{ denomination: 500, quantity: 12 }]
    ))
    assert settlement.save, settlement.errors.full_messages.to_sentence

    assert_equal BigDecimal("2500"), settlement.total_digital_receipt_amount
    assert_equal BigDecimal("1000"), settlement.total_expense_amount
    # 10000 fuel − (2500 digital + 1000 taken out) = 6500
    assert_equal BigDecimal("6500"), settlement.final_amount_to_settle
    assert_equal BigDecimal("500"), settlement.shortage_amount # 6500 − 6000 counted
  end

  test "the same digital means cannot be recorded twice" do
    settlement = DailySettlement.new(base_attrs(
      digital_receipts_attributes: [{ label: "PAYTM", amount: 100 }, { label: "paytm", amount: 200 }]
    ))

    assert_not settlement.save
    assert_match(/same digital means was submitted more than once/i, settlement.errors.full_messages.to_sentence)
  end

  test "a discount added during settlement counts even with no visit entry" do
    # Item 11 — a discount missed at capture, entered on the settlement sheet.
    settlement = DailySettlement.new(base_attrs(
      discount_lines_attributes: [{ transport_name: "Walk-in", litres: 20, discount_amount: 300 }]
    ))
    assert settlement.save, settlement.errors.full_messages.to_sentence

    assert_equal BigDecimal("300"), settlement.total_discount_amount
    assert_nil settlement.discount_lines.first.visit_entry_id
  end

  test "an empty added discount row is dropped rather than saved" do
    settlement = DailySettlement.new(base_attrs(
      discount_lines_attributes: [{ transport_name: "", litres: "", discount_amount: "" }]
    ))
    assert settlement.save, settlement.errors.full_messages.to_sentence

    assert_empty settlement.discount_lines
  end

  test "re-posting saved children without their ids is refused, not duplicated" do
    # The "settlement multiplying on a second submit" bug (staff feedback item
    # 6): a client that forgets the ids it was handed back would otherwise append
    # a whole second set of rows and double every total.
    settlement = DailySettlement.create!(base_attrs(
      lube_lines_attributes: [{ product_id: @lube.id, quantity: 2, unit_price: 500 }],
      cash_denominations_attributes: [{ denomination: 500, quantity: 4 }]
    ))
    original_fuel_total = settlement.total_fuel_amount

    settlement.assign_attributes(
      nozzle_readings_attributes: [
        { fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }
      ]
    )

    assert_not settlement.save
    assert_includes settlement.errors.full_messages.to_sentence, "same nozzle was submitted more than once"
    assert_equal original_fuel_total, settlement.reload.total_fuel_amount
    assert_equal 1, settlement.nozzle_readings.count
  end

  test "credit lines accept the three customer account types" do
    settlement = DailySettlement.new(base_attrs(
      credit_lines_attributes: [
        { credit_type: "drive_in", amount: 100 },
        { credit_type: "credit", amount: 200 },
        { credit_type: "fleet_otp", amount: 300 }
      ]
    ))

    assert settlement.save, settlement.errors.full_messages.to_sentence
    assert_equal %w[drive_in credit fleet_otp].sort, settlement.credit_lines.map(&:credit_type).sort
    assert_equal BigDecimal("600"), settlement.total_credit_amount
    assert_equal ["Drive-In", "Credit", "Fleet/OTP"], SettlementCreditLine.credit_type_options.map(&:first)
  end

  test "final amount and shortage follow the D6/D7 formulas" do
    settlement = DailySettlement.new(base_attrs(
      digital_receipts_attributes: [{ label: "PhonePe POS", amount: 2000 }, { label: "PhonePe Scanner", amount: 1000 }],
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
