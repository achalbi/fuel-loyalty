require "test_helper"

class SettlementNozzleReadingTest < ActiveSupport::TestCase
  def reading(**attrs)
    SettlementNozzleReading.new(
      { daily_settlement: DailySettlement.new, fuel_pump_nozzle: fuel_pump_nozzles(:one), unit_price: 100 }.merge(attrs)
    )
  end

  test "derives net litres and amount server-side" do
    r = reading(opening_reading: 84210.5, closing_reading: 85990.0, testing_litres: 5, unit_price: 98.95)
    r.valid?
    assert_equal BigDecimal("1774.5"), r.net_litres_sold # 85990 - 84210.5 - 5
    assert_equal BigDecimal("175586.78"), r.amount.round(2) # 1774.5 * 98.95
  end

  test "rollover treats closing as the post-reset total" do
    r = reading(opening_reading: 99990, closing_reading: 120, testing_litres: 0, rollover: true, unit_price: 100)
    assert r.valid?, r.errors.full_messages.to_sentence
    assert_equal BigDecimal("120"), r.net_litres_sold
    assert_equal BigDecimal("12000"), r.amount
  end

  test "closing below opening without rollover is rejected" do
    r = reading(opening_reading: 100, closing_reading: 90)
    assert_not r.valid?
    assert_includes r.errors[:closing_reading].to_sentence, "opening reading"
  end

  test "testing litres larger than the interval yields a rejected negative net" do
    r = reading(opening_reading: 100, closing_reading: 110, testing_litres: 50)
    assert_not r.valid?
    assert_includes r.errors[:net_litres_sold].to_sentence, "negative"
  end
end
