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
end
