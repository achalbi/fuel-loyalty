require "test_helper"

# The audit in db/queries/settlement_totals_audit.sql is raw SQL, so nothing in
# the app stops a column rename from quietly breaking it — and a broken audit
# fails open: it returns no rows and reads exactly like "everything is fine".
# These tests keep it honest by running it against the real schema and proving
# it still catches the damage it was written to find.
class SettlementTotalsAuditTest < ActiveSupport::TestCase
  QUERIES = Rails.root.join("db/queries/settlement_totals_audit.sql").read
    .split(/;\s*$/)
    .map(&:strip)
    .reject { |chunk| chunk.empty? || chunk.lines.all? { |line| line.strip.start_with?("--") || line.strip.empty? } }

  MISMATCH_QUERY = QUERIES.first

  setup do
    @pump = fuel_pumps(:one)
    @nozzle = fuel_pump_nozzles(:one)
    @settlement = DailySettlement.create!(
      fuel_pump: @pump, business_date: Date.new(2026, 8, 1), recorded_by: users(:two),
      nozzle_readings_attributes: [
        { fuel_pump_nozzle_id: @nozzle.id, opening_reading: 100, closing_reading: 200, unit_price: 100 }
      ],
      cash_denominations_attributes: [{ denomination: 500, quantity: 4 }],
      digital_receipts_attributes: [{ label: "PhonePe POS", amount: 1500 }]
    )
  end

  test "every query in the file runs against the current schema" do
    assert_equal 3, QUERIES.size, "expected three queries in the audit file"

    QUERIES.each_with_index do |sql, index|
      ActiveRecord::Base.connection.select_all(sql)
    rescue ActiveRecord::StatementInvalid => error
      flunk "query #{index + 1} no longer matches the schema: #{error.message}"
    end
  end

  test "a settlement whose totals match its lines is not flagged" do
    flagged = ActiveRecord::Base.connection.select_all(MISMATCH_QUERY).to_a

    assert_empty flagged.select { |row| row["id"] == @settlement.id }
  end

  test "a doubled header is flagged and named" do
    # Exactly the damage the item-6 bug produced: children posted twice, so the
    # stored totals are twice what the surviving lines add up to.
    @settlement.update_columns(
      total_fuel_amount: @settlement.total_fuel_amount * 2,
      final_amount_to_settle: @settlement.final_amount_to_settle * 2
    )

    row = ActiveRecord::Base.connection.select_all(MISMATCH_QUERY).to_a
      .find { |candidate| candidate["id"] == @settlement.id }

    assert_not_nil row, "the audit missed a settlement with doubled totals"
    assert_equal "looks doubled", row["diagnosis"]
    assert_equal @settlement.reload.total_fuel_amount, row["total_fuel_amount"]
    assert_equal BigDecimal("10000"), row["lines_fuel"] # 100 L × ₹100
  end

  test "a drifted total that is not a doubling is flagged as other drift" do
    @settlement.update_columns(counted_cash_amount: @settlement.counted_cash_amount + 1)

    row = ActiveRecord::Base.connection.select_all(MISMATCH_QUERY).to_a
      .find { |candidate| candidate["id"] == @settlement.id }

    assert_not_nil row
    assert_equal "other drift", row["diagnosis"]
  end

  test "the unique indexes the audit checks for are all present" do
    names = ActiveRecord::Base.connection
      .select_values("SELECT indexname FROM pg_indexes WHERE indexname LIKE '%_on_settlement_key'")

    # One per keyed child: nozzle readings, lube lines, denominations, digital
    # receipts, stock receipts, rate comparisons.
    assert_equal 6, names.size, "a keyed child lost its unique index: #{names.sort}"
  end
end
