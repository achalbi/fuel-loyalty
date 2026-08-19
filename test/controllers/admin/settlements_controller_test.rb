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

    # A sheet on a NEW pump, because the pump/date/shift index is unique and a
    # day therefore holds one sheet per pump. `litres` × ₹100 is the fuel money.
    def settlement_on_new_pump(recorded_by:, business_date:, status:, litres:)
      pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
      DailySettlement.create!(
        fuel_pump: pump, business_date: business_date, recorded_by: recorded_by, status: status,
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: pump.nozzles.first.id, opening_reading: 0, closing_reading: litres, unit_price: 100 }]
      )
    end

    # Recorded by the ADMIN on purpose: admin-recorded sheets exist in the data
    # and must stay filterable. ₹1,000 of fuel.
    def admin_recorded_settlement
      settlement_on_new_pump(recorded_by: @admin, business_date: Date.new(2026, 7, 21), status: "submitted", litres: 10)
    end

    test "index shows cross-pump totals for a single date" do
      sign_in @admin
      get admin_settlements_path, params: { business_date: "2026-07-21" }
      assert_response :success
      assert_select "div.card", text: /Cross-pump totals/
    end

    test "index filters by the FSM who recorded the sheet" do
      other = admin_recorded_settlement
      sign_in @admin

      get admin_settlements_path, params: { business_date: "2026-07-21", recorded_by_id: @staff.id }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(@settlement)
      assert_select "a[href=?]", admin_settlement_path(other), count: 0

      # ...and the admin's own sheet is reachable through the same filter.
      get admin_settlements_path, params: { business_date: "2026-07-21", recorded_by_id: @admin.id }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(other)
      assert_select "a[href=?]", admin_settlement_path(@settlement), count: 0
    end

    # The option list is built from the settlements themselves, not from
    # `role: :staff`, so a sheet an admin recorded stays reachable.
    test "the FSM filter offers admins who have recorded a settlement" do
      admin_recorded_settlement
      sign_in @admin
      get admin_settlements_path
      assert_response :success
      assert_select "select[name=recorded_by_id] option[value=?]", @admin.id.to_s
      assert_select "select[name=recorded_by_id] option[value=?]", @staff.id.to_s
    end

    test "index shows per-FSM totals for the listed day" do
      admin_recorded_settlement
      sign_in @admin
      get admin_settlements_path, params: { business_date: "2026-07-21" }
      assert_response :success
      assert_select "h2", text: /Per-FSM totals/
      assert_select "tr[data-per-fsm-row]", 2
      # 100 L × ₹100 for the FSM's sheet; 10 L × ₹100 for the admin's.
      assert_select "tr[data-per-fsm-row=?]", @staff.id.to_s do
        assert_select "td", text: "₹10,000.00"
      end
      assert_select "tr[data-per-fsm-row=?]", @admin.id.to_s do
        assert_select "td", text: "₹1,000.00"
      end
    end

    test "a draft is left out of the per-FSM totals" do
      # One FSM, one day, two sheets: a ₹50,000 draft and a ₹1,000 submitted
      # one. The row must exist and carry the submitted sheet's money ONLY —
      # counting the draft would read 2 sheets and ₹51,000.
      draft = DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 22), recorded_by: @staff, status: "draft",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 0, closing_reading: 500, unit_price: 100 }]
      )
      submitted = settlement_on_new_pump(recorded_by: @staff, business_date: Date.new(2026, 7, 22), status: "submitted", litres: 10)
      sign_in @admin
      get admin_settlements_path, params: { business_date: "2026-07-22" }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(draft)     # the draft is listed...
      assert_select "a[href=?]", admin_settlement_path(submitted)
      assert_select "tr[data-per-fsm-row]", 1                     # ...but it is not money yet
      assert_select "tr[data-per-fsm-row=?]", @staff.id.to_s do
        assert_select "td", text: "1"                             # one sheet counted, not two
        assert_select "td", text: "₹1,000.00"                     # the submitted sheet
        assert_select "td", text: "₹50,000.00", count: 0          # the draft's litres never land
        assert_select "td", text: "₹51,000.00", count: 0
      end
    end

    # The web used to look the filter ids up first and skip the scope when the
    # lookup missed, so a stale id listed EVERYBODY while the select still read
    # "All" — the same id returns an empty list on the API.
    test "an unrecognised recorded_by_id narrows to nothing rather than dropping the filter" do
      admin_recorded_settlement
      sign_in @admin
      get admin_settlements_path, params: { business_date: "2026-07-21", recorded_by_id: User.maximum(:id) + 1 }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(@settlement), count: 0
      assert_select "tr[data-per-fsm-row]", 0
      assert_select "p", text: "No settlements match."
      # ...and the cross-pump card still admits it is showing one FSM's money.
      assert_select "div.card", text: /Cross-pump totals.*one FSM only/m
    end

    test "an unrecognised fuel_pump_id narrows to nothing and suppresses the cross-pump card" do
      sign_in @admin
      get admin_settlements_path, params: { business_date: "2026-07-21", fuel_pump_id: FuelPump.maximum(:id) + 1 }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(@settlement), count: 0
      assert_select "div.card", text: /Cross-pump totals/, count: 0
    end

    test "the cross-pump card says whose money it is when the day is filtered to one FSM" do
      admin_recorded_settlement
      sign_in @admin
      get admin_settlements_path, params: { business_date: "2026-07-21", recorded_by_id: @staff.id }
      assert_response :success
      assert_select "div.card", text: /Cross-pump totals.*#{Regexp.escape(@staff.display_name)} only/m
      # Unfiltered, the same card carries no qualifier.
      get admin_settlements_path, params: { business_date: "2026-07-21" }
      assert_select "div.card", text: /Cross-pump totals(?!.*only)/m
    end

    test "show frames the settlement as the FSM's, corrected on their behalf" do
      Settlement::Persister.call(
        settlement: @settlement, attributes: { notes: "tweak" }, actor: @admin,
        admin_edit: true, change_reason: "Typo in notes"
      )
      sign_in @admin
      get admin_settlement_path(@settlement)
      assert_response :success
      assert_select "h2", text: "Audit trail"
      assert_match(/Recorded by/, response.body)
      assert_match(/last corrected by/, response.body)
      # The edit control names the FSM so the on-behalf nature is explicit.
      assert_select "a[href=?]", edit_admin_settlement_path(@settlement),
        text: "Correct on behalf of #{@staff.display_name}"
    end

    test "update with a reason redirects and writes an audit row" do
      sign_in @admin
      assert_difference -> { SettlementChange.count }, 1 do
        patch admin_settlement_path(@settlement), params: {
          change_reason: "Corrected PhonePe",
          settlement: { digital_receipts_attributes: { "0" => { id: @receipt.id, label: "PhonePe POS", amount: "800" } } },
        }
      end
      assert_redirected_to admin_settlement_path(@settlement)
      assert_equal BigDecimal("800"), @receipt.reload.amount
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

    # ---- record on behalf of a named FSM (staff feedback item 3) ------------

    # The body of an on-behalf create: the pump/date define the slot, and the
    # FSM + reason ride at the TOP level, outside the settlement object, exactly
    # as the shared form posts them.
    def on_behalf_params(recorded_by: @staff, business_date: "2026-07-23", reason: "Staff was on sick leave; readings dictated at the counter", status: "submitted", **overrides)
      body = {
        change_reason: reason,
        settlement: {
          fuel_pump_id: @pump.id,
          business_date: business_date,
          status: status,
          nozzle_readings_attributes: {
            "0" => {
              fuel_pump_nozzle_id: @petrol.id, opening_reading: "1100", closing_reading: "1200",
              testing_litres: "0", rollover: "0", opening_source: "manual"
            }
          }
        }
      }
      # Omitted entirely rather than sent as nil, so "no FSM named" is the same
      # shape a browser would post when the hidden field is missing.
      body[:recorded_by_id] = recorded_by.id if recorded_by
      body.deep_merge(overrides)
    end

    # The picker is forward-looking (User.settlement_recorder_candidates) — every
    # active operator, including admins, not just those with sheets on the books.
    test "the on-behalf form offers the operators a sheet may be recorded for, admins included" do
      sign_in @admin
      get new_admin_settlement_path
      assert_response :success
      assert_select "select[name=recorded_by_id] option[value=?]", @staff.id.to_s
      assert_select "select[name=recorded_by_id] option[value=?]", @admin.id.to_s
      # Nothing is hydrated before an FSM is named — the sheet is built from
      # THEIR pump, so there is nothing to fill in yet.
      assert_select "input[name$='[closing_reading]']", count: 0
      assert_select "input[name=change_reason]", count: 0
    end

    test "naming the FSM hydrates the sheet against their pump and says whose it is" do
      # The users fixtures assign no pump, so post the FSM to one explicitly —
      # otherwise the sheet hydrates empty and the assertions below pass
      # vacuously against a blank hidden field.
      @staff.update!(assigned_fuel_pump: @pump, assigned_fuel_pump_nozzles: [@petrol])
      sign_in @admin
      get new_admin_settlement_path, params: { recorded_by_id: @staff.id, business_date: "2026-07-23" }
      assert_response :success
      # The FSM's pump, not the admin's — the admin has no pump at all, so a
      # leak would render an empty sheet. Asserted through the banner and the
      # nozzle rows rather than the form's `fuel_pump_id` hidden field: that
      # field is emitted by `form.hidden_field` and so carries the model's own
      # param key (`daily_settlement[...]`), which no controller reads — the
      # pump is resolved server-side from the FSM.
      assert_select "[data-on-behalf-banner]", text: /#{Regexp.escape(@pump.display_name)}/
      assert_select "form[action=?]", admin_settlements_path do
        assert_select "input[type=hidden][name=recorded_by_id][value=?]", @staff.id.to_s
        assert_select "input[name=change_reason][required]"
      end
      # Their nozzles are on the form...
      assert_select "input[name$='[fuel_pump_nozzle_id]'][value=?]", @petrol.id.to_s
      # ...and the page says the sheet is theirs and the admin only typed it.
      assert_select "[data-fsm-name]", text: /#{Regexp.escape(@staff.display_name)}/
      assert_select "[data-entered-by]", text: /entered by #{Regexp.escape(@admin.display_name)}/
    end

    # The (pump, date, shift) slot is unique, so an occupied one has to send the
    # admin to the audited correct-it flow rather than a doomed create.
    test "an already-settled slot sends the admin to the existing sheet" do
      sign_in @admin
      get new_admin_settlement_path, params: { recorded_by_id: @staff.id, business_date: "2026-07-21" }
      assert_redirected_to edit_admin_settlement_path(@settlement)
    end

    test "recording on behalf keeps the sheet the FSM's and records the admin as the enterer" do
      sign_in @admin
      assert_difference -> { DailySettlement.count }, 1 do
        post admin_settlements_path, params: on_behalf_params
      end
      settlement = DailySettlement.order(:id).last
      assert_redirected_to admin_settlement_path(settlement)
      assert_equal @staff.id, settlement.recorded_by_id
      assert_equal @staff.display_name, settlement.fsm_name_snapshot
      assert_equal @admin.id, settlement.entered_by_id
      assert settlement.entered_on_behalf?
      # The FSM cannot act, so the admin submits it rather than parking a draft
      # nobody is coming back to.
      assert settlement.submitted?
      assert_equal BigDecimal("10000"), settlement.total_fuel_amount # 100 L × ₹100
    end

    test "an on-behalf create is audited with the reason given" do
      sign_in @admin
      assert_difference -> { SettlementChange.count }, 1 do
        post admin_settlements_path, params: on_behalf_params(reason: "Device dead; dictated at the counter")
      end
      change = SettlementChange.order(:id).last
      assert_equal @admin.id, change.changed_by_id
      assert_equal "Device dead; dictated at the counter", change.change_reason
      # The diff records who it was recorded for and who typed it.
      assert_equal @staff.id.to_s, change.field_diffs["recorded_by_id"].last.to_s
      assert_equal @admin.id.to_s, change.field_diffs["entered_by_id"].last.to_s
    end

    test "an on-behalf create may be parked as a draft" do
      sign_in @admin
      post admin_settlements_path, params: on_behalf_params(status: "draft")
      settlement = DailySettlement.order(:id).last
      assert settlement.draft?
      assert_equal @staff.id, settlement.recorded_by_id
      assert_equal @admin.id, settlement.entered_by_id
    end

    test "an on-behalf create without a reason saves nothing" do
      sign_in @admin
      assert_no_difference [ "DailySettlement.count", "SettlementChange.count" ] do
        post admin_settlements_path, params: on_behalf_params(reason: "")
      end
      assert_response :unprocessable_entity
      assert_select "div.alert-danger", text: /reason/i
      # The form comes back with the FSM still named, so nothing has to be retyped.
      assert_select "input[type=hidden][name=recorded_by_id][value=?]", @staff.id.to_s
    end

    test "an on-behalf create without naming an FSM saves nothing" do
      sign_in @admin
      assert_no_difference -> { DailySettlement.count } do
        post admin_settlements_path, params: on_behalf_params(recorded_by: nil)
      end
      assert_response :unprocessable_entity
      assert_select "div.alert-danger", text: /FSM/
    end

    # Resolved through the picker's own scope, so a deactivated operator cannot
    # be smuggled in by id even though their historical sheets stay filterable.
    test "an operator who is not on the picker list is refused" do
      @staff.update!(active: false)
      sign_in @admin
      assert_no_difference -> { DailySettlement.count } do
        post admin_settlements_path, params: on_behalf_params
      end
      assert_response :unprocessable_entity

      get new_admin_settlement_path, params: { recorded_by_id: @staff.id }
      assert_response :success
      assert_select "input[name=change_reason]", count: 0 # no form, just the picker
    end

    # Attribution is applied server-side from the resolved FSM and the signed-in
    # admin, so a hand-rolled POST cannot stamp a sheet as somebody else's or
    # hide who typed it.
    test "attribution cannot be smuggled in through the settlement body" do
      sign_in @admin
      post admin_settlements_path, params: on_behalf_params(
        settlement: { recorded_by_id: @admin.id, entered_by_id: @staff.id }
      )
      settlement = DailySettlement.order(:id).last
      assert_equal @staff.id, settlement.recorded_by_id
      assert_equal @admin.id, settlement.entered_by_id
    end

    test "staff cannot record on behalf of anyone" do
      sign_in @staff
      get new_admin_settlement_path
      assert_response :redirect # ensure_admin! bounces non-admins

      assert_no_difference -> { DailySettlement.count } do
        post admin_settlements_path, params: on_behalf_params
      end
      assert_response :redirect
    end

    # An on-behalf sheet must never read as one the FSM typed themselves — on
    # the list, and on the page you reconcile from.
    test "the list and the settlement page name the admin who typed the sheet" do
      sign_in @admin
      post admin_settlements_path, params: on_behalf_params
      settlement = DailySettlement.order(:id).last

      get admin_settlements_path, params: { business_date: "2026-07-23" }
      assert_response :success
      assert_select "[data-entered-by]", text: /entered by #{Regexp.escape(@admin.display_name)}/
      # ...and the FSM still owns the money: the rollup is under them, not the admin.
      assert_select "tr[data-per-fsm-row=?]", @staff.id.to_s
      assert_select "tr[data-per-fsm-row=?]", @admin.id.to_s, count: 0

      get admin_settlement_path(settlement)
      assert_response :success
      assert_select "[data-entered-by]", text: /entered by #{Regexp.escape(@admin.display_name)}/
    end

    # Reconcile stays permitted on a self-entered sheet (a single-admin site
    # would otherwise deadlock), so entered_by is what keeps it visible.
    test "a sheet an admin enters under their own name is still flagged as admin-entered" do
      sign_in @admin
      post admin_settlements_path, params: on_behalf_params(recorded_by: @admin)
      settlement = DailySettlement.order(:id).last
      assert_equal @admin.id, settlement.recorded_by_id
      assert_equal @admin.id, settlement.entered_by_id
      assert settlement.self_entered_by_admin?
      assert_not settlement.entered_on_behalf?

      get admin_settlement_path(settlement)
      assert_select "[data-entered-by]", text: /entered by #{Regexp.escape(@admin.display_name)}/
    end
  end
end
