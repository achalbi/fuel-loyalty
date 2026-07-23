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

      test "staff can update my pump for a selected day" do
        target_date = 1.day.from_now.to_date
        patch api_v1_my_pump_path,
          params: { user: { assignment_date: target_date.iso8601, fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: ["", fuel_pump_nozzles(:one).id] } },
          headers: auth_headers(users(:two)),
          as: :json

        assert_response :ok
        assert_equal target_date, users(:two).reload.pump_assignment_for(on: target_date)&.assigned_on
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
