require "test_helper"

class AttendanceRosterBuilderTest < ActiveSupport::TestCase
  STARTS_AT = Time.zone.parse("2026-03-26 08:00")

  setup do
    # users(:two) is rostered onto day_shift from 2026-03-02 (fixtures).
    @rostered = users(:two)
  end

  def roster(shift_template: shift_templates(:day_shift))
    AttendanceRosterBuilder.call(shift_template: shift_template, starts_at: STARTS_AT)
  end

  def staff_member_ids(shift_template: shift_templates(:day_shift))
    roster(shift_template: shift_template).map { |item| item.fetch(:staff_member).id }
  end

  def create_staff(name:, username:, phone_number:, active: true)
    User.create!(
      name: name, username: username, phone_number: phone_number, role: :staff, active: active,
      password: "password123", password_confirmation: "password123"
    )
  end

  test "includes active staff who have not been assigned a shift yet" do
    unassigned = create_staff(name: "Unassigned Staff", username: "unassigned_staff", phone_number: "9000000033")

    assert_includes staff_member_ids, unassigned.id
  end

  test "includes staff rostered onto the requested template" do
    assert_includes staff_member_ids, @rostered.id
  end

  test "excludes staff rostered onto a different template" do
    assert_not_includes staff_member_ids(shift_template: shift_templates(:night_shift)), @rostered.id
  end

  test "excludes deactivated staff" do
    deactivated = create_staff(name: "Gone Staff", username: "gone_staff", phone_number: "9000000034", active: false)

    assert_not_includes staff_member_ids, deactivated.id
  end

  test "excludes admins" do
    assert_not_includes staff_member_ids, users(:one).id
  end

  test "returns each staff member exactly once, ordered by name" do
    create_staff(name: "Aaa Staff", username: "aaa_staff", phone_number: "9000000035")
    ids = staff_member_ids

    assert_equal ids.uniq, ids
    names = roster.map { |item| item.fetch(:staff_member).name }
    assert_equal names.sort, names
  end
end
