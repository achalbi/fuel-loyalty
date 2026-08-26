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

        test "index returns cross-pump totals for a single date across all pumps" do
          get api_v1_admin_settlements_path, params: { business_date: "2026-07-21" }, headers: auth_headers(@admin)
          assert_response :ok
          totals = response.parsed_body["cross_pump_totals"]
          assert_not_nil totals
          assert_equal 10000.0, totals["total_fuel_amount"]
          assert_equal 9500.0, totals["final_amount_to_settle"] # 10000 - 500 phonepe
        end

        # The app's settlement list is where an admin goes looking for a past day,
        # so it takes the same range + free-text cuts the web console does.
        test "index filters by an open-ended range and by free text" do
          older = DailySettlement.create!(
            fuel_pump: @pump, business_date: Date.new(2026, 7, 10), recorded_by: @staff, status: "submitted",
            notes: "Tanker arrived late",
            nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 900, closing_reading: 950, unit_price: 100 }]
          )

          get api_v1_admin_settlements_path, params: { from: "2026-07-15" }, headers: auth_headers(@admin)
          assert_response :ok
          assert_equal [@settlement.id], response.parsed_body["settlements"].map { |row| row["id"] }
          assert_not_nil response.parsed_body["cross_pump_totals"], "a range is still a period worth totalling"

          get api_v1_admin_settlements_path, params: { to: "2026-07-15" }, headers: auth_headers(@admin)
          assert_response :ok
          assert_equal [older.id], response.parsed_body["settlements"].map { |row| row["id"] }

          get api_v1_admin_settlements_path, params: { q: "tanker" }, headers: auth_headers(@admin)
          assert_response :ok
          assert_equal [older.id], response.parsed_body["settlements"].map { |row| row["id"] }
        end

        # The list is the Android admin's only way back to a past day, so every
        # branch of the shared search has to answer here too — not just notes.
        test "index search reaches the FSM snapshot, the recorder's credentials and the pump number" do
          other_staff = User.create!(
            name: "Meena Rao", username: "fsm-meena", phone_number: "9000000044",
            password: "password123", password_confirmation: "password123", role: :staff
          )
          other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
          theirs = DailySettlement.create!(
            fuel_pump: other_pump, business_date: Date.new(2026, 7, 21), recorded_by: other_staff, status: "submitted",
            nozzle_readings_attributes: [{ fuel_pump_nozzle_id: other_pump.nozzles.first.id, opening_reading: 10, closing_reading: 20, unit_price: 100 }]
          )

          { "Meena Rao" => "the FSM name snapshot", "fsm-meena" => "the recorder's username",
            "9000000044" => "the recorder's phone", "Pump #{other_pump.sequence_number}" => "the pump number" }.each do |query, branch|
            get api_v1_admin_settlements_path, params: { q: query }, headers: auth_headers(@admin)
            assert_response :ok
            assert_equal [theirs.id], response.parsed_body["settlements"].map { |row| row["id"] }, "search by #{branch} failed"
          end
        end

        test "index search narrows the other filters instead of escaping them" do
          other_staff = User.create!(
            name: "Meena Rao", username: "fsm-meena", phone_number: "9000000044",
            password: "password123", password_confirmation: "password123", role: :staff
          )
          other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
          DailySettlement.create!(
            fuel_pump: other_pump, business_date: Date.new(2026, 7, 21), recorded_by: other_staff, status: "draft",
            nozzle_readings_attributes: [{ fuel_pump_nozzle_id: other_pump.nozzles.first.id, opening_reading: 10, closing_reading: 20, unit_price: 100 }]
          )

          # "Meena" matches only the draft; the status filter excludes it, and the
          # search must not smuggle it back past that filter.
          get api_v1_admin_settlements_path, params: { q: "Meena", status: "submitted" }, headers: auth_headers(@admin)
          assert_response :ok
          assert_empty response.parsed_body["settlements"]
        end

        # Same query string, same rows, on both surfaces: an explicit range wins
        # over business_date rather than being AND-ed on top of it.
        test "an explicit range overrides business_date, as the web console resolves it" do
          older = DailySettlement.create!(
            fuel_pump: @pump, business_date: Date.new(2026, 7, 10), recorded_by: @staff, status: "submitted",
            nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 900, closing_reading: 950, unit_price: 100 }]
          )

          get api_v1_admin_settlements_path,
            params: { business_date: "2026-07-21", from: "2026-07-01", to: "2026-07-15" },
            headers: auth_headers(@admin)

          assert_response :ok
          assert_equal [older.id], response.parsed_body["settlements"].map { |row| row["id"] }
        end

        test "an unparseable business_date reports no rollup rather than an all-zero one" do
          get api_v1_admin_settlements_path, params: { business_date: "not-a-date" }, headers: auth_headers(@admin)
          assert_response :ok
          assert_nil response.parsed_body["cross_pump_totals"],
            "a junk date must not render a rollup of zeroes that reads as 'the day was empty'"
        end

        test "show includes the audit changes array" do
          get api_v1_admin_settlement_path(@settlement), headers: auth_headers(@admin)
          assert_response :ok
          assert_equal [], response.parsed_body["changes"]
        end

        # The native admin sheet marks a typed-over opening "edited" and captions
        # it with what it was auto-filled from, so the detail payload has to
        # carry all three fields — the marker is only as trustworthy as the
        # `opening_source` the server derives.
        test "show carries the derived opening source and the figure it was offered" do
          # @settlement closed this nozzle at 1100 on the 21st; the 25th's sheet
          # is offered that and the FSM types over it, the gap being the point.
          corrected = DailySettlement.new(fuel_pump: @pump, business_date: Date.new(2026, 7, 25), recorded_by: @staff)
          Settlement::Persister.call(
            settlement: corrected, actor: @staff,
            attributes: {
              status: "submitted",
              nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: "1490.250", closing_reading: "1600" }],
            }
          )

          get api_v1_admin_settlement_path(corrected), headers: auth_headers(@admin)
          assert_response :ok

          reading = response.parsed_body["nozzle_readings"].first
          assert_equal "corrected", reading["opening_source"]
          assert_equal 1100.0, reading["prior_closing_reading"]
          assert_equal "2026-07-21", reading["prior_closing_date"]
        end

        test "update without a change reason is rejected" do
          patch api_v1_admin_settlement_path(@settlement),
            params: { settlement: { notes: "fix" } }, headers: auth_headers(@admin)
          assert_response :unprocessable_entity
          assert_equal "change_reason_required", response.parsed_body.dig("error", "code")
        end

        test "update without an on-behalf-of staff member is rejected" do
          assert_no_difference -> { SettlementChange.count } do
            patch api_v1_admin_settlement_path(@settlement),
              params: { change_reason: "fix", settlement: { notes: "fix" } }, headers: auth_headers(@admin)
          end
          assert_response :unprocessable_entity
          assert_equal "on_behalf_of_required", response.parsed_body.dig("error", "code")
        end

        test "update with a reason writes an audit row with field diffs" do
          assert_difference -> { SettlementChange.count }, 1 do
            patch api_v1_admin_settlement_path(@settlement), params: {
              change_reason: "Correcting PhonePe total",
              on_behalf_of_id: @staff.id,
              settlement: { digital_receipts_attributes: [{ id: @receipt.id, label: "PhonePe POS", amount: "700" }] },
            }, headers: auth_headers(@admin)
          end
          assert_response :ok
          body = response.parsed_body
          assert_equal false, body["points_recomputed"]
          change = @settlement.audit_changes.last
          assert_equal "Correcting PhonePe total", change.change_reason
          assert_equal @staff, change.on_behalf_of
          assert_equal ["500.0", "700.0"], change.field_diffs["total_digital_receipt_amount"]
          assert_equal 9300.0, body["final_amount_to_settle"] # 10000 - 700
          assert_equal @staff.display_name, body["changes"].first["on_behalf_of"]
        end

        test "index reports per-user totals and filters by user" do
          get api_v1_admin_settlements_path, params: { business_date: @settlement.business_date.iso8601 },
            headers: auth_headers(@admin)

          assert_response :ok
          rollup = response.parsed_body["per_user_totals"]
          assert_equal 1, rollup.size
          assert_equal @staff.id, rollup.first["user_id"]
          assert_equal 1, rollup.first["count"]

          get api_v1_admin_settlements_path, params: { user_id: @admin.id }, headers: auth_headers(@admin)

          assert_response :ok
          assert_equal 0, response.parsed_body["total"]
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
