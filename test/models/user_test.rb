require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "finds a user by username for authentication" do
    user = User.find_for_database_authentication(login: "admin")

    assert_equal users(:one), user
  end

  test "finds a user by email for authentication" do
    user = User.find_for_database_authentication(login: "staff@example.com")

    assert_equal users(:two), user
  end

  test "finds a user by phone number for authentication" do
    user = User.find_for_database_authentication(login: "9000000022")

    assert_equal users(:two), user
  end

  test "finds a user by a username containing special characters" do
    user = User.create!(
      name: "Special Username User",
      username: "achal.rvce+staff@gmail.com",
      phone_number: "9000000088",
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert_equal user, User.find_for_database_authentication(login: "achal.rvce+staff@gmail.com")
  end

  test "does not find a soft deleted user for authentication" do
    users(:two).update!(active: false, deleted_at: Time.current)

    assert_nil User.find_for_database_authentication(login: "staff")
    assert_nil User.find_for_database_authentication(login: "staff@example.com")
    assert_nil User.find_for_database_authentication(login: "9000000022")
  end

  test "falls back to username and email authentication when phone number attribute is unavailable" do
    original_availability = User.method(:phone_number_attribute_available?)
    User.define_singleton_method(:phone_number_attribute_available?) { false }

    begin
      assert_equal users(:one), User.find_for_database_authentication(login: "admin")
      assert_equal users(:two), User.find_for_database_authentication(login: "staff@example.com")
      assert_nil User.find_for_database_authentication(login: "9000000022")
    ensure
      User.define_singleton_method(:phone_number_attribute_available?) { original_availability.call }
    end
  end

  test "normalizes phone number and syncs internal email" do
    user = User.create!(
      name: "Staff Three",
      username: "staff_three",
      phone_number: "90000 00033",
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert_equal "9000000033", user.phone_number
    assert_equal "user-9000000033@users.fuel-loyalty.local", user.email
  end

  test "preserves an explicit email address when provided" do
    user = User.create!(
      name: "Staff With Email",
      username: "staff_with_email",
      phone_number: "9000000044",
      email: "staff_with_email@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert_equal "staff_with_email@example.com", user.email
    assert_equal "staff_with_email@example.com", user.explicit_email
  end

  test "requires a 10 digit mobile number" do
    user = User.new(
      name: "Staff Four",
      username: "staff_four",
      phone_number: "12345",
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert_not user.valid?
    assert_includes user.errors[:phone_number], User::PHONE_NUMBER_ERROR_MESSAGE
  end

  test "requires a valid email format when provided" do
    user = User.new(
      name: "Staff Invalid Email",
      username: "staff_invalid_email",
      phone_number: "9000000055",
      email: "not-an-email",
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "allows special characters in usernames" do
    user = User.new(
      name: "Staff Special Username",
      username: "staff.user+1@example.com",
      phone_number: "9000000077",
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert user.valid?
  end

  test "does not add a duplicate email error when optional email is left blank" do
    user = User.new(
      name: "Staff Blank Email",
      username: "staff_blank_email",
      phone_number: "",
      email: "",
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert_not user.valid?
    assert_not_includes user.errors[:email], "has already been taken"
    assert_includes user.errors[:phone_number], "can't be blank"
  end

  test "duplicate phone with blank visible email only reports the phone conflict" do
    existing_user = User.create!(
      name: "Existing Internal Email User",
      username: "existing_internal_email_user",
      phone_number: "9000000099",
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    user = User.new(
      name: "Staff Duplicate Internal Email",
      username: "staff_duplicate_internal_email",
      phone_number: existing_user.phone_number,
      email: "",
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert_not user.valid?
    assert_includes user.errors[:phone_number], "has already been taken"
    assert_not_includes user.errors[:email], "has already been taken"
  end

  test "does not allow duplicate mobile numbers" do
    user = User.new(
      name: "Staff Five",
      username: "staff_five",
      phone_number: users(:two).phone_number,
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert_not user.valid?
    assert_includes user.errors[:phone_number], "has already been taken"
  end

  test "does not allow duplicate explicit email addresses" do
    user = User.new(
      name: "Staff Six",
      username: "staff_six",
      phone_number: "9000000066",
      email: users(:two).email,
      password: "password123",
      password_confirmation: "password123",
      role: :staff
    )

    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "does not allow demoting the last admin" do
    user = users(:one)

    assert_not user.update(role: :staff)
    assert_includes user.errors[:role], "must leave at least one admin user"
  end

  test "login and display phone number do not raise when phone number attribute is unavailable" do
    user = User.new(name: "Admin", username: "admin", email: "admin@example.com")
    original_has_attribute = user.method(:has_attribute?)
    user.define_singleton_method(:has_attribute?) { |_attribute_name| false }

    begin
      assert_equal "admin", user.login
      assert_nil user.display_phone_number
    ensure
      user.define_singleton_method(:has_attribute?) { |attribute_name| original_has_attribute.call(attribute_name) }
    end
  end

  test "display name prefers the stored name" do
    user = User.new(name: "Rahul Verma", username: "rahul_verma")

    assert_equal "Rahul Verma", user.display_name
    assert_equal "R", user.avatar_initial
  end

  test "inactive and soft deleted users are not active for authentication" do
    inactive_user = users(:two)
    inactive_user.update!(active: false)
    refute inactive_user.active_for_authentication?

    inactive_user.update!(deleted_at: Time.current)
    refute inactive_user.active_for_authentication?
  end

  test "soft delete requires the staff member to be inactive" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      users(:two).soft_delete!
    end

    assert_includes error.record.errors[:base], "User is in active state. Deactivate before soft deleting"
  end

  test "soft delete keeps history references in place" do
    user = users(:two)
    transaction = transactions(:one)
    attendance_entry = attendance_entries(:day_run_staff)

    user.update!(active: false)
    user.soft_delete!

    assert user.soft_deleted?
    assert_equal user.id, transaction.reload.user_id
    assert_equal user.id, attendance_entry.reload.scheduled_user_id
  end

  test "current shift template follows the assigned shift" do
    travel_to Time.zone.parse("2026-03-26 08:00") do
      assert_equal shift_templates(:day_shift), users(:two).current_shift_template
      assert_equal shift_cycles(:day_night_cycle), users(:two).current_shift_cycle
    end

    travel_to Time.zone.parse("2026-03-26 20:00") do
      assert_equal shift_templates(:day_shift), users(:two).current_shift_template
      assert_equal shift_cycles(:day_night_cycle), users(:two).current_shift_cycle
    end
  end
end
