require "test_helper"

class VisitEntryTest < ActiveSupport::TestCase
  def base_attrs(**overrides)
    { user: users(:two), fuel_pump: fuel_pumps(:one), entry_date: Date.current,
      vehicle_number: "TN01AA1111", litres: 10 }.merge(overrides)
  end

  test "requires a vehicle number and a positive litres" do
    entry = VisitEntry.new(base_attrs(vehicle_number: "", litres: 0))
    assert_not entry.valid?
    assert entry.errors[:vehicle_number].any?
    assert entry.errors[:litres].any?
  end

  test "normalizes the vehicle number and contact phones" do
    entry = VisitEntry.create!(base_attrs(vehicle_number: "ka 01 ab 1234", driver_phone_number: "90000 11122"))
    assert_equal "KA01AB1234", entry.vehicle_number
    assert_equal "9000011122", entry.driver_phone_number
  end

  test "defaults a blank discount to zero" do
    entry = VisitEntry.create!(base_attrs(discount_amount: ""))
    assert_equal 0, entry.discount_amount
  end

  test "rejects a malformed driver phone" do
    entry = VisitEntry.new(base_attrs(driver_phone_number: "123"))
    assert_not entry.valid?
    assert entry.errors[:driver_phone_number].any?
  end

  test "for_pump_day scopes to a pump and date" do
    entry = VisitEntry.create!(base_attrs)
    assert_includes VisitEntry.for_pump_day(fuel_pumps(:one), Date.current), entry
    assert_not_includes VisitEntry.for_pump_day(fuel_pumps(:one), Date.current - 1), entry
  end
end
