require "test_helper"

class VehicleTypeTest < ActiveSupport::TestCase
  test "rejects codes with numbers" do
    vehicle_type = VehicleType.new(name: "Mini Van", code: "mini_van_2", active: true)

    assert_not vehicle_type.valid?
    assert_includes vehicle_type.errors[:code], "only allows lowercase letters and underscores"
  end

  test "defaults short name from name when blank" do
    vehicle_type = VehicleType.create!(name: "Light Motor Vehicle", code: "light_motor_vehicle", short_name: "", active: true)

    assert_equal "Light Motor Vehicle", vehicle_type.short_name
  end

  test "uses the configured app label source" do
    vehicle_type = VehicleType.create!(
      name: "Light Motor Vehicle",
      short_name: "LMV",
      app_label_source: "name",
      code: "light_motor_vehicle",
      active: true
    )

    assert_equal "Light Motor Vehicle", vehicle_type.app_label

    vehicle_type.update!(app_label_source: "short_name")

    assert_equal "LMV", vehicle_type.app_label
  end

  test "defaults icon from the vehicle type when blank" do
    vehicle_type = VehicleType.create!(name: "Pickup Truck", code: "pickup_truck", short_name: "Pickup Truck", icon_name: "", active: true)

    assert_equal "ti-truck", vehicle_type.icon_name
  end

  test "defaults auto rickshaw and three wheeler types to the dedicated icon" do
    auto_rickshaw = VehicleType.create!(name: "Auto Rickshaw", code: "auto_rickshaw", short_name: "Auto", icon_name: "", active: true)
    three_wheeler = VehicleType.create!(name: "3 Wheeler", code: "three_wheeler_goods", short_name: "3 Wheeler", icon_name: "", active: true)

    assert_equal "ti-moped", auto_rickshaw.icon_name
    assert_equal "ti-moped", three_wheeler.icon_name
  end
end
