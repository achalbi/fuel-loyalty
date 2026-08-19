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
          assert_equal "default", body["assignment_mode"]
          assert_equal users(:two).fuel_pump_id, body["fuel_pump_id"]
          assert body["pumps"].is_a?(Array)
        end

        test "admin can assign a staff member's pump and nozzle" do
          default_pump_id = users(:two).fuel_pump_id
          second_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
          second_nozzle = second_pump.nozzles.first
          target_date = Date.current + 1.day

          patch pump_api_v1_admin_staff_member_path(users(:two)),
            params: { user: { assignment_mode: "override", assignment_date: target_date.iso8601, fuel_pump_id: second_pump.id, assigned_fuel_pump_nozzle_ids: ["", second_nozzle.id] } },
            headers: auth_headers(users(:one)),
            as: :json

          assert_response :ok
          body = response.parsed_body
          assert_equal "override", body["assignment_mode"]
          assert_equal second_pump.id, body["fuel_pump_id"]
          assert_equal [second_nozzle.id], body["assigned_fuel_pump_nozzle_ids"]
          assert_equal "Daily pump override updated for #{users(:two).name}.", body["message"]
          user = users(:two).reload
          assert_equal default_pump_id, user.fuel_pump_id
          assert_equal second_pump, user.transaction_fuel_pump(on: target_date)
        end

        test "admin cannot back-date a staff member's daily pump override" do
          second_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
          second_nozzle = second_pump.nozzles.first
          past_date = Date.current - 1.day

          patch pump_api_v1_admin_staff_member_path(users(:two)),
            params: { user: { assignment_mode: "override", assignment_date: past_date.iso8601, fuel_pump_id: second_pump.id, assigned_fuel_pump_nozzle_ids: ["", second_nozzle.id] } },
            headers: auth_headers(users(:one)),
            as: :json

          assert_response :unprocessable_entity
          assert_equal "past_assignment_date", response.parsed_body.dig("error", "code")
          assert_nil users(:two).reload.pump_assignment_for(on: past_date)
        end

        test "admin can update a staff member's protected default pump and nozzles" do
          second_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
          second_nozzle = second_pump.nozzles.first

          patch pump_api_v1_admin_staff_member_path(users(:two)),
            params: { user: { assignment_mode: "default", fuel_pump_id: second_pump.id, assigned_fuel_pump_nozzle_ids: ["", second_nozzle.id] } },
            headers: auth_headers(users(:one)),
            as: :json

          assert_response :ok
          body = response.parsed_body
          assert_equal "default", body["assignment_mode"]
          assert_nil body["assignment_date"]
          assert_equal second_pump.id, body["fuel_pump_id"]
          assert_equal [second_nozzle.id], body["assigned_fuel_pump_nozzle_ids"]
          assert_equal "Default pump updated for #{users(:two).name}.", body["message"]
          user = users(:two).reload
          assert_equal second_pump.id, user.fuel_pump_id
          assert_equal [second_nozzle.id], user.assigned_fuel_pump_nozzle_ids
        end

        test "assigning without a nozzle returns a validation error envelope" do
          patch pump_api_v1_admin_staff_member_path(users(:two)),
            params: { user: { assignment_mode: "override", fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: [""] } },
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
