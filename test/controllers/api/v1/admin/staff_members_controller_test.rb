require "test_helper"

module Api
  module V1
    module Admin
      class StaffMembersControllerTest < ActionDispatch::IntegrationTest
        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "admin can read a staff member's pump assignment and pump catalog" do
          get pump_api_v1_admin_staff_member_path(users(:two)), headers: auth_headers(users(:one))

          assert_response :ok
          body = response.parsed_body
          assert_equal users(:two).fuel_pump_id, body["fuel_pump_id"]
          assert body["pumps"].is_a?(Array)
        end

        test "admin can assign a staff member's pump and nozzle" do
          second_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
          second_nozzle = second_pump.nozzles.first

          patch pump_api_v1_admin_staff_member_path(users(:two)),
            params: { user: { fuel_pump_id: second_pump.id, assigned_fuel_pump_nozzle_ids: ["", second_nozzle.id] } },
            headers: auth_headers(users(:one)),
            as: :json

          assert_response :ok
          body = response.parsed_body
          assert_equal second_pump.id, body["fuel_pump_id"]
          assert_equal [second_nozzle.id], body["assigned_fuel_pump_nozzle_ids"]
          assert_equal "Pump assignment updated for #{users(:two).name}.", body["message"]
          assert_equal second_pump, users(:two).reload.assigned_fuel_pump
        end

        test "assigning without a nozzle returns a validation error envelope" do
          patch pump_api_v1_admin_staff_member_path(users(:two)),
            params: { user: { fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: [""] } },
            headers: auth_headers(users(:one)),
            as: :json

          assert_response :unprocessable_entity
          assert_equal "validation_failed", response.parsed_body["error"]["code"]
        end

        test "staff cannot assign pumps via the admin API" do
          get pump_api_v1_admin_staff_member_path(users(:two)), headers: auth_headers(users(:two))
          assert_response :forbidden
        end
      end
    end
  end
end
