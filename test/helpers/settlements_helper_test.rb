require "test_helper"

# The helper exists for exactly one reason: on a reprint of an entered sheet, a
# figure nobody typed must not read as a figure someone typed as zero. "—" and
# "₹0.00" are different claims about the shift, and only these tests keep them
# apart.
class SettlementsHelperTest < ActionView::TestCase
  include SettlementsHelper

  test "a missing figure is an em dash, never a zero" do
    assert_equal "—", settlement_money(nil)
    assert_equal "—", settlement_litres(nil)
    assert_equal "—", settlement_price(nil)
    assert_equal "—", settlement_count(nil)
  end

  test "a real zero is printed as a zero" do
    assert_equal "₹0.00", settlement_money(0)
    assert_equal "0", settlement_litres(0)
    assert_equal "0.00", settlement_price(0)
    assert_equal "0", settlement_count(0)
  end

  # No thousands separator, deliberately: the entry form captures these in number
  # inputs that show none, and a meter reading is read digit-for-digit against the
  # pump head, not scanned as a money figure.
  test "litres keep the reading precision the form captures, without trailing noise" do
    assert_equal "1234.567", settlement_litres(BigDecimal("1234.567"))
    assert_equal "450", settlement_litres(BigDecimal("450.000"))
    assert_equal "0.5", settlement_litres(BigDecimal("0.500"))
  end

  test "money keeps two decimals and the rupee unit" do
    assert_equal "₹50,112.00", settlement_money(BigDecimal("50112"))
    assert_equal "₹1,234.57", settlement_money(BigDecimal("1234.567"))
  end

  test "the status badge follows the settlement, not the caller" do
    settlement = DailySettlement.new(status: :draft)
    assert_equal "text-bg-secondary", settlement_status_badge_class(settlement)
    settlement.status = :submitted
    assert_equal "text-bg-primary", settlement_status_badge_class(settlement)
    settlement.status = :reconciled
    assert_equal "text-bg-success", settlement_status_badge_class(settlement)
  end
end
