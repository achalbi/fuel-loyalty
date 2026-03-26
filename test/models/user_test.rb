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

  test "does not allow duplicate mobile numbers" do
    user = User.new(
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
    user = User.new(username: "admin", email: "admin@example.com")
    original_has_attribute = user.method(:has_attribute?)
    user.define_singleton_method(:has_attribute?) { |_attribute_name| false }

    begin
      assert_equal "admin", user.login
      assert_nil user.display_phone_number
    ensure
      user.define_singleton_method(:has_attribute?) { |attribute_name| original_has_attribute.call(attribute_name) }
    end
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
