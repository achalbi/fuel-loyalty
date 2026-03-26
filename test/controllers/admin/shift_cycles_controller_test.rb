require "test_helper"

module Admin
  class ShiftCyclesControllerTest < ActionDispatch::IntegrationTest
    test "admin can view shift cycles index" do
      sign_in users(:one)

      get admin_shift_cycles_path

      assert_response :success
      assert_select "h1", text: "Shift Cycles"
      assert_select ".nav-section-label", text: "Attendance"
      assert_select "a.nav-link.active[href='#{admin_shift_cycles_path}']", text: /Cycles/
      assert_select ".admin-shifts-card-grid", count: 1
      assert_select ".admin-shifts-card--cycle", minimum: 1
      assert_select ".admin-shift-item__name", text: /Day and Night Rotation/
      assert_select ".admin-shift-item__details--flush", minimum: 1
      assert_select ".admin-shift-item__detail-label", text: /Flow/
      assert_select ".admin-shift-item__detail-value", text: /Each shift uses its saved duration/
      assert_select ".admin-shift-item__detail-value", text: /36 hours/
      assert_select ".admin-shift-item__sequence-shift", text: /Day Shift/
      assert_select ".admin-shift-item__sequence-shift", text: /Night Shift/
      assert_select ".admin-shift-item__sequence-arrow", text: /->/
      assert_select "label", text: "Keep Each Shift Active For"
      assert_select "button[data-shift-cycle-add-step]", text: /Add Another Shift/
      assert_select "form[action='#{deactivate_admin_shift_cycle_path(shift_cycles(:day_night_cycle))}']", 1
      assert_select "form[action='#{admin_shift_cycle_path(shift_cycles(:week_long_cycle))}'] .admin-shift-item__delete", 1
    end

    test "admin can create a shift cycle" do
      sign_in users(:one)

      assert_difference("ShiftCycle.count", 1) do
        assert_difference("ShiftCycleStep.count", 2) do
          post admin_shift_cycles_path, params: {
            shift_cycle: {
              name: "Relief Loop",
              starts_on: "2026-04-05",
              active: true,
              step_shift_template_ids: [shift_templates(:night_shift).id, shift_templates(:day_shift).id, ""]
            }
          }
        end
      end

      assert_redirected_to admin_shift_cycles_path
      created_cycle = ShiftCycle.order(:created_at).last

      assert_equal "Relief Loop", created_cycle.name
      assert_equal Date.new(2026, 4, 5), created_cycle.starts_on
      assert_equal [shift_templates(:night_shift), shift_templates(:day_shift)], created_cycle.shift_cycle_steps.order(:position).map(&:shift_template)
    end

    test "admin can deactivate a used shift cycle" do
      sign_in users(:one)

      patch deactivate_admin_shift_cycle_path(shift_cycles(:day_night_cycle))

      assert_redirected_to admin_shift_cycles_path
      assert_not shift_cycles(:day_night_cycle).reload.active?
    end

    test "admin can delete an unused shift cycle" do
      sign_in users(:one)

      assert_difference("ShiftCycle.count", -1) do
        assert_difference("ShiftCycleStep.count", -2) do
          delete admin_shift_cycle_path(shift_cycles(:week_long_cycle))
        end
      end

      assert_redirected_to admin_shift_cycles_path
    end
  end
end
