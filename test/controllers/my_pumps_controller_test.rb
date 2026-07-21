require "test_helper"

class MyPumpsControllerTest < ActionDispatch::IntegrationTest
  # Self-service pump assignment ("My Pump") is disabled for staff (S-MYPUMP);
  # an admin assigns pumps via Admin::StaffMembersController#pump (A10).
  test "staff cannot access the my pump page" do
    sign_in users(:two)

    get my_pump_path

    assert_redirected_to root_path
  end

  test "staff cannot update their own pump" do
    sign_in users(:two)
    before_pump = users(:two).fuel_pump_id

    patch my_pump_path, params: {
      user: { fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: ["", fuel_pump_nozzles(:one).id] }
    }

    assert_redirected_to root_path
    assert_equal before_pump, users(:two).reload.fuel_pump_id
  end

  test "staff no longer see the my pump nav link" do
    sign_in users(:two)

    get new_staff_transaction_path

    assert_response :success
    assert_select "a.nav-link[href='#{my_pump_path}']", count: 0
  end

  test "admin can still view the my pump page" do
    sign_in users(:one)

    get my_pump_path

    assert_response :success
    assert_select "h1", text: "My Pump"
    assert_select "a.nav-link.active[href='#{my_pump_path}']", text: /My Pump/
  end
end
