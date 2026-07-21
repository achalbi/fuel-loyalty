require "test_helper"

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

    test "index shows cross-pump totals for a single date" do
      sign_in @admin
      get admin_settlements_path, params: { business_date: "2026-07-21" }
      assert_response :success
      assert_select "div.card", text: /Cross-pump totals/
    end

    test "show renders the settlement and audit panel" do
      sign_in @admin
      get admin_settlement_path(@settlement)
      assert_response :success
      assert_select "h2", text: "Audit trail"
    end

    test "update with a reason redirects and writes an audit row" do
      sign_in @admin
      assert_difference -> { SettlementChange.count }, 1 do
        patch admin_settlement_path(@settlement), params: {
          change_reason: "Corrected PhonePe", settlement: { phonepe_pos_amount: "800" },
        }
      end
      assert_redirected_to admin_settlement_path(@settlement)
      assert_equal BigDecimal("800"), @settlement.reload.phonepe_pos_amount
    end

    test "update without a reason is rejected" do
      sign_in @admin
      assert_no_difference -> { SettlementChange.count } do
        patch admin_settlement_path(@settlement), params: { change_reason: "", settlement: { notes: "x" } }
      end
      assert_response :unprocessable_entity
    end

    test "reconcile locks the settlement" do
      sign_in @admin
      patch reconcile_admin_settlement_path(@settlement)
      assert_redirected_to admin_settlement_path(@settlement)
      assert @settlement.reload.reconciled?
      assert @settlement.locked?
    end

    test "staff cannot reach the admin console" do
      sign_in @staff
      get admin_settlements_path
      assert_response :redirect # ensure_admin! bounces non-admins
    end
  end
end
