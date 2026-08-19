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
            digital_receipts_attributes: [{ label: "PhonePe POS", amount: 500 }],
            nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }]
          )
          @receipt = @settlement.digital_receipts.first
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        # A sheet on a NEW pump, because the pump/date/shift index is unique and
        # a day therefore holds one sheet per pump. `litres` × ₹100 is the fuel
        # money.
        def settlement_on_new_pump(recorded_by:, business_date:, status:, litres:)
          pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
          DailySettlement.create!(
            fuel_pump: pump, business_date: business_date, recorded_by: recorded_by, status: status,
            nozzle_readings_attributes: [{ fuel_pump_nozzle_id: pump.nozzles.first.id, opening_reading: 0, closing_reading: litres, unit_price: 100 }]
          )
        end

        # Recorded by the ADMIN on purpose: admin-recorded sheets exist and must
        # stay filterable. ₹1,000 of fuel.
        def admin_recorded_settlement
          settlement_on_new_pump(recorded_by: @admin, business_date: Date.new(2026, 7, 21), status: "submitted", litres: 10)
        end

        test "index returns cross-pump totals for a single date across all pumps" do
          get api_v1_admin_settlements_path, params: { business_date: "2026-07-21" }, headers: auth_headers(@admin)
          assert_response :ok
          totals = response.parsed_body["cross_pump_totals"]
          assert_not_nil totals
          assert_equal 10000.0, totals["total_fuel_amount"]
          assert_equal 9500.0, totals["final_amount_to_settle"] # 10000 - 500 phonepe
        end

        test "index filters by recorded_by_id and exposes the id on each row" do
          other = admin_recorded_settlement

          get api_v1_admin_settlements_path,
            params: { business_date: "2026-07-21", recorded_by_id: @staff.id }, headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body
          assert_equal [@settlement.id], body["settlements"].map { |s| s["id"] }
          # Admin-12: the id, not just the display name, so a native client can
          # group a list by the FSM who recorded each sheet.
          assert_equal [@staff.id], body["settlements"].map { |s| s["recorded_by_id"] }

          get api_v1_admin_settlements_path,
            params: { business_date: "2026-07-21", recorded_by_id: @admin.id }, headers: auth_headers(@admin)
          assert_equal [other.id], response.parsed_body["settlements"].map { |s| s["id"] }
        end

        test "index returns per-FSM totals and an option list that includes admins" do
          admin_recorded_settlement

          get api_v1_admin_settlements_path, params: { business_date: "2026-07-21" }, headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body

          rows = body["per_fsm_totals"].index_by { |row| row["recorded_by_id"] }
          assert_equal 2, rows.size
          assert_equal 1, rows[@staff.id]["settlement_count"]
          assert_equal 10000.0, rows[@staff.id].dig("totals", "total_fuel_amount")
          assert_equal 9500.0, rows[@staff.id].dig("totals", "final_amount_to_settle") # 10000 − 500 receipt
          assert_equal 1000.0, rows[@admin.id].dig("totals", "total_fuel_amount")
          assert_equal @staff.display_name, rows[@staff.id]["fsm_name"]

          # The filter's option list must reach admin-recorded sheets too.
          assert_equal [@admin.id, @staff.id].sort, body["fsm_options"].map { |o| o["id"] }.sort
        end

        test "per-FSM totals ignore drafts" do
          # One FSM, one day, two sheets: a ₹50,000 draft and a ₹1,000 submitted
          # one. The row must carry the submitted sheet's money ONLY — counting
          # the draft would read 2 sheets and ₹51,000.
          DailySettlement.create!(
            fuel_pump: @pump, business_date: Date.new(2026, 7, 22), recorded_by: @staff, status: "draft",
            nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 0, closing_reading: 500, unit_price: 100 }]
          )
          settlement_on_new_pump(recorded_by: @staff, business_date: Date.new(2026, 7, 22), status: "submitted", litres: 10)

          get api_v1_admin_settlements_path, params: { business_date: "2026-07-22" }, headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body
          assert_equal 2, body["settlements"].size # the draft is listed...
          assert_equal 1, body["per_fsm_totals"].size # ...but it is not money yet
          row = body["per_fsm_totals"].first
          assert_equal @staff.id, row["recorded_by_id"]
          assert_equal 1, row["settlement_count"]
          assert_equal 1000.0, row.dig("totals", "total_fuel_amount")
          # And the day's cross-pump block agrees — drafts are out of both.
          assert_equal 1000.0, body.dig("cross_pump_totals", "total_fuel_amount")
        end

        test "filtered_by names the recorder the rows were narrowed to" do
          get api_v1_admin_settlements_path,
            params: { business_date: "2026-07-21", recorded_by_id: @staff.id }, headers: auth_headers(@admin)
          assert_response :ok
          # cross_pump_totals says "the whole day across all pumps"; with this
          # filter on it is one operator's money, and the payload has to say so.
          assert_equal({ "recorded_by_id" => @staff.id, "fsm_name" => @staff.display_name },
                       response.parsed_body["filtered_by"])

          get api_v1_admin_settlements_path, params: { business_date: "2026-07-21" }, headers: auth_headers(@admin)
          assert_nil response.parsed_body["filtered_by"]
        end

        # The web used to drop the filter when the id matched no user, listing
        # everybody; here the same id has always returned nothing. Both surfaces
        # now narrow to nothing, and the label stays qualified.
        test "an unrecognised recorded_by_id returns no settlements and no totals" do
          admin_recorded_settlement
          unknown = User.maximum(:id) + 1

          get api_v1_admin_settlements_path,
            params: { business_date: "2026-07-21", recorded_by_id: unknown }, headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body
          assert_equal [], body["settlements"]
          assert_equal [], body["per_fsm_totals"]
          assert_equal({ "recorded_by_id" => unknown, "fsm_name" => nil }, body["filtered_by"])
          assert_equal 0.0, body.dig("cross_pump_totals", "total_fuel_amount")
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
              settlement: { digital_receipts_attributes: [{ id: @receipt.id, label: "PhonePe POS", amount: "700" }] },
            }, headers: auth_headers(@admin)
          end
          assert_response :ok
          body = response.parsed_body
          assert_equal false, body["points_recomputed"]
          change = @settlement.audit_changes.last
          assert_equal "Correcting PhonePe total", change.change_reason
          assert_equal ["500.0", "700.0"], change.field_diffs["total_digital_receipt_amount"]
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

        # --- record on behalf of (staff feedback item 3) --------------------

        # A slot the fixture settlement does not already occupy — (pump, date,
        # shift) is unique and @settlement holds pump one on 2026-07-21.
        def on_behalf_body(**overrides)
          {
            recorded_by_id: @staff.id,
            change_reason: "Ravi was on sick leave; readings dictated at the counter",
            settlement: {
              fuel_pump_id: @pump.id,
              business_date: "2026-07-22",
              nozzle_readings_attributes: [
                { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1100", closing_reading: "1200" },
              ],
            },
          }.deep_merge(overrides)
        end

        test "new lists the operators a sheet may be recorded for, admins included" do
          get api_v1_admin_new_settlement_path, headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body

          # Not scoped to role: :staff — an admin stands a shift on a small site,
          # and admin-recorded sheets already exist in the data.
          assert_equal [@admin.id, @staff.id].sort, body["fsm_options"].map { |o| o["id"] }.sort
          assert_includes body["fsm_options"].map { |o| o["role"] }, "admin"
          # The picker row carries the operator's standing pump as a hint.
          staff_option = body["fsm_options"].find { |o| o["id"] == @staff.id }
          assert_equal @pump.id, staff_option["default_fuel_pump_id"]
          # Whoever is typing is named up front, so the form can say "entered by".
          assert_equal({ "id" => @admin.id, "name" => @admin.display_name }, body["entered_by"])
          # Nothing to hydrate before an FSM is picked: the nozzles, the
          # yesterday readings and the pulled discounts all hang off their pump.
          assert_nil body["recorded_for"]
          assert_nil body["draft"]
        end

        test "new hydrates the draft against the named FSM's pump" do
          get api_v1_admin_new_settlement_path,
            params: { recorded_by_id: @staff.id, business_date: "2026-07-22" }, headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body

          assert_equal({ "id" => @staff.id, "name" => @staff.display_name }, body["recorded_for"])
          draft = body["draft"]
          assert_equal @pump.id, draft.dig("fuel_pump", "id")
          assert_equal @staff.display_name, draft["fsm_name"]
          # Yesterday's closing from the FSM's own pump is auto-popped.
          petrol = draft["nozzle_readings"].find { |r| r["fuel_pump_nozzle_id"] == @petrol.id }
          assert_equal 1100.0, petrol["opening_reading"]
          assert_equal "prior_settlement", petrol["opening_source"]
          assert_nil draft["existing_settlement_id"]
        end

        test "new points at the sheet that already fills the slot" do
          get api_v1_admin_new_settlement_path,
            params: { recorded_by_id: @staff.id, business_date: "2026-07-21" }, headers: auth_headers(@admin)
          assert_response :ok
          assert_equal @settlement.id, response.parsed_body.dig("draft", "existing_settlement_id")
        end

        test "creating on behalf attributes the sheet to the FSM and the entry to the admin" do
          assert_difference -> { DailySettlement.count }, 1 do
            post api_v1_admin_settlements_path, params: on_behalf_body, headers: auth_headers(@admin), as: :json
          end
          assert_response :created
          body = response.parsed_body

          created = DailySettlement.find(body["id"])
          assert_equal @staff, created.recorded_by
          assert_equal @staff.display_name, created.fsm_name_snapshot
          assert_equal @admin, created.entered_by
          # The admin submits directly — parking it in draft would wait on the
          # very FSM who could not act.
          assert_equal "submitted", created.status

          # And the payload says "recorded for X, entered by Y" without a lookup.
          assert_equal @staff.id, body["recorded_by_id"]
          assert_equal @staff.display_name, body["fsm_name"]
          assert_equal @admin.id, body["entered_by_id"]
          assert_equal @admin.display_name, body["entered_by_name"]
          assert_equal true, body["entered_on_behalf"]
        end

        test "creating on behalf writes the audit row and returns it" do
          assert_difference -> { SettlementChange.count }, 1 do
            post api_v1_admin_settlements_path, params: on_behalf_body, headers: auth_headers(@admin), as: :json
          end
          assert_response :created

          change = response.parsed_body["changes"].first
          assert_equal @admin.display_name, change["changed_by"]
          assert_equal "Ravi was on sick leave; readings dictated at the counter", change["change_reason"]
          assert_equal [nil, @staff.id.to_s], change.dig("field_diffs", "recorded_by_id")
          assert_equal [nil, @admin.id.to_s], change.dig("field_diffs", "entered_by_id")
        end

        test "creating on behalf accepts a status the client asks for" do
          post api_v1_admin_settlements_path, params: on_behalf_body(settlement: { status: "draft" }),
            headers: auth_headers(@admin), as: :json
          assert_response :created
          assert_equal "draft", response.parsed_body["status"]
        end

        test "the FSM is taken from the request, never from the settlement body" do
          # A client that tries to smuggle attribution into the nested object
          # must not be able to reattribute the sheet or name its own enterer.
          post api_v1_admin_settlements_path,
            params: on_behalf_body(settlement: { recorded_by_id: @admin.id, entered_by_id: @staff.id }),
            headers: auth_headers(@admin), as: :json
          assert_response :created
          body = response.parsed_body
          # Top-level recorded_by_id (the FSM) wins; entered_by is the caller.
          assert_equal @staff.id, body["recorded_by_id"]
          assert_equal @admin.id, body["entered_by_id"]
        end

        test "creating on behalf without a reason is rejected" do
          assert_no_difference -> { DailySettlement.count } do
            post api_v1_admin_settlements_path, params: on_behalf_body(change_reason: ""),
              headers: auth_headers(@admin), as: :json
          end
          assert_response :unprocessable_entity
          assert_equal "change_reason_required", response.parsed_body.dig("error", "code")
        end

        test "creating on behalf without naming an FSM is rejected" do
          body = on_behalf_body
          body.delete(:recorded_by_id)

          assert_no_difference -> { DailySettlement.count } do
            post api_v1_admin_settlements_path, params: body, headers: auth_headers(@admin), as: :json
          end
          assert_response :unprocessable_entity
          assert_equal "recorded_by_required", response.parsed_body.dig("error", "code")
        end

        test "an FSM who is not on the picker list is refused" do
          # Deactivated: their historical sheets stay readable and filterable,
          # but no fresh sheet may be opened in their name.
          @staff.update!(active: false)

          post api_v1_admin_settlements_path, params: on_behalf_body, headers: auth_headers(@admin), as: :json
          assert_response :unprocessable_entity
          assert_equal "recorded_by_invalid", response.parsed_body.dig("error", "code")

          get api_v1_admin_new_settlement_path, params: { recorded_by_id: @staff.id }, headers: auth_headers(@admin)
          assert_response :unprocessable_entity
          assert_equal "recorded_by_invalid", response.parsed_body.dig("error", "code")
        end

        test "a slot that already has a sheet is a clean conflict, not a crash" do
          # @settlement already holds pump one on 2026-07-21 with no shift.
          assert_no_difference -> { DailySettlement.count } do
            post api_v1_admin_settlements_path,
              params: on_behalf_body(settlement: { business_date: "2026-07-21" }),
              headers: auth_headers(@admin), as: :json
          end
          assert_response :conflict
          body = response.parsed_body
          assert_equal "settlement_exists", body.dig("error", "code")
          # Named, so the console can offer "open the existing sheet" instead.
          assert_equal @settlement.id, body.dig("error", "details", "existing_settlement_id")
        end

        test "staff cannot record on behalf of anyone" do
          get api_v1_admin_new_settlement_path, headers: auth_headers(@staff)
          assert_response :forbidden

          assert_no_difference -> { DailySettlement.count } do
            post api_v1_admin_settlements_path, params: on_behalf_body, headers: auth_headers(@staff), as: :json
          end
          assert_response :forbidden
        end

        test "the on-behalf capability is admin-only and the FSM form stays staff-only" do
          # Wave 2 closed the unaudited back door by making new?/create? staff
          # only; this capability must not have quietly reopened it.
          assert DailySettlementPolicy.new(@admin, DailySettlement).create_on_behalf?
          assert_not DailySettlementPolicy.new(@staff, DailySettlement).create_on_behalf?
          assert_not DailySettlementPolicy.new(@admin, DailySettlement).new?
          assert_not DailySettlementPolicy.new(@admin, DailySettlement).create?
        end

        test "the index and show payloads carry the enterer" do
          post api_v1_admin_settlements_path, params: on_behalf_body, headers: auth_headers(@admin), as: :json
          assert_response :created
          created_id = response.parsed_body["id"]

          get api_v1_admin_settlements_path, params: { business_date: "2026-07-22" }, headers: auth_headers(@admin)
          assert_response :ok
          row = response.parsed_body["settlements"].find { |s| s["id"] == created_id }
          assert_equal @admin.id, row["entered_by_id"]
          assert_equal @admin.display_name, row["entered_by_name"]
          assert_equal true, row["entered_on_behalf"]
          # The sheet still counts as the FSM's money in the per-FSM rollup.
          assert_equal [@staff.id], response.parsed_body["per_fsm_totals"].map { |r| r["recorded_by_id"] }

          get api_v1_admin_settlement_path(created_id), headers: auth_headers(@admin)
          assert_response :ok
          assert_equal @admin.id, response.parsed_body["entered_by_id"]
        end

        test "an FSM-recorded sheet reports no enterer" do
          get api_v1_admin_settlement_path(@settlement), headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body
          assert_nil body["entered_by_id"]
          assert_nil body["entered_by_name"]
          assert_equal false, body["entered_on_behalf"]
        end
      end
    end
  end
end
