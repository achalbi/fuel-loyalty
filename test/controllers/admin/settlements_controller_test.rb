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
        digital_receipts_attributes: [{ label: "PhonePe POS", amount: 500 }],
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }]
      )
      @receipt = @settlement.digital_receipts.first
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

    test "update with a reason redirects and writes an audit row naming the staff member it was entered for" do
      sign_in @admin
      assert_difference -> { SettlementChange.count }, 1 do
        patch admin_settlement_path(@settlement), params: {
          change_reason: "Corrected PhonePe", on_behalf_of_id: @staff.id,
          settlement: { digital_receipts_attributes: { "0" => { id: @receipt.id, label: "PhonePe POS", amount: "800" } } },
        }
      end
      assert_redirected_to admin_settlement_path(@settlement)
      assert_equal BigDecimal("800"), @receipt.reload.amount
      change = SettlementChange.order(:id).last
      assert_equal @admin, change.changed_by
      assert_equal @staff, change.on_behalf_of
    end

    test "update without a reason is rejected" do
      sign_in @admin
      assert_no_difference -> { SettlementChange.count } do
        patch admin_settlement_path(@settlement), params: {
          change_reason: "", on_behalf_of_id: @staff.id, settlement: { notes: "x" },
        }
      end
      assert_response :unprocessable_entity
    end

    test "update without an on-behalf-of staff member is rejected" do
      sign_in @admin
      assert_no_difference -> { SettlementChange.count } do
        patch admin_settlement_path(@settlement), params: {
          change_reason: "Corrected PhonePe", settlement: { notes: "x" },
        }
      end
      assert_response :unprocessable_entity
      assert_select ".alert.alert-danger", text: /on behalf of/
      assert_nil @settlement.reload.notes
    end

    test "an admin cannot record an edit as being on behalf of himself" do
      sign_in @admin

      assert_no_difference -> { SettlementChange.count } do
        patch admin_settlement_path(@settlement), params: {
          change_reason: "Corrected PhonePe", on_behalf_of_id: @admin.id,
          settlement: { notes: "x" },
        }
      end

      assert_response :unprocessable_entity
      assert_select ".alert.alert-danger", text: /on behalf of/
    end

    test "the per-staff rollup counts only the settlements whose money it sums" do
      @settlement.update_column(:status, DailySettlement.statuses[:draft])
      sign_in @admin

      get admin_settlements_path, params: { business_date: "2026-07-21" }

      assert_response :success
      # One draft: nothing to sum, so the count is 0 with the draft called out.
      assert_select "h2", text: /Per staff member/
      assert_match(/\+1 draft/, response.body)
    end

    test "the edit form asks who the settlement is being entered for" do
      sign_in @admin
      get edit_admin_settlement_path(@settlement)

      assert_response :success
      assert_select "label[for='on_behalf_of_id']", text: "Entering on behalf of"
      assert_select "select[name='on_behalf_of_id'] option[selected][value='#{@staff.id}']"
    end

    test "index reports settlement totals per staff member and filters by staff" do
      other_staff = User.create!(
        name: "Second FSM", username: "fsm2", phone_number: "9000000033",
        password: "password123", password_confirmation: "password123", role: :staff
      )
      other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
      other = DailySettlement.create!(
        fuel_pump: other_pump, business_date: Date.new(2026, 7, 21), recorded_by: other_staff,
        status: "submitted", digital_receipts_attributes: [{ label: "PhonePe POS", amount: 100 }],
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: other_pump.nozzles.first.id, opening_reading: 10, closing_reading: 20, unit_price: 100 }]
      )
      sign_in @admin

      get admin_settlements_path, params: { business_date: "2026-07-21" }

      assert_response :success
      assert_select "h2", text: /Per staff member/
      # Both FSMs get a rollup row that drills through to their own settlements.
      assert_select "a[href=?]", admin_settlements_path(business_date: "2026-07-21", user_id: other_staff.id), text: other_staff.display_name
      assert_select "a[href=?]", admin_settlements_path(business_date: "2026-07-21", user_id: @staff.id), text: @staff.display_name

      get admin_settlements_path, params: { business_date: "2026-07-21", user_id: other_staff.id }

      assert_response :success
      assert_select "td", text: other.fuel_pump.display_name
      assert_select "td", text: @settlement.fuel_pump.display_name, count: 0
    end

    test "reconciling a pre-existing settlement does not claim the admin keyed it in" do
      # A row created before entered_by existed; reconcile is the normal end state
      # of every settlement, so a back-stamp here would mis-attribute all history.
      @settlement.update_column(:entered_by_id, nil)
      sign_in @admin

      patch reconcile_admin_settlement_path(@settlement)

      @settlement.reload
      assert @settlement.reconciled?
      assert_nil @settlement.entered_by_id
      assert_not @settlement.entered_on_behalf?

      get admin_settlement_path(@settlement)
      assert_select "span", text: /entered by/, count: 0
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
