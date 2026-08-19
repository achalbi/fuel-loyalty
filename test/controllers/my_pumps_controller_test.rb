require "test_helper"

class MyPumpsControllerTest < ActionDispatch::IntegrationTest
  test "staff can access the my pump page" do
    sign_in users(:two)

    get my_pump_path

    assert_response :success
    assert_select "h1", text: "My Pump"
    assert_select "input[name='assignment_date']", 0
    assert_select "[data-my-pump-assignment-date]", text: /today/
  end

  test "staff can update their own pump for today" do
    sign_in users(:two)
    default_pump_id = users(:two).fuel_pump_id
    target_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
    target_nozzle = target_pump.nozzles.first

    patch my_pump_path, params: {
      assignment_date: Date.current.iso8601,
      user: { fuel_pump_id: target_pump.id, assigned_fuel_pump_nozzle_ids: ["", target_nozzle.id] }
    }

    assert_redirected_to my_pump_path
    user = users(:two).reload
    assert_equal default_pump_id, user.fuel_pump_id
    assert_equal target_pump, user.transaction_fuel_pump
    assert_equal Date.current, user.pump_assignment_for&.assigned_on
  end

  test "staff cannot schedule a future pump override" do
    sign_in users(:two)

    patch my_pump_path, params: {
      assignment_date: 1.day.from_now.to_date.iso8601,
      user: { fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: ["", fuel_pump_nozzles(:one).id] }
    }

    assert_redirected_to my_pump_path
    assert_equal MyPumpsController::TODAY_ONLY_MESSAGE, flash[:alert]
    assert_nil users(:two).reload.pump_assignment_for(on: 1.day.from_now.to_date)
  end

  test "admin cannot schedule my pump for another day either" do
    sign_in users(:one)

    patch my_pump_path, params: {
      assignment_date: 1.day.from_now.to_date.iso8601,
      user: { fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: ["", fuel_pump_nozzles(:one).id] }
    }

    assert_redirected_to my_pump_path
    assert_equal MyPumpsController::TODAY_ONLY_MESSAGE, flash[:alert]
    assert_nil users(:one).reload.pump_assignment_for(on: 1.day.from_now.to_date)
  end

  test "admin cannot back-date my pump" do
    sign_in users(:one)

    get my_pump_path(assignment_date: 1.day.ago.to_date.iso8601)

    assert_redirected_to my_pump_path
    assert_equal MyPumpsController::TODAY_ONLY_MESSAGE, flash[:alert]
  end

  test "staff see the my pump nav link" do
    sign_in users(:two)

    get new_staff_transaction_path

    assert_response :success
    assert_select "a.nav-link[href='#{my_pump_path}']", count: 1
  end

  test "admin can still view the my pump page" do
    sign_in users(:one)

    get my_pump_path

    assert_response :success
    assert_select "h1", text: "My Pump"
    assert_select "a.nav-link.active[href='#{my_pump_path}']", text: /My Pump/
    assert_select "input[name='assignment_date']", 0
  end

  test "admin can set their own pump for today" do
    sign_in users(:one)
    target_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
    target_nozzle = target_pump.nozzles.first

    patch my_pump_path, params: {
      user: { fuel_pump_id: target_pump.id, assigned_fuel_pump_nozzle_ids: ["", target_nozzle.id] }
    }

    assert_redirected_to my_pump_path
    assert_equal Date.current, users(:one).reload.pump_assignment_for&.assigned_on
  end
end
