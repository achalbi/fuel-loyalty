require "test_helper"

module Api
  module V1
    module Admin
      class FuelPumpsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @pump = fuel_pumps(:one)
          @retained_nozzle = fuel_pump_nozzles(:one)
          @removed_nozzle = fuel_pump_nozzles(:two)
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "admin can update a pump while deleting a nested nozzle" do
          patch api_v1_admin_fuel_pump_path(@pump), params: {
            fuel_pump: {
              active: true,
              nozzles_attributes: [
                { id: @retained_nozzle.id, fuel_type_code: @retained_nozzle.fuel_type_code, active: true },
                { id: @removed_nozzle.id, _destroy: true }
              ]
            }
          }, headers: auth_headers(@admin), as: :json

          assert_response :ok
          assert_equal(
            [ @retained_nozzle.id ],
            @pump.reload.nozzles.pluck(:id),
          )
          assert_equal @retained_nozzle.id, response.parsed_body["nozzles"].first["id"]
        end

        test "nested nozzle deletion returns a conflict when transactions use the nozzle" do
          Transaction.create!(
            customer: customers(:one),
            user: @admin,
            vehicle: vehicles(:one),
            fuel_pump: @pump,
            fuel_pump_nozzle: @removed_nozzle,
            fuel_amount: 500,
          )

          patch api_v1_admin_fuel_pump_path(@pump), params: {
            fuel_pump: {
              active: true,
              nozzles_attributes: [
                { id: @retained_nozzle.id, fuel_type_code: @retained_nozzle.fuel_type_code, active: true },
                { id: @removed_nozzle.id, _destroy: true }
              ]
            }
          }, headers: auth_headers(@admin), as: :json

          assert_response :conflict
          assert_equal "delete_restricted", response.parsed_body.dig("error", "code")
        end
      end
    end
  end
end
