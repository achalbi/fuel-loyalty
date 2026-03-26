require "test_helper"

module Admin
  class StaffMembersControllerTest < ActionDispatch::IntegrationTest
    test "admin can view staff members index" do
      sign_in users(:one)

      travel_to Time.zone.parse("2026-03-26 08:00") do
        get admin_staff_members_path
      end

      assert_response :success
      assert_select "h1", text: "Staff"
      assert_select ".nav-section-label", text: "Attendance"
      assert_select "a.nav-link.active[href='#{admin_staff_members_path}']", text: /Staff/
      assert_select ".admin-staff-list", 1
      assert_select ".admin-staff-card--member", minimum: 1
      assert_select ".admin-staff-member__details--flush", minimum: 1
      assert_select ".admin-staff-member__name", text: /Staff/
      assert_select ".admin-staff-member__heading .admin-user-item__role", 0
      assert_select ".admin-staff-member__side .admin-user-item__role", minimum: 1
      assert_select ".admin-staff-member__shift-value", text: /Day Shift/
      assert_select ".admin-staff-member__detail-label", text: /Mobile/
      assert_select ".admin-staff-member__detail-label", text: /Shift Cycle/
      assert_select ".admin-staff-member__detail-value", text: /Day and Night Rotation/
      assert_select ".admin-staff-member__subcopy", text: /Forecourt lead for the morning shift/
      assert_select ".admin-staff-member__subcopy", text: /Included in future planning and attendance\./, count: 0
      assert_select ".admin-staff-member__shift-meta", text: /Starts 06:00 AM/
      assert_select ".admin-staff-member__shift-meta", text: /Day and Night Rotation/
      assert_select "input[placeholder='Add an internal employee code only if your station uses one']", 1
      assert_select "input[placeholder='Add a short subtitle that helps the team recognise this staff member']", 1
      assert_select "input[placeholder='Explain why this shift is being assigned or changed']", 1
      assert_select "select[name='shift_assignment[shift_template_id]']", minimum: 1
      assert_select "select[name='shift_assignment[shift_template_id]'] option[selected][value='#{shift_templates(:day_shift).id}']", text: /Day Shift/
      assert_select "input[name='shift_assignment[effective_from_date]']", 0
      assert_select "input[name='shift_assignment[effective_from_time]']", 0
      assert_select "form[action='#{admin_staff_member_path(users(:two))}']", 1
      assert_select "button.admin-staff-member__action[data-bs-target='#editStaffProfileModal-#{users(:two).id}']", 1
      assert_select "button.admin-staff-member__action[data-bs-target='#assignStaffShiftModal-#{users(:two).id}']", text: /Shift/
      assert_select "#editStaffProfileModal-#{users(:two).id}", 1
      assert_select "#assignStaffShiftModal-#{users(:two).id}", 1
    end

    test "admin can update a staff member status, employee code, and subtitle" do
      sign_in users(:one)

      patch admin_staff_member_path(users(:two)), params: {
        user: {
          active: false,
          employee_code: "EMP-002",
          subtitle: "Covers night shift handovers"
        }
      }

      assert_redirected_to admin_staff_members_path
      assert_not users(:two).reload.active?
      assert_equal "EMP-002", users(:two).reload.employee_code
      assert_equal "Covers night shift handovers", users(:two).reload.subtitle
    end
  end
end
