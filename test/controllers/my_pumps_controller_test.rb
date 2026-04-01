require "test_helper"

class MyPumpsControllerTest < ActionDispatch::IntegrationTest
  test "staff can view my pump page" do
    sign_in users(:two)

    get my_pump_path

    assert_response :success
    assert_select "h1", text: "My Pump"
    assert_select "form[action='#{my_pump_path}'][data-my-pump-form='true']"
    assert_select "select[name='user[fuel_pump_id]'] option[selected]", text: "Pump 1"
    assert_select ".my-pump-nozzle-option[data-my-pump-nozzle-option]", minimum: 2
    assert_select ".my-pump-nozzle-card", minimum: 2
    assert_select "input.my-pump-nozzle-card__input[data-my-pump-nozzle-input][type='checkbox'][name='user[assigned_fuel_pump_nozzle_ids][]'][value='#{fuel_pump_nozzles(:one).id}'][checked='checked']", 1
    assert_select "input.my-pump-nozzle-card__input[data-my-pump-nozzle-input][type='checkbox'][name='user[assigned_fuel_pump_nozzle_ids][]'][value='#{fuel_pump_nozzles(:two).id}'][checked='checked']", 1
    assert_select "a.btn.btn-outline-secondary[href='#{new_staff_transaction_path}']", text: "Back"
    assert_select "a.nav-link.active[href='#{my_pump_path}']", text: /My Pump/
  end

  test "admin can view my pump page" do
    sign_in users(:one)

    get my_pump_path

    assert_response :success
    assert_select "h1", text: "My Pump"
    assert_select "a.btn.btn-outline-secondary[href='#{new_staff_transaction_path}']", text: "Back"
    assert_select "a.nav-link.active[href='#{my_pump_path}']", text: /My Pump/
  end

  test "user can update my pump selection" do
    sign_in users(:two)
    second_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
    second_nozzle = second_pump.nozzles.first

    patch my_pump_path, params: {
      user: {
        fuel_pump_id: second_pump.id,
        assigned_fuel_pump_nozzle_ids: ["", second_nozzle.id]
      }
    }

    assert_redirected_to my_pump_path
    assert_equal second_pump, users(:two).reload.assigned_fuel_pump
    assert_equal [second_nozzle.id], users(:two).assigned_fuel_pump_nozzle_ids
  end

  test "user must choose at least one nozzle when selecting a pump" do
    sign_in users(:two)

    patch my_pump_path, params: {
      user: {
        fuel_pump_id: fuel_pumps(:one).id,
        assigned_fuel_pump_nozzle_ids: [""]
      }
    }

    assert_response :unprocessable_entity
    assert_select ".alert.alert-danger", 1
    assert_match(/Select at least one nozzle for the chosen pump\./i, response.body)
    refute_match(/Assigned fuel pump nozzle ids must include at least one nozzle/i, response.body)
    refute_match(/Phone number can't be blank/i, response.body)
  end

  test "my pump validation does not surface unrelated profile errors for legacy staff records" do
    staff = users(:two)
    staff.update_columns(phone_number: nil)
    sign_in staff

    patch my_pump_path, params: {
      user: {
        fuel_pump_id: fuel_pumps(:one).id,
        assigned_fuel_pump_nozzle_ids: [""]
      }
    }

    assert_response :unprocessable_entity
    assert_select ".alert.alert-danger", 1
    assert_match(/Select at least one nozzle for the chosen pump\./i, response.body)
    refute_match(/Assigned fuel pump nozzle ids must include at least one nozzle/i, response.body)
    refute_match(/Phone number can't be blank/i, response.body)
  end
end
