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

      # Self-service pump assignment is admin-only (S-MYPUMP); staff are forbidden
      # and must have their pump assigned by an admin (A10).
      test "staff cannot view my pump" do
        get api_v1_my_pump_path, headers: auth_headers(users(:two))
        assert_response :forbidden
      end

      test "staff cannot update my pump" do
        before_pump = users(:two).fuel_pump_id

        patch api_v1_my_pump_path,
          params: { user: { fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: ["", fuel_pump_nozzles(:one).id] } },
          headers: auth_headers(users(:two)),
          as: :json

        assert_response :forbidden
        assert_equal before_pump, users(:two).reload.fuel_pump_id
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
