require "test_helper"

module Admin
  class ShiftTemplatesControllerTest < ActionDispatch::IntegrationTest
    test "admin can view shift templates index" do
      sign_in users(:one)

      get admin_shift_templates_path

      assert_response :success
      assert_select "h1", text: "Shifts"
      assert_select ".nav-section-label", text: "Attendance"
      assert_select "a.nav-link.active[href='#{admin_shift_templates_path}']", text: /Shifts/
      assert_select ".page-actions a[href='#{admin_staff_members_path}']", text: /Staff/
      assert_select ".page-actions a[href='#{admin_shift_cycles_path}']", text: /Cycles/
      assert_select ".admin-shifts-card-grid", 1
      assert_select ".admin-shifts-card--cycle", minimum: 1
      assert_select ".admin-shift-item__name", text: /Day Shift/
      assert_select ".admin-shift-item__top", minimum: 1
      assert_select "button.admin-shift-item__edit[data-bs-target='#editShiftTemplateModal-#{shift_templates(:day_shift).id}']", 1
      assert_select ".admin-shift-item__detail-label", text: /Starts At/
      assert_select ".admin-shift-item__detail-value", text: /06:00 AM/
      assert_select ".admin-shift-item__detail-label", text: /Linked Cycles/
      assert_select "label", text: "Shift Duration (hours)"
      assert_select "label", text: "Shift Start Time"
      assert_select "input[name='shift_template[start_time]']", minimum: 1
      assert_select "input[name='shift_template[duration_hours]']", minimum: 1
      assert_select "#addShiftTemplateModal", 1
    end

    test "admin can create a shift template" do
      sign_in users(:one)

      assert_difference("ShiftTemplate.count", 1) do
        post admin_shift_templates_path, params: {
          shift_template: {
            name: "Relief Shift",
            start_time: "14:30",
            duration_hours: 6,
            active: true
          }
        }
      end

      assert_redirected_to admin_shift_templates_path
      created_shift = ShiftTemplate.order(:created_at).last
      assert_equal "Relief Shift", created_shift.name
      assert_equal "14:30", created_shift.start_time_input_value
      assert_equal 360, created_shift.duration_minutes
      assert_predicate created_shift, :active?
    end
  end
end
