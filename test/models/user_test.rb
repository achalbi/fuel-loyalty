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
end
