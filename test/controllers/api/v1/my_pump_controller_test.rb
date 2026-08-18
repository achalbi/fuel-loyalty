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

      test "staff can view my pump" do
        get api_v1_my_pump_path, headers: auth_headers(users(:two))
        assert_response :ok
      end

      test "staff can update today's pump without changing the default" do
        default_pump_id = users(:two).fuel_pump_id
        target_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
        target_nozzle = target_pump.nozzles.first
        patch api_v1_my_pump_path,
          params: { user: { assignment_date: Date.current.iso8601, fuel_pump_id: target_pump.id, assigned_fuel_pump_nozzle_ids: ["", target_nozzle.id] } },
          headers: auth_headers(users(:two)),
          as: :json

        assert_response :ok
        user = users(:two).reload
        assert_equal default_pump_id, user.fuel_pump_id
        assert_equal target_pump, user.transaction_fuel_pump
        assert_equal Date.current, user.pump_assignment_for&.assigned_on
      end

      test "staff cannot schedule a future pump override" do
        patch api_v1_my_pump_path,
          params: { user: { assignment_date: 1.day.from_now.to_date.iso8601, fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: ["", fuel_pump_nozzles(:one).id] } },
          headers: auth_headers(users(:two)),
          as: :json

        assert_response :unprocessable_entity
        assert_equal "daily_assignment_only", response.parsed_body.dig("error", "code")
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
      end
    end
  end
end
