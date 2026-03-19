require "test_helper"

class VehicleTest < ActiveSupport::TestCase
  test "accepts a normalized standard vehicle number" do
    vehicle = Vehicle.new(
      customer: customers(:one),
      vehicle_number: "TN 01 AA 1234",
      fuel_type: :petrol,
      vehicle_kind: :two_wheeler
    )

    assert vehicle.valid?
    assert_equal "TN01AA1234", vehicle.vehicle_number
  end

  test "accepts a BH series vehicle number" do
    vehicle = Vehicle.new(
      customer: customers(:one),
      vehicle_number: "22 bh 1234 aa",
      fuel_type: :diesel,
      vehicle_kind: :lmv
    )

    assert vehicle.valid?
    assert_equal "22BH1234AA", vehicle.vehicle_number
  end

  test "rejects an invalid vehicle number" do
    vehicle = Vehicle.new(
      customer: customers(:one),
      vehicle_number: "INVALID123",
      fuel_type: :diesel,
      vehicle_kind: :lmv
    )

    assert_not vehicle.valid?
    assert_includes vehicle.errors[:vehicle_number], "is invalid"
  end
end
