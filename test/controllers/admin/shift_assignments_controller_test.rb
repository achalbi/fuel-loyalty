require "test_helper"

module Admin
  class ShiftAssignmentsControllerTest < ActionDispatch::IntegrationTest
    test "admin can assign a shift to staff and close the previous one" do
      sign_in users(:one)
      travel_to Time.zone.parse("2026-04-01 08:00") do
        post admin_staff_member_shift_assignments_path(users(:two)), params: {
          shift_assignment: {
            shift_template_id: shift_templates(:night_shift).id,
            notes: "Emergency rotation"
          }
        }
      end

      assert_redirected_to admin_staff_members_path

      latest_assignment = users(:two).shift_assignments.order(:created_at).last
      previous_assignment = shift_assignments(:staff_day_shift).reload

      assert_equal shift_templates(:night_shift), latest_assignment.shift_template
      assert_equal shift_cycles(:week_long_cycle), latest_assignment.shift_cycle
      assert_equal Time.zone.parse("2026-04-01 08:00"), latest_assignment.effective_from
      assert_equal Time.zone.parse("2026-04-01 07:59:59"), previous_assignment.effective_to
    end

    test "admin sees a validation error when no shift is selected" do
      sign_in users(:one)

      post admin_staff_member_shift_assignments_path(users(:two)), params: {
        shift_assignment: {
          shift_template_id: "",
          notes: "Missing shift"
        }
      }

      assert_response :unprocessable_entity
      assert_select ".alert.alert-danger", text: /Shift template must be selected/i
      assert_select "select[name='shift_assignment\\[shift_template_id\\]']", 1
    end
  end
end
