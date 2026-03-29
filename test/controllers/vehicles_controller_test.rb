require "test_helper"

class VehiclesControllerTest < ActionDispatch::IntegrationTest
  test "staff can add a vehicle for a customer" do
    sign_in users(:two)

    assert_difference -> { customers(:one).vehicles.count }, 1 do
      post customer_vehicles_path(customers(:one)), params: {
        vehicle: {
          vehicle_number: "TN 55 ZZ 1234",
          fuel_type: "diesel",
          vehicle_kind: "lmv"
        }
      }
    end

    assert_redirected_to customer_path(customers(:one))
  end

  test "staff can edit a vehicle" do
    sign_in users(:two)

    get edit_customer_vehicle_path(customers(:one), vehicles(:one))
    assert_response :success

    patch customer_vehicle_path(customers(:one), vehicles(:one)), params: {
      vehicle: {
        vehicle_number: "TN 11 AA 4321",
        fuel_type: "diesel",
        vehicle_kind: "three_wheeler"
      }
    }

    assert_redirected_to customer_path(customers(:one))
    vehicle = vehicles(:one).reload
    assert_equal "TN11AA4321", vehicle.vehicle_number
    assert_equal "diesel", vehicle.fuel_type
    assert_equal "three_wheeler", vehicle.vehicle_kind
  end

  test "edit vehicle keeps its inactive fuel type visible as a radio option" do
    sign_in users(:two)
    fuel_types(:petrol).update!(active: false)

    get edit_customer_vehicle_path(customers(:one), vehicles(:one))

    assert_response :success
    assert_select "input[type='radio'][name='vehicle[fuel_type]'][value='petrol'][checked]", 1
    assert_select "select[name='vehicle[fuel_type]']", 0
  end

  test "edit vehicle keeps its inactive vehicle type visible as a radio option" do
    sign_in users(:two)
    vehicle_types(:two_wheeler).update!(active: false)

    get edit_customer_vehicle_path(customers(:one), vehicles(:one))

    assert_response :success
    assert_select "input[type='radio'][name='vehicle[vehicle_kind]'][value='two_wheeler'][checked]", 1
    assert_select "label[for='vehicle_#{vehicles(:one).id}_vehicle_kind_two_wheeler'] i.ti.ti-bike", 1
    assert_select "select[name='vehicle[vehicle_kind]']", 0
  end

  test "staff can delete a vehicle without transaction history" do
    sign_in users(:two)
    vehicle = customers(:one).vehicles.create!(vehicle_number: "TN44AB9999", fuel_type: :petrol, vehicle_kind: :lmv)

    assert_difference -> { customers(:one).vehicles.count }, -1 do
      delete customer_vehicle_path(customers(:one), vehicle)
    end

    assert_redirected_to customer_path(customers(:one))
  end

  test "invalid vehicle create re-renders customer page without crashing" do
    sign_in users(:two)

    assert_no_difference -> { customers(:one).vehicles.count } do
      post customer_vehicles_path(customers(:one)), params: {
        vehicle: {
          vehicle_number: vehicles(:one).vehicle_number,
          fuel_type: "diesel",
          vehicle_kind: "lmv"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Vehicle number has already been taken", response.body
    assert_match vehicles(:two).vehicle_number, response.body
  end

  test "invalid vehicle edit from modal re-renders customer page and reopens matching modal" do
    sign_in users(:two)

    patch customer_vehicle_path(customers(:one), vehicles(:one)), params: {
      vehicle_form_context: "modal",
      vehicle: {
        vehicle_number: vehicles(:two).vehicle_number,
        fuel_type: "diesel",
        vehicle_kind: "lmv"
      }
    }

    assert_response :unprocessable_entity
    assert_match "Vehicle number has already been taken", response.body
    assert_match "editVehicleModal-#{vehicles(:one).id}", response.body
    assert_match 'data-auto-open-modal="true"', response.body
  end
end
