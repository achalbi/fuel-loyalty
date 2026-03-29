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

  test "allows the same vehicle number for different customers" do
    vehicle = Vehicle.new(
      customer: customers(:two),
      vehicle_number: vehicles(:one).vehicle_number,
      fuel_type: :diesel,
      vehicle_kind: :lmv
    )

    assert vehicle.valid?
  end

  test "rejects the same vehicle number for the same customer" do
    vehicle = Vehicle.new(
      customer: customers(:one),
      vehicle_number: vehicles(:one).vehicle_number,
      fuel_type: :diesel,
      vehicle_kind: :lmv
    )

    assert_not vehicle.valid?
    assert_includes vehicle.errors[:vehicle_number], "has already been taken"
  end

  test "rejects an inactive fuel type for a new vehicle" do
    fuel_types(:diesel).update!(active: false)

    vehicle = Vehicle.new(
      customer: customers(:one),
      vehicle_number: "TN09AB1234",
      fuel_type: :diesel,
      vehicle_kind: :lmv
    )

    assert_not vehicle.valid?
    assert_includes vehicle.errors[:fuel_type], "is not currently active"
  end

  test "allows keeping an inactive fuel type on an existing vehicle" do
    fuel_types(:petrol).update!(active: false)
    vehicle = vehicles(:one)
    vehicle.vehicle_kind = :three_wheeler

    assert vehicle.valid?
  end

  test "rejects an inactive vehicle type for a new vehicle" do
    vehicle_types(:lmv).update!(active: false)

    vehicle = Vehicle.new(
      customer: customers(:one),
      vehicle_number: "TN09AB5678",
      fuel_type: :diesel,
      vehicle_kind: :lmv
    )

    assert_not vehicle.valid?
    assert_includes vehicle.errors[:vehicle_kind], "is not currently active"
  end

  test "allows keeping an inactive vehicle type on an existing vehicle" do
    vehicle_types(:two_wheeler).update!(active: false)
    vehicle = vehicles(:one)
    vehicle.fuel_type = :diesel

    assert vehicle.valid?
  end

  test "accepts a dynamically added fuel type" do
    FuelType.create!(name: "EV Charging", active: true)

    vehicle = Vehicle.new(
      customer: customers(:one),
      vehicle_number: "TN11EV1234",
      fuel_type: "ev_charging",
      vehicle_kind: :lmv
    )

    assert vehicle.valid?
    assert_equal "EV Charging", vehicle.display_fuel_type
  end

  test "accepts a dynamically added vehicle type" do
    VehicleType.create!(name: "Mini-Van", active: true)

    vehicle = Vehicle.new(
      customer: customers(:one),
      vehicle_number: "TN11MV1234",
      fuel_type: :diesel,
      vehicle_kind: "mini-van"
    )

    assert vehicle.valid?
    assert_equal "mini_van", vehicle.vehicle_kind
    assert_equal "Mini-Van", vehicle.display_vehicle_kind
  end
end
