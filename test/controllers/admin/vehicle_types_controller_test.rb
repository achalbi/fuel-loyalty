require "test_helper"

module Admin
  class VehicleTypesControllerTest < ActionDispatch::IntegrationTest
    test "admin can view vehicle types management" do
      sign_in users(:one)

      get admin_vehicle_types_path

      assert_response :success
      assert_select "h1", "Vehicle Types"
      assert_select "form[action='#{admin_vehicle_types_path}']", 1
      assert_select "input[name='vehicle_type[short_name]']", 1
      assert_select "input[type='radio'][name='vehicle_type[app_label_source]'][value='name']", 1
      assert_select "input[type='radio'][name='vehicle_type[app_label_source]'][value='short_name']", 1
      assert_select "input[type='radio'][name='vehicle_type[icon_name]'][value='ti-car']", 1
      assert_select "input[type='radio'][name='vehicle_type[icon_name]'][value='ti-moped']", 1
      assert_select "input[type='radio'][name='vehicle_type[icon_name]'][value='ti-truck']", 1
      assert_select "label.vehicle-type-icon-picker__option", text: /Auto Rickshaw \/ 3 Wheeler/
      assert_select "input[name='vehicle_type[code]']", 1
      assert_select "input[name='vehicle_type[code]'][placeholder='vehicle_type_code']", 1
      assert_select "a.nav-link.active[href='#{admin_vehicle_types_path}']", text: /Vehicle Types/
      assert_select "a[href='#{edit_admin_vehicle_type_path(vehicle_types(:lmv))}']", text: "Edit"
      assert_select ".reward-rate-meta", text: /Short name:\s*LMV/
      assert_select ".reward-rate-meta", text: /App label:\s*Short Name/
      assert_select ".reward-rate-meta", text: /Icon:\s*ti-car/
    end

    test "admin can add a vehicle type with a custom code" do
      sign_in users(:one)

      assert_difference -> { VehicleType.count }, 1 do
        post admin_vehicle_types_path, params: {
          vehicle_type: {
            name: "Mini Van",
            short_name: "MV",
            app_label_source: "short_name",
            code: "mini_van_custom",
            icon_name: "ti-car-suv",
            active: "1"
          }
        }
      end

      vehicle_type = VehicleType.order(:id).last

      assert_redirected_to admin_vehicle_types_path
      assert_equal "Mini Van", vehicle_type.name
      assert_equal "MV", vehicle_type.short_name
      assert_equal "short_name", vehicle_type.app_label_source
      assert_equal "ti-car-suv", vehicle_type.icon_name
      assert_equal "mini_van_custom", vehicle_type.code
      assert vehicle_type.active?
    end

    test "admin can leave code blank and let it auto-generate on create" do
      sign_in users(:one)

      assert_difference -> { VehicleType.count }, 1 do
        post admin_vehicle_types_path, params: {
          vehicle_type: {
            name: "Pickup Truck",
            short_name: "",
            app_label_source: "name",
            code: "",
            active: "1"
          }
        }
      end

      vehicle_type = VehicleType.order(:id).last

      assert_redirected_to admin_vehicle_types_path
      assert_equal "pickup_truck", vehicle_type.code
      assert_equal "Pickup Truck", vehicle_type.short_name
      assert_equal "name", vehicle_type.app_label_source
      assert_equal "ti-truck", vehicle_type.icon_name
    end

    test "admin cannot create a vehicle type with numbers in the code" do
      sign_in users(:one)

      assert_no_difference -> { VehicleType.count } do
        post admin_vehicle_types_path, params: {
          vehicle_type: {
            name: "Mini Van",
            code: "mini_van_2",
            active: "1"
          }
        }
      end

      assert_response :unprocessable_entity
      assert_match(/code only allows lowercase letters and underscores/i, response.body)
    end

    test "admin can edit a vehicle type" do
      sign_in users(:one)

      patch admin_vehicle_type_path(vehicle_types(:lmv)), params: {
        vehicle_type: {
          name: "Light Motor Vehicle",
          short_name: "LMV",
          app_label_source: "name",
          icon_name: "ti-car-suv",
          code: "light_motor_vehicle",
          active: "0"
        }
      }

      assert_redirected_to admin_vehicle_types_path
      assert_equal "Light Motor Vehicle", vehicle_types(:lmv).reload.name
      assert_equal "LMV", vehicle_types(:lmv).short_name
      assert_equal "name", vehicle_types(:lmv).app_label_source
      assert_equal "ti-car-suv", vehicle_types(:lmv).icon_name
      assert_not vehicle_types(:lmv).active?
      assert_equal "lmv", vehicle_types(:lmv).code
    end

    test "admin can remove an unused vehicle type" do
      sign_in users(:one)
      vehicle_type = VehicleType.create!(name: "Bus", active: true)

      assert_difference -> { VehicleType.count }, -1 do
        delete admin_vehicle_type_path(vehicle_type)
      end

      assert_redirected_to admin_vehicle_types_path
    end

    test "admin cannot remove a vehicle type that existing vehicles use" do
      sign_in users(:one)

      assert_no_difference -> { VehicleType.count } do
        delete admin_vehicle_type_path(vehicle_types(:two_wheeler))
      end

      assert_redirected_to admin_vehicle_types_path
      assert_match(/cannot be removed while vehicles still use it/i, flash[:alert])
    end
  end
end
