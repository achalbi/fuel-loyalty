require "test_helper"

module Api
  module V1
    module Admin
      class SettlementsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @pump = fuel_pumps(:one)
          @petrol = fuel_pump_nozzles(:one)
          @admin = users(:one)
          @staff = users(:two)
          Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 100)
          @settlement = DailySettlement.create!(
            fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff, status: "submitted",
            phonepe_pos_amount: 500,
            nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }]
          )
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "index returns cross-pump totals for a single date across all pumps" do
          get api_v1_admin_settlements_path, params: { business_date: "2026-07-21" }, headers: auth_headers(@admin)
          assert_response :ok
          totals = response.parsed_body["cross_pump_totals"]
          assert_not_nil totals
          assert_equal 10000.0, totals["total_fuel_amount"]
          assert_equal 9500.0, totals["final_amount_to_settle"] # 10000 - 500 phonepe
        end

        test "show includes the audit changes array" do
          get api_v1_admin_settlement_path(@settlement), headers: auth_headers(@admin)
          assert_response :ok
          assert_equal [], response.parsed_body["changes"]
        end

        test "update without a change reason is rejected" do
          patch api_v1_admin_settlement_path(@settlement),
            params: { settlement: { notes: "fix" } }, headers: auth_headers(@admin)
          assert_response :unprocessable_entity
          assert_equal "change_reason_required", response.parsed_body.dig("error", "code")
        end

        test "update with a reason writes an audit row with field diffs" do
          assert_difference -> { SettlementChange.count }, 1 do
            patch api_v1_admin_settlement_path(@settlement), params: {
              change_reason: "Correcting PhonePe total",
              settlement: { phonepe_pos_amount: "700" },
            }, headers: auth_headers(@admin)
          end
          assert_response :ok
          body = response.parsed_body
          assert_equal false, body["points_recomputed"]
          change = @settlement.audit_changes.last
          assert_equal "Correcting PhonePe total", change.change_reason
          assert_equal ["500.0", "700.0"], change.field_diffs["phonepe_pos_amount"]
          assert_equal 9300.0, body["final_amount_to_settle"] # 10000 - 700
        end

        test "reconcile locks the settlement" do
          patch reconcile_api_v1_admin_settlement_path(@settlement), headers: auth_headers(@admin)
          assert_response :ok
          assert @settlement.reload.reconciled?
          assert @settlement.locked?
        end

        test "staff cannot reach the admin settlement endpoints" do
          get api_v1_admin_settlements_path, headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
