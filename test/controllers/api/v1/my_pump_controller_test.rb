require "test_helper"

module Api
  module V1
    class MyPumpControllerTest < ActionDispatch::IntegrationTest
      # Bearer auth for the native-app API layer (see Api::TokenService).
      def auth_headers(user)
        { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
      end

      test "requires authentication" do
        get api_v1_my_pump_path
        assert_response :unauthorized
      end

      # Reading is not the same capability as writing: the native transaction and
      # visit-entry screens fetch this endpoint to know which nozzles to offer, so
      # staff must keep GET access even though S-MYPUMP bars them from writing.
      test "staff can read their own assignment" do
        get api_v1_my_pump_path, headers: auth_headers(users(:two))

        assert_response :ok
        assert_equal users(:two).fuel_pump_id, response.parsed_body["fuel_pump_id"]
      end

      # S-MYPUMP — staff must not set their own pump; an admin does it (A10).
      test "staff cannot update their own pump" do
        target_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])

        patch api_v1_my_pump_path,
          params: { user: { fuel_pump_id: target_pump.id, assigned_fuel_pump_nozzle_ids: ["", target_pump.nozzles.first.id] } },
          headers: auth_headers(users(:two)),
          as: :json

        assert_response :forbidden
        assert_nil users(:two).reload.pump_assignment_for
      end

      test "admin cannot schedule a future pump override either" do
        patch api_v1_my_pump_path,
          params: { user: { assignment_date: 1.day.from_now.to_date.iso8601, fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: ["", fuel_pump_nozzles(:one).id] } },
          headers: auth_headers(users(:one)),
          as: :json

        assert_response :unprocessable_entity
        assert_equal "daily_assignment_only", response.parsed_body.dig("error", "code")
        assert_nil users(:one).reload.pump_assignment_for(on: 1.day.from_now.to_date)
      end

      test "reading with a stale date serves today rather than erroring" do
        get api_v1_my_pump_path(assignment_date: 1.day.ago.to_date.iso8601), headers: auth_headers(users(:two))

        assert_response :ok
        assert_equal Date.current.iso8601, response.parsed_body["assignment_date"]
      end

      test "admin can view own my pump assignment and the pump catalog" do
        get api_v1_my_pump_path, headers: auth_headers(users(:one))

        assert_response :ok
        body = response.parsed_body
        assert body.key?("fuel_pump_id")
        assert body["pumps"].is_a?(Array)
        assert_equal Date.current.iso8601, body["assignment_date"]
      end

      # Older app builds still transmit a device-local date. It must be IGNORED
      # rather than rejected — a clock-skewed device would otherwise be locked
      # out of the screen entirely.
      test "a supplied non-today date is ignored on read" do
        get api_v1_my_pump_path,
          params: { assignment_date: 5.days.from_now.to_date.iso8601 },
          headers: auth_headers(users(:one))

        assert_response :ok
        assert_equal Date.current.iso8601, response.parsed_body["assignment_date"]
      end

      test "a supplied non-today date is ignored on update" do
        target_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
        target_nozzle = target_pump.nozzles.first
        future_date = 5.days.from_now.to_date

        patch api_v1_my_pump_path,
          params: { user: { assignment_date: future_date.iso8601, fuel_pump_id: target_pump.id, assigned_fuel_pump_nozzle_ids: ["", target_nozzle.id] } },
          headers: auth_headers(users(:one)),
          as: :json

        assert_response :ok
        assert_equal Date.current.iso8601, response.parsed_body["assignment_date"]
        admin = users(:one).reload
        assert_equal Date.current, admin.pump_assignment_for&.assigned_on
        assert_nil admin.pump_assignment_for(on: future_date)
        assert_equal target_pump, admin.transaction_fuel_pump
      end

      test "admin update does not change the protected default pump" do
        admin = users(:one)
        admin.update!(fuel_pump_id: fuel_pumps(:one).id)
        target_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])

        patch api_v1_my_pump_path,
          params: { user: { fuel_pump_id: target_pump.id, assigned_fuel_pump_nozzle_ids: ["", target_pump.nozzles.first.id] } },
          headers: auth_headers(admin),
          as: :json

        assert_response :ok
        assert_equal fuel_pumps(:one).id, admin.reload.fuel_pump_id
        assert_equal target_pump, admin.transaction_fuel_pump
      end
    end
  end
end
