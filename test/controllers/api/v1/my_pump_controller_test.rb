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

      test "show returns the assignment plus the pump catalog and ready flag" do
        get api_v1_my_pump_path, headers: auth_headers(users(:two))

        assert_response :ok
        body = response.parsed_body
        assert_equal users(:two).fuel_pump_id, body["fuel_pump_id"]
        assert_equal users(:two).assigned_fuel_pump_nozzle_ids.sort, body["assigned_fuel_pump_nozzle_ids"].sort
        assert_equal true, body["ready"]
        assert body["pumps"].is_a?(Array)
        assert body["pumps"].any? { |p| p["id"] == fuel_pumps(:one).id }
      end

      test "update assigns a new pump and nozzle and reports ready" do
        second_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
        second_nozzle = second_pump.nozzles.first

        patch api_v1_my_pump_path,
          params: { user: { fuel_pump_id: second_pump.id, assigned_fuel_pump_nozzle_ids: ["", second_nozzle.id] } },
          headers: auth_headers(users(:two)),
          as: :json

        assert_response :ok
        body = response.parsed_body
        assert_equal second_pump.id, body["fuel_pump_id"]
        assert_equal [second_nozzle.id], body["assigned_fuel_pump_nozzle_ids"]
        assert_equal true, body["ready"]
        assert_equal "My pump updated successfully.", body["message"]

        assert_equal second_pump, users(:two).reload.assigned_fuel_pump
        assert_equal [second_nozzle.id], users(:two).assigned_fuel_pump_nozzle_ids
      end

      test "update returns a validation error envelope when no nozzle is chosen" do
        patch api_v1_my_pump_path,
          params: { user: { fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: [""] } },
          headers: auth_headers(users(:two)),
          as: :json

        assert_response :unprocessable_entity
        error = response.parsed_body["error"]
        assert_equal "validation_failed", error["code"]
        assert error["message"].present?
        assert error.dig("details", "assigned_fuel_pump_nozzle_ids").present?
      end

      test "a rejected update does not corrupt the existing assignment" do
        before_pump = users(:two).fuel_pump_id
        before_nozzles = users(:two).assigned_fuel_pump_nozzle_ids.sort
        assert before_pump.present?
        assert before_nozzles.any?, "fixture must start with an existing assignment"

        patch api_v1_my_pump_path,
          params: { user: { fuel_pump_id: fuel_pumps(:one).id, assigned_fuel_pump_nozzle_ids: [""] } },
          headers: auth_headers(users(:two)),
          as: :json

        assert_response :unprocessable_entity
        users(:two).reload
        assert_equal before_pump, users(:two).fuel_pump_id
        assert_equal before_nozzles, users(:two).assigned_fuel_pump_nozzle_ids.sort
      end
    end
  end
end
