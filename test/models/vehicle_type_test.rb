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

    assert_equal "custom-pickup-truck", vehicle_type.icon_name
  end

  test "defaults big truck icon for heavy truck types when blank" do
    vehicle_type = VehicleType.create!(name: "Big Truck", code: "heavy_truck", short_name: "Big Truck", icon_name: "", active: true)

    assert_equal "custom-big-truck", vehicle_type.icon_name
  end

  test "defaults auto rickshaw and three wheeler types to the dedicated icon" do
    auto_rickshaw = VehicleType.create!(name: "Auto Rickshaw", code: "auto_rickshaw", short_name: "Auto", icon_name: "", active: true)
    three_wheeler = VehicleType.create!(name: "3 Wheeler", code: "three_wheeler_goods", short_name: "3 Wheeler", icon_name: "", active: true)

    assert_equal "custom-tuk-tuk", auto_rickshaw.icon_name
    assert_equal "custom-tuk-tuk", three_wheeler.icon_name
  end

  test "maps removed two wheeler icon types back to bike" do
    motorbike = VehicleType.create!(name: "Motorbike", code: "motorbike", short_name: "Motorbike", icon_name: "", active: true)
    scooter = VehicleType.create!(name: "Electric Scooter", code: "electric_scooter", short_name: "E Scooter", icon_name: "", active: true)

    assert_equal "ti-bike", motorbike.icon_name
    assert_equal "ti-bike", scooter.icon_name
  end

  test "maps removed specialized vehicle icon types to supported icons" do
    suv = VehicleType.create!(name: "SUV", code: "suv", short_name: "SUV", icon_name: "", active: true)
    ambulance = VehicleType.create!(name: "Ambulance", code: "ambulance", short_name: "Ambulance", icon_name: "", active: true)
    caravan = VehicleType.create!(name: "Caravan", code: "caravan", short_name: "Caravan", icon_name: "", active: true)

    assert_equal "ti-car", suv.icon_name
    assert_equal "ti-truck", ambulance.icon_name
    assert_equal "ti-bus", caravan.icon_name
  end

  test "normalizes removed legacy icon selections to supported icons" do
    suv = VehicleType.create!(name: "SUV", code: "sport_utility_vehicle", short_name: "SUV", icon_name: "ti-car-suv", active: true)
    forklift = VehicleType.create!(name: "Forklift", code: "forklift", short_name: "Forklift", icon_name: "ti-forklift", active: true)
    caravan = VehicleType.create!(name: "Caravan", code: "caravan", short_name: "Caravan", icon_name: "ti-caravan", active: true)

    assert_equal "ti-car", suv.icon_name
    assert_equal "ti-truck", forklift.icon_name
    assert_equal "ti-bus", caravan.icon_name
  end
end
