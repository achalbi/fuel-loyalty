require "test_helper"

module Admin
  class FuelPumpsControllerTest < ActionDispatch::IntegrationTest
    test "admin can view pump management with nozzle controls" do
      sign_in users(:one)

      get admin_fuel_pumps_path

      assert_response :success
      assert_select "form[action='#{feature_settings_admin_fuel_pumps_path}']", 1
      assert_select "input[name='reward_setting[nozzle_feature_enabled]'][type='checkbox']", 1
      assert_select "h1", "Fuel Dispensing Units / Pumps"
      assert_select "form[action='#{admin_fuel_pumps_path}'][data-fuel-pump-form='true']", 1
      assert_select "[data-fuel-pump-nozzle-add]", text: /Add Nozzle/
      assert_select "template[data-fuel-pump-nozzle-template]", 1
      assert_select "[data-fuel-pump-nozzle-list] [data-fuel-pump-nozzle-row]", 1
      assert_includes response.body, "NEW_RECORD"
      assert_includes response.body, "data-fuel-pump-nozzle-row"
      assert_select "a.nav-link.active[href='#{admin_fuel_pumps_path}']", text: /Pumps/
    end

    test "admin can add a pump with multiple nozzles" do
      sign_in users(:one)

      assert_difference -> { FuelPump.count }, 1 do
        assert_difference -> { FuelPumpNozzle.count }, 2 do
          post admin_fuel_pumps_path, params: {
            fuel_pump: {
              active: "1",
              nozzles_attributes: {
                "0" => { fuel_type_code: "petrol", active: "1" },
                "1" => { fuel_type_code: "diesel", active: "0" }
              }
            }
          }
        end
      end

      fuel_pump = FuelPump.order(:id).last

      assert_redirected_to admin_fuel_pumps_path
      assert_equal 2, fuel_pump.sequence_number
      assert fuel_pump.active?
      assert_equal(
        [
          [ "petrol", 1, true ],
          [ "diesel", 2, false ]
        ],
        fuel_pump.nozzles.order(:sequence_number).pluck(:fuel_type_code, :sequence_number, :active)
      )
    end

    test "admin can update pump nozzles" do
      sign_in users(:one)
      fuel_pump = fuel_pumps(:one)
      retained_nozzle = fuel_pump_nozzles(:one)
      removed_nozzle = fuel_pump_nozzles(:two)

      assert_no_difference -> { FuelPump.count } do
        assert_no_difference -> { FuelPumpNozzle.count } do
          patch admin_fuel_pump_path(fuel_pump), params: {
            fuel_pump: {
              active: "0",
              nozzles_attributes: {
                "0" => { id: retained_nozzle.id, fuel_type_code: "petrol", active: "0" },
                "1" => { id: removed_nozzle.id, fuel_type_code: "diesel", active: "1", _destroy: "1" },
                "2" => { fuel_type_code: "petrol", active: "1" }
              }
            }
          }
        end
      end

      assert_redirected_to admin_fuel_pumps_path
      assert_not fuel_pump.reload.active?
      assert_not FuelPumpNozzle.exists?(removed_nozzle.id)
      assert_equal(
        [
          [ 1, "petrol", false ],
          [ 2, "petrol", true ]
        ],
        fuel_pump.nozzles.order(:sequence_number).pluck(:sequence_number, :fuel_type_code, :active)
      )
    end

    test "web pump edit reports a delete restriction when a nozzle has transactions" do
      sign_in users(:one)
      fuel_pump = fuel_pumps(:one)
      retained_nozzle = fuel_pump_nozzles(:one)
      removed_nozzle = fuel_pump_nozzles(:two)
      Transaction.create!(
        customer: customers(:one),
        user: users(:one),
        vehicle: vehicles(:one),
        fuel_pump: fuel_pump,
        fuel_pump_nozzle: removed_nozzle,
        fuel_amount: 500,
      )

      patch admin_fuel_pump_path(fuel_pump), params: {
        fuel_pump: {
          active: true,
          nozzles_attributes: {
            "0" => { id: retained_nozzle.id, fuel_type_code: retained_nozzle.fuel_type_code, active: "1" },
            "1" => { id: removed_nozzle.id, _destroy: "1" }
          }
        }
      }

      assert_response :unprocessable_entity
      assert_match(/cannot be removed while transactions still use it/i, response.body)
      assert FuelPumpNozzle.exists?(removed_nozzle.id)
    end

    test "admin can disable nozzle selection for transactions" do
      sign_in users(:one)

      patch feature_settings_admin_fuel_pumps_path, params: {
        reward_setting: {
          nozzle_feature_enabled: "0"
        }
      }

      assert_redirected_to admin_fuel_pumps_path
      assert_equal false, RewardSetting.current.nozzle_feature_enabled?
    end
  end
end
