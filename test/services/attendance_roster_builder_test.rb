require "test_helper"

class AttendanceRosterBuilderTest < ActiveSupport::TestCase
  test "includes active staff who have not been assigned a shift yet" do
    unassigned_staff = User.create!(
      name: "Unassigned Staff",
      username: "unassigned_staff",
      phone_number: "9000000033",
      role: :staff,
      password: "password123",
      password_confirmation: "password123",
    )

    roster = AttendanceRosterBuilder.call(
      shift_template: shift_templates(:day_shift),
      starts_at: Time.zone.parse("2026-03-26 08:00"),
    )

    assert_includes roster.map { |item| item.fetch(:staff_member).id }, unassigned_staff.id
  end
end
