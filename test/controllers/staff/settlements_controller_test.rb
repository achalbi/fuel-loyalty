require "test_helper"

module Staff
  class SettlementsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @pump = fuel_pumps(:one)
      @petrol = fuel_pump_nozzles(:one)
      @staff = users(:two)
      @staff.update!(fuel_pump_id: @pump.id)
      Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 102.75)
      Product.create!(name: "HSD", category: "fuel", fuel_type_code: "diesel", pack_unit: "litre", mrp: 95, selling_price: 90)
      Product.create!(name: "10W30", category: "lubricant", pack_size: 1, pack_unit: "L", mrp: 500, selling_price: 500)
    end

    # Every other test here hand-builds a `settlement: {...}` payload, so for a
    # long time nothing noticed that the rendered form named all 65 of its fields
    # `daily_settlement[...]` while all three settlement controllers read
    # `params.require(:settlement)`. A real submission arrived as `{status:}` —
    # the submit button being the one field named by hand — and every reading,
    # lube line, denomination and expense was silently discarded on save.
    #
    # This asserts the CONTRACT BETWEEN the page and the controller: post what the
    # browser would actually post, and prove the reading survives the round trip.
    test "the rendered form posts under the key the controller reads" do
      sign_in @staff
      get new_staff_settlement_path
      assert_response :success

      names = response.body.scan(/name="([^"]+)"/).flatten.uniq
      assert_empty names.select { |n| n.start_with?("daily_settlement[") },
        "the form must not emit the model's own param key — no controller reads it"
      assert_includes names, "settlement[nozzle_readings_attributes][0][closing_reading]"

      nozzle_row = { "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000",
                              closing_reading: "1180", unit_price: "102.75" } }
      assert_difference -> { DailySettlement.count }, 1 do
        post staff_settlements_path, params: {
          settlement: { fuel_pump_id: @pump.id, business_date: "2026-07-21",
                        status: "draft", nozzle_readings_attributes: nozzle_row }
        }
      end
      reading = DailySettlement.order(:id).last.nozzle_readings.find_by(fuel_pump_nozzle_id: @petrol.id)
      assert_equal 1180, reading.closing_reading.to_i, "the reading must survive the round trip"
    end

    # The admin on-behalf-of field was carried by the same broken param key as
    # every other field on this form, and none of the tests around it noticed:
    # they hand-build `settlement: {...}`, which is true whatever the page
    # renders. So an admin filling the page in a browser had `recorded_by_id`
    # discarded and hit the "name the staff member" guard with no way to satisfy
    # it. This posts what the browser would post instead of a payload of our own.
    test "the rendered on-behalf-of field round-trips to the FSM who owns the settlement" do
      admin = users(:one)
      sign_in admin
      # The pump chooser at the top of the page, as an admin would use it.
      get new_staff_settlement_path(fuel_pump_id: @pump.id)
      assert_response :success

      select_name = "settlement[recorded_by_id]"
      assert_select "select[name=?]", select_name, 1
      offered = css_select("select[name='#{select_name}'] option").map { |option| option["value"] }
      assert_includes offered, @staff.id.to_s, "the FSM must be offered"
      assert_not_includes offered, admin.id.to_s, "an admin may not file on his own behalf"

      params = rendered_settlement_params("settlement" => { "recorded_by_id" => @staff.id.to_s, "status" => "draft" })
      assert_equal @staff.id.to_s, params.dig("settlement", "recorded_by_id"),
        "the page must name this field the way the controller reads it"

      assert_difference -> { DailySettlement.count }, 1 do
        post staff_settlements_path, params: params
      end

      settlement = DailySettlement.order(:id).last
      assert_equal @staff, settlement.recorded_by, "the settlement belongs to the FSM named on the form"
      assert_equal admin, settlement.entered_by, "the admin who keyed it in stays on record"
      assert settlement.entered_on_behalf?
      assert_equal @staff.display_name, settlement.fsm_name_snapshot
    end

    test "staff can open the settlement form with a pre-filled draft and lube grid" do
      sign_in @staff
      get new_staff_settlement_path
      assert_response :success
      assert_select "form[data-settlement-form]"
      assert_select "tr[data-nozzle-row]", minimum: 2   # petrol + diesel nozzles
      assert_select "tr[data-lube-row]"                 # 10W30
      assert_select "tr[data-denom-row]", 9             # full denomination grid, ₹500 down to ₹1
    end

    test "staff can view a colleague's settlement for their pump but not edit it" do
      colleague = users(:one)
      theirs = DailySettlement.create!(
        fuel_pump: fuel_pumps(:one), business_date: Date.new(2026, 7, 21), recorded_by: colleague,
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: fuel_pump_nozzles(:one).id, opening_reading: 1, closing_reading: 2, unit_price: 100 }]
      )
      sign_in @staff

      get staff_settlements_path
      assert_response :success
      assert_select "a[href=?]", staff_settlement_path(theirs)
      assert_select "a[href=?]", edit_staff_settlement_path(theirs), count: 0

      get staff_settlement_path(theirs)
      assert_response :success

      get edit_staff_settlement_path(theirs)
      assert_redirected_to staff_settlement_path(theirs)
      assert_match(/view it but not edit it/, flash[:alert])
    end

    test "staff can submit a settlement and amounts are derived server-side" do
      sign_in @staff
      assert_difference -> { DailySettlement.count }, 1 do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            digital_receipts_attributes: { "0" => { label: "PhonePe POS", amount: "0" } },
            nozzle_readings_attributes: {
              "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
            },
            cash_denominations_attributes: {
              "0" => { denomination: "500", quantity: "20" },
            },
          },
        }
      end
      settlement = DailySettlement.order(:id).last
      assert_redirected_to staff_settlement_path(settlement)
      assert settlement.submitted?
      reading = settlement.nozzle_readings.find_by(fuel_pump_nozzle_id: @petrol.id)
      assert_equal BigDecimal("102.75"), reading.unit_price   # from catalog, not the form
      assert_equal BigDecimal("10275"), settlement.total_fuel_amount
      assert_equal BigDecimal("10000"), settlement.counted_cash_amount
    end

    test "opening new for an existing pump/date redirects to edit" do
      existing = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                         nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      sign_in @staff
      get new_staff_settlement_path, params: { fuel_pump_id: @pump.id, business_date: "2026-07-21" }
      assert_redirected_to edit_staff_settlement_path(existing)
    end

    # The on-behalf create flow ends here when the sheet already exists. Sending
    # an admin to the staff edit URL would bounce them straight back out, so the
    # hand-off goes to the console — with the same notice.
    test "opening new for an existing pump/date sends an admin to the audited console" do
      existing = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                         nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      sign_in users(:one)

      get new_staff_settlement_path, params: { fuel_pump_id: @pump.id, business_date: "2026-07-21" }

      assert_redirected_to edit_admin_settlement_path(existing)
      assert_match(/already exists for that pump and date/, flash[:notice])
      follow_redirect!
      assert_response :success
    end

    # End to end: an admin files a sheet for an FSM, then comes back to the same
    # pump/date and is carried through to the console that can correct it.
    test "an admin files on an FSM's behalf and is carried to the console on the way back" do
      admin = users(:one)
      sign_in admin

      assert_difference -> { DailySettlement.count }, 1 do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            recorded_by_id: @staff.id,
            nozzle_readings_attributes: {
              "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
            },
          },
        }
      end

      settlement = DailySettlement.order(:id).last
      assert_redirected_to staff_settlement_path(settlement)
      assert_equal @staff, settlement.recorded_by
      assert_equal admin, settlement.entered_by

      get new_staff_settlement_path, params: { fuel_pump_id: @pump.id, business_date: "2026-07-21" }
      assert_redirected_to edit_admin_settlement_path(settlement)
    end

    test "a staff settlement is recorded as its own author and cannot be reassigned" do
      sign_in @staff
      post staff_settlements_path, params: {
        settlement: {
          fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
          recorded_by_id: users(:one).id,
          nozzle_readings_attributes: {
            "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
          },
        },
      }

      settlement = DailySettlement.order(:id).last
      assert_equal @staff, settlement.recorded_by
      assert_equal @staff, settlement.entered_by
      assert_not settlement.entered_on_behalf?
    end

    test "an admin must name the staff member a settlement is entered for" do
      sign_in users(:one)

      assert_no_difference -> { DailySettlement.count } do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            nozzle_readings_attributes: {
              "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
            },
          },
        }
      end

      assert_response :unprocessable_entity
      assert_select ".alert.alert-danger", text: /on behalf of/
    end

    test "an admin entering on behalf of a staff member is recorded on both sides" do
      sign_in users(:one)

      assert_difference -> { DailySettlement.count }, 1 do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            recorded_by_id: @staff.id,
            nozzle_readings_attributes: {
              "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
            },
          },
        }
      end

      settlement = DailySettlement.order(:id).last
      assert_equal @staff, settlement.recorded_by
      assert_equal users(:one), settlement.entered_by
      assert settlement.entered_on_behalf?
      assert_equal @staff.display_name, settlement.fsm_name_snapshot
    end

    # The staff flow calls the Persister with no `admin_edit:`, so anything it
    # saves is saved with no `settlement_changes` row and no mandatory reason.
    # An admin therefore has nothing editable here at all: the sheet is untouched
    # and they are handed the audited console for the very settlement they asked
    # for. (This test used to prove only that such an edit could not re-point
    # ownership — it went through.)
    test "an admin cannot rewrite a settlement through the staff path" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           status: "submitted",
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }])
      other_staff = User.create!(name: "Other FSM", username: "fsm-other", phone_number: "9000000044",
                                 password: "password123", password_confirmation: "password123", role: :staff)
      reading = settlement.nozzle_readings.first
      sign_in users(:one)

      assert_no_difference -> { SettlementChange.count } do
        patch staff_settlement_path(settlement), params: {
          settlement: { notes: "Tidied up", recorded_by_id: other_staff.id,
                        nozzle_readings_attributes: { "0" => { id: reading.id, closing_reading: "9999" } } },
        }
      end

      assert_redirected_to edit_admin_settlement_path(settlement)
      settlement.reload
      assert_nil settlement.notes, "not one figure may change without an audit row"
      assert_equal 1100, reading.reload.closing_reading.to_i
      assert_equal @staff, settlement.recorded_by, "ownership is decided at creation and never re-pointed"
    end

    # The staff show page was reduced to the shared sheet, so nothing but this
    # test stands between an FSM and a blank page if the partial stops rendering.
    test "the staff sheet shows the settlement in the format it was entered" do
      settlement = DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff, status: "submitted",
        digital_receipts_attributes: [{ label: "PhonePe POS", amount: 500 }],
        cash_denominations_attributes: [{ denomination: 500, quantity: 4 }],
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }]
      )
      sign_in @staff

      get staff_settlement_path(settlement)

      assert_response :success
      ["Nozzle readings", "Lubricants &amp; oils", "Digital receipts", "Credit lines",
       "Cash taken out", "Cash count", "Stock received", "Decantation", "Rate comparison"].each do |section|
        assert_includes response.body, ">#{section}", "#{section} is missing from the staff sheet"
      end
      assert_select "td", text: "PhonePe POS"
      assert_select "td", text: "₹500"
      # Read-only here too: the sheet is not the entry form.
      assert_select "form[data-settlement-form]", count: 0
      assert_select "input[name^='settlement']", count: 0
    end

    # An Edit control that only bounces the person who clicks it is worse than no
    # control: the list and the sheet must point an admin at the console directly.
    test "the Edit control an admin sees points at the audited console, not the staff form" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      sign_in users(:one)

      get staff_settlements_path
      assert_response :success
      assert_select "a[href=?]", edit_admin_settlement_path(settlement)
      assert_select "a[href=?]", edit_staff_settlement_path(settlement), count: 0

      get staff_settlement_path(settlement)
      assert_response :success
      assert_select "a[href=?]", edit_admin_settlement_path(settlement)
      assert_select "a[href=?]", edit_staff_settlement_path(settlement), count: 0
    end

    test "an admin opening the staff edit form lands in the audited console for that settlement" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      sign_in users(:one)

      get edit_staff_settlement_path(settlement)

      assert_redirected_to edit_admin_settlement_path(settlement),
        "an admin must not lose which sheet they came for"
      assert_match(/audited admin console/, flash[:notice])
    end

    # The console the admin is sent to must actually do the job the staff path no
    # longer does: save the change, with a reason, on the record.
    test "the admin console the staff path hands off to still edits and still audits" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           status: "submitted",
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1000, closing_reading: 1100, unit_price: 100 }])
      sign_in users(:one)

      get edit_staff_settlement_path(settlement)
      follow_redirect!
      assert_response :success

      assert_difference -> { SettlementChange.count }, 1 do
        patch admin_settlement_path(settlement), params: {
          change_reason: "FSM misread the meter", on_behalf_of_id: @staff.id,
          settlement: { notes: "Corrected by admin" },
        }
      end

      assert_redirected_to admin_settlement_path(settlement)
      assert_equal "Corrected by admin", settlement.reload.notes
      change = SettlementChange.order(:id).last
      assert_equal users(:one), change.changed_by
      assert_equal @staff, change.on_behalf_of
      assert_equal "FSM misread the meter", change.change_reason
    end

    # The live half of the ownership guard: an FSM editing their own sheet is
    # still the one path that reaches `settlement_params` on update.
    test "a staff member editing their own settlement cannot re-point it at anyone" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      sign_in @staff

      patch staff_settlement_path(settlement), params: { settlement: { recorded_by_id: users(:one).id, notes: "Not mine now?" } }

      assert_redirected_to staff_settlement_path(settlement)
      settlement.reload
      assert_equal @staff, settlement.recorded_by, "ownership is decided at creation and never re-pointed"
      assert_equal "Not mine now?", settlement.notes, "an FSM still edits the sheet they recorded"
    end

    test "an admin cannot file a settlement on behalf of himself" do
      sign_in users(:one)

      assert_no_difference -> { DailySettlement.count } do
        post staff_settlements_path, params: {
          settlement: {
            fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
            recorded_by_id: users(:one).id,
            nozzle_readings_attributes: {
              "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "1000", closing_reading: "1100", testing_litres: "0" },
            },
          },
        }
      end

      assert_response :unprocessable_entity
      assert_select "select[name='settlement[recorded_by_id]'] option[value=?]", users(:one).id.to_s, count: 0
    end

    # Was driven through the staff path as an admin; an admin edit now happens in
    # the audited console, so the guard is asserted where the edit actually runs.
    test "a pre-existing settlement is not back-stamped as entered by whoever edits it" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      # Simulate a row created before the entered_by column existed.
      settlement.update_column(:entered_by_id, nil)
      sign_in users(:one)

      patch admin_settlement_path(settlement), params: {
        change_reason: "Admin correction", on_behalf_of_id: @staff.id,
        settlement: { notes: "Admin correction" },
      }

      settlement.reload
      assert_equal "Admin correction", settlement.notes, "the audited edit still saves"
      assert_nil settlement.entered_by_id, "an edit must not claim the editor keyed the settlement in"
      assert_not settlement.entered_on_behalf?
    end

    test "an admin with no staff accounts is told why they cannot record a settlement" do
      @staff.soft_delete! if @staff.update!(active: false) || true
      sign_in users(:one)

      get new_staff_settlement_path

      assert_response :success
      assert_select ".alert.alert-warning", text: /no staff accounts yet/
      assert_select "select[name='settlement[recorded_by_id]']", 0
    end

    # Everything the rendered form would submit: each named field with the value
    # the page gave it, nested the way Rack parses a real form body. `overrides`
    # stand in for what the user types or clicks (the submit button is a field
    # too, and is the only one a browser sends by name alone).
    def rendered_settlement_params(overrides = {})
      form = css_select("form[data-settlement-form]").first
      pairs = form.css("input, select, textarea").filter_map do |field|
        name = field["name"].to_s
        next if name.empty? || field.attributes.key?("disabled")

        case field.name
        when "input"
          type = (field["type"] || "text").downcase
          next if %w[submit button image file].include?(type)
          next if %w[checkbox radio].include?(type) && !field.attributes.key?("checked")

          [name, field["value"].to_s]
        when "select"
          # A browser submits the marked option, or the first one when none is.
          option = field.css("option[selected]").first || field.css("option").first
          [name, option&.attr("value").to_s]
        when "textarea"
          [name, field.text]
        end
      end
      query = pairs.map { |name, value| "#{CGI.escape(name)}=#{CGI.escape(value)}" }.join("&")
      Rack::Utils.parse_nested_query(query).deep_merge(overrides.deep_stringify_keys)
    end

    # The draft resolves the pump from the caller's assignment ON the business
    # date, so an FSM the admin only posts day-by-day (no standing pump) opens
    # the sheet for yesterday with no pump — and the nozzle grid renders empty.
    # It used to render empty and SILENT: no rows, no explanation, and nothing
    # on the page saying the pump chooser was the way out.
    test "an empty nozzle grid says why instead of rendering nothing" do
      @staff.update!(fuel_pump_id: nil, assigned_fuel_pump_nozzle_ids: [])
      sign_in @staff
      get new_staff_settlement_path

      assert_response :success
      assert_select "input[name=?]", "settlement[nozzle_readings_attributes][0][closing_reading]", 0
      assert_match(/No pump is assigned to you/, response.body)
    end

    test "a pump with no active nozzles says so rather than rendering an empty grid" do
      @pump.nozzles.update_all(active: false)
      sign_in @staff
      get new_staff_settlement_path(fuel_pump_id: @pump.id)

      assert_response :success
      assert_select "input[name=?]", "settlement[nozzle_readings_attributes][0][closing_reading]", 0
      assert_match(/has no active nozzles/, response.body)
    end

    test "a locked settlement cannot be edited" do
      settlement = DailySettlement.create!(fuel_pump: @pump, business_date: Date.new(2026, 7, 21), recorded_by: @staff,
                                           status: "reconciled", locked: true,
                                           nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 1, closing_reading: 2, unit_price: 100 }])
      sign_in @staff
      get edit_staff_settlement_path(settlement)
      assert_redirected_to staff_settlement_path(settlement)
    end

    # The opening reading is auto-filled from the last settled sheet, but a pump
    # that went unsettled for a few days kept selling — the offered figure is
    # then behind the meter and only the FSM can say where it is. It has to be
    # typeable, and the sheet has to show that it was typed.
    test "the opening reading is editable and a typed-over value is recorded as corrected" do
      DailySettlement.create!(
        fuel_pump: @pump, business_date: Date.new(2026, 7, 15), recorded_by: @staff, status: "submitted",
        nozzle_readings_attributes: [{ fuel_pump_nozzle_id: @petrol.id, opening_reading: 500, closing_reading: 1000, unit_price: 100 }]
      )
      sign_in @staff

      get new_staff_settlement_path(fuel_pump_id: @pump.id, business_date: "2026-07-21")
      assert_response :success
      opening_field = css_select("input[name='settlement[nozzle_readings_attributes][0][opening_reading]']").first
      assert_not_nil opening_field
      assert_nil opening_field["readonly"], "the FSM must be able to correct the auto-filled opening"
      assert_equal "1000.0", opening_field["data-opening-auto"]
      assert_match "5 days not settled", response.body

      post staff_settlements_path, params: {
        settlement: {
          fuel_pump_id: @pump.id, business_date: "2026-07-21", status: "submitted",
          nozzle_readings_attributes: {
            "0" => { fuel_pump_nozzle_id: @petrol.id, opening_reading: "2310.500", closing_reading: "2400" },
          },
        },
      }
      settlement = DailySettlement.order(:id).last
      reading = settlement.nozzle_readings.find_by(fuel_pump_nozzle_id: @petrol.id)
      assert_equal BigDecimal("2310.5"), reading.opening_reading
      assert_equal "corrected", reading.opening_source
      assert_equal BigDecimal("1000"), reading.prior_closing_reading

      get staff_settlement_path(settlement)
      assert_response :success
      assert_select "span.badge", text: "edited"
    end
  end
end
