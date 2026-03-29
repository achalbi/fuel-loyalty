require "test_helper"

module Admin
  class FuelTypesControllerTest < ActionDispatch::IntegrationTest
    test "admin can view fuel types management" do
      sign_in users(:one)

      get admin_fuel_types_path

      assert_response :success
      assert_select "h1", "Fuel Types"
      assert_select "form[action='#{admin_fuel_types_path}']", 1
      assert_select "a.nav-link.active[href='#{admin_fuel_types_path}']", text: /Fuel Types/
      assert_select "a[href='#{edit_admin_fuel_type_path(fuel_types(:petrol))}']", text: "Edit"
    end

    test "admin can add a fuel type" do
      sign_in users(:one)

      assert_difference -> { FuelType.count }, 1 do
        post admin_fuel_types_path, params: {
          fuel_type: {
            name: "Premium Diesel",
            active: "1"
          }
        }
      end

      fuel_type = FuelType.order(:id).last

      assert_redirected_to admin_fuel_types_path
      assert_equal "Premium Diesel", fuel_type.name
      assert_equal "premium_diesel", fuel_type.code
      assert fuel_type.active?
    end

    test "admin can edit a fuel type" do
      sign_in users(:one)

      patch admin_fuel_type_path(fuel_types(:diesel)), params: {
        fuel_type: {
          name: "Diesel XP",
          active: "0"
        }
      }

      assert_redirected_to admin_fuel_types_path
      assert_equal "Diesel XP", fuel_types(:diesel).reload.name
      assert_not fuel_types(:diesel).active?
      assert_equal "diesel", fuel_types(:diesel).code
    end

    test "admin can remove an unused fuel type" do
      sign_in users(:one)
      fuel_type = FuelType.create!(name: "Bio Diesel", active: true)
      FuelRewardRate.create!(fuel_type: fuel_type.code, points_per_100: 3)

      assert_difference -> { FuelType.count }, -1 do
        assert_difference -> { FuelRewardRate.count }, -1 do
          delete admin_fuel_type_path(fuel_type)
        end
      end

      assert_redirected_to admin_fuel_types_path
    end

    test "admin cannot remove a fuel type that existing vehicles use" do
      sign_in users(:one)

      assert_no_difference -> { FuelType.count } do
        delete admin_fuel_type_path(fuel_types(:petrol))
      end

      assert_redirected_to admin_fuel_types_path
      assert_match(/cannot be removed while vehicles still use it/i, flash[:alert])
    end
  end
end
