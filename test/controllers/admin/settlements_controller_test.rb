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

    # A rolled-up digest cannot be checked against the paper sheet it came from.
    # The console has to reprint what the FSM actually entered, section for
    # section, and reprint it as text — not as a form the reviewer can type into.
    test "show reprints every section of the entry sheet, read-only" do
      lube = Product.create!(name: "Engine oil 1L", category: "lubricant", pack_unit: "litre", mrp: 400, selling_price: 380)
      @settlement.update!(
        notes: "Handover to night shift",
        lube_lines_attributes: [{ product_id: lube.id, quantity: 2, opening_stock: 10, closing_stock: 8 }],
        credit_lines_attributes: [{ credit_type: "fleet_otp", litres: 30, amount: 3_000, reference: "NL-01/AE-2471" }],
        cash_denominations_attributes: [{ denomination: 500, quantity: 4 }],
        expense_lines_attributes: [{ description: "Salary advance — Ravi", amount: 250 }],
        stock_receipts_attributes: [{ fuel_type_code: "petrol", litres_received: 4_000 }],
        decantations_attributes: [{ fuel_type_code: "petrol", tank_label: "T1", opening_kl: 2, closing_kl: 6 }],
        rate_comparisons_attributes: [{ fuel_type_code: "petrol", competitor_name: "JIO-BP", competitor_price: 101, own_price: 100 }]
      )
      sign_in @admin

      get admin_settlement_path(@settlement)

      assert_response :success
      ["Nozzle readings", "Lubricants & oils", "Digital receipts", "Credit lines",
       "Cash taken out", "Cash count", "Stock received", "Decantation", "Rate comparison"].each do |section|
        assert_select "h2", text: /\A#{Regexp.escape(section)}/, count: 1, message: "#{section} is missing from the sheet"
      end
      assert_select "td", text: "Engine oil 1L"
      assert_select "td", text: "Salary advance — Ravi"
      assert_select "td", text: "PhonePe POS"
      assert_match "NL-01/AE-2471", response.body
      assert_match "Handover to night shift", response.body
      # Read-only: the sheet must not carry a single settlement input.
      assert_select "form[data-settlement-form]", count: 0
      assert_select "input[name^='settlement']", count: 0
      assert_select "select[name^='settlement']", count: 0
      assert_select "textarea[name^='settlement']", count: 0
    end

    # "Same format the staff entered" is a claim about ORDER and HEADINGS, not
    # just about which sections exist. Pin both against the entry form.
    test "the sheet keeps the entry form's section order and column headings" do
      sign_in @admin

      get admin_settlement_path(@settlement)

      assert_response :success
      order = ["Nozzle readings", "Lubricants &amp; oils", "Discounts", "Digital receipts",
               "Credit lines", "Cash taken out", "Cash count", "Stock received",
               "Decantation", "Rate comparison"]
      positions = order.map { |section| [section, response.body.index(">#{section}")] }
      positions.each { |section, at| assert_not_nil at, "#{section} is missing from the sheet" }
      assert_equal positions.map(&:last), positions.map(&:last).sort,
        "sections must appear in the entry form's order: #{order.join(' → ')}"

      # The reading grid's headings are how a reviewer lines the sheet up against
      # the paper it came from; renaming or reordering one silently breaks that.
      # (Asserted as a whole row, since "Amount" also heads two other tables.)
      headings = css_select(".settlement-sheet section:first-of-type table thead th").map { |th| th.text.strip }
      assert_equal ["Nozzle", "Fuel", "Opening", "Closing", "Testing", "Rollover", "Net L", "₹/L", "Amount"],
        headings, "the reading grid must carry the entry form's columns, in its order"
    end

    test "a section with nothing in it still shows on the sheet, said out loud" do
      sign_in @admin

      get admin_settlement_path(@settlement)

      assert_response :success
      assert_select "h2", text: /\ALubricants/
      assert_match "No lubricants sold.", response.body
      assert_match "No credit lines recorded.", response.body
    end

    test "index filters past settlements by a date range and keeps the range totals honest" do
      older = DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 10), recorded_by: @staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 900, closing_reading: 950, unit_price: 100 }]
      )
      sign_in @admin

      get admin_settlements_path, params: { from: "2026-07-01", to: "2026-07-15" }

      assert_response :success
      assert_select "td", text: older.business_date.to_s
      assert_select "td", text: @settlement.business_date.to_s, count: 0
      # The point of the rollup is the arithmetic, so read a number out of it:
      # only `older` is in range (50 L x ₹100), and @settlement must not be added.
      assert_select "div.card", text: /Cross-pump totals/ do
        assert_select "div.col", text: /₹5,000\.00/
      end
      assert_match "2026-07-01 → 2026-07-15", response.body
      assert_equal BigDecimal("5000"), older.reload.total_fuel_amount
    end

    test "index accepts a half-open range so 'everything since' is answerable" do
      DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 10), recorded_by: @staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 900, closing_reading: 950, unit_price: 100 }]
      )
      sign_in @admin

      get admin_settlements_path, params: { from: "2026-07-15" }

      assert_response :success
      assert_select "td", text: @settlement.business_date.to_s
      assert_select "td", text: "2026-07-10", count: 0
    end

    test "index searches past settlements by who filed them, by pump and by notes" do
      @settlement.update!(notes: "Tanker arrived late")
      other_staff = User.create!(
        name: "Meena Rao", username: "fsm-meena", phone_number: "9000000044",
        password: "password123", password_confirmation: "password123", role: :staff
      )
      other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
      theirs = DailySettlement.create!(
        fuel_pump: other_pump, business_date: Date.new(2026, 7, 21), recorded_by: other_staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: other_pump.nozzles.first.id, opening_reading: 10, closing_reading: 20, unit_price: 100 }]
      )
      sign_in @admin

      get admin_settlements_path, params: { q: "Meena" }
      assert_response :success
      assert_select "td", text: other_staff.display_name
      assert_select "td", text: @settlement.recorded_by.display_name, count: 0

      # A pump has no name of its own — "Pump 3" is its sequence number — so the
      # digits in the query have to be read as one.
      get admin_settlements_path, params: { q: "Pump #{other_pump.sequence_number}" }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(theirs)
      assert_select "a[href=?]", admin_settlement_path(@settlement), count: 0

      get admin_settlements_path, params: { q: "tanker" }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(@settlement)
      assert_select "a[href=?]", admin_settlement_path(theirs), count: 0
    end

    # "Meena" is also the fsm_name_snapshot, so searching for it proves nothing
    # about the recorder branch. A username and a phone number exist ONLY on the
    # user record, so these two queries can be answered by nothing else.
    test "search reaches the recorder's username and phone, not just the name snapshot" do
      other_staff = User.create!(
        name: "Meena Rao", username: "fsm-meena", phone_number: "9000000044",
        password: "password123", password_confirmation: "password123", role: :staff
      )
      other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
      theirs = DailySettlement.create!(
        fuel_pump: other_pump, business_date: Date.new(2026, 7, 21), recorded_by: other_staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: other_pump.nozzles.first.id, opening_reading: 10, closing_reading: 20, unit_price: 100 }]
      )
      # The snapshot is the display name, so neither query can be served by it.
      assert_equal "Meena Rao", theirs.fsm_name_snapshot

      sign_in @admin

      get admin_settlements_path, params: { q: "fsm-meena" }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(theirs)

      get admin_settlements_path, params: { q: "9000000044" }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(theirs)
    end

    # A pump is reachable by its number, but only when the number is what was
    # typed — a reference that merely contains digits is not a pump query.
    test "a reference that happens to contain digits is not read as a pump number" do
      @settlement.update!(credit_lines_attributes: [{ credit_type: "fleet_otp", litres: 10, amount: 1_000, reference: "NL-01/AE-2471" }])
      sign_in @admin

      # Pump 1 owns @settlement, so a wrong pump-number match would still return
      # it — search a term that matches nothing else and assert the miss.
      get admin_settlements_path, params: { q: "NL-01/AE-2471" }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(@settlement), { count: 0 },
        "digits inside a reference must not be read as 'give me everything Pump 1 filed'"

      # The bare number and the spoken form both still work.
      ["#{@pump.sequence_number}", "Pump #{@pump.sequence_number}"].each do |query|
        get admin_settlements_path, params: { q: query }
        assert_response :success
        assert_select "a[href=?]", admin_settlement_path(@settlement), { count: 1 },
          "#{query.inspect} should find Pump #{@pump.sequence_number}"
      end
    end

    test "index answers a to-only range, the mirror of the from-only one" do
      older = DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 10), recorded_by: @staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 900, closing_reading: 950, unit_price: 100 }]
      )
      sign_in @admin

      get admin_settlements_path, params: { to: "2026-07-15" }

      assert_response :success
      assert_select "td", text: older.business_date.to_s
      assert_select "td", text: @settlement.business_date.to_s, count: 0
      assert_match "up to 2026-07-15", response.body
    end

    # The search is an OR group merged into the scope; it has to narrow the other
    # filters, never widen past them.
    test "search narrows the other filters instead of escaping them" do
      other_staff = User.create!(
        name: "Meena Rao", username: "fsm-meena", phone_number: "9000000044",
        password: "password123", password_confirmation: "password123", role: :staff
      )
      other_pump = FuelPump.create!(active: true, nozzles_attributes: [{ fuel_type_code: "petrol", active: true }])
      theirs = DailySettlement.create!(
        fuel_pump: other_pump, business_date: Date.new(2026, 7, 21), recorded_by: other_staff, status: "draft",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: other_pump.nozzles.first.id, opening_reading: 10, closing_reading: 20, unit_price: 100 }]
      )
      sign_in @admin

      # "Meena" matches only theirs; the status filter excludes it, and the search
      # must not smuggle it back in.
      get admin_settlements_path, params: { q: "Meena", status: "submitted" }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(theirs), count: 0
      assert_select "a[href=?]", admin_settlement_path(@settlement), count: 0

      get admin_settlements_path, params: { q: "Meena", status: "draft" }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(theirs)

      # Same for the FSM filter: two AND-ed cuts on the same column.
      get admin_settlements_path, params: { q: "Meena", user_id: @staff.id }
      assert_response :success
      assert_select "a[href=?]", admin_settlement_path(theirs), count: 0
      assert_select "a[href=?]", admin_settlement_path(@settlement), count: 0
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
