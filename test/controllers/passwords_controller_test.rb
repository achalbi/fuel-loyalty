require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "admin can open change password page" do
    sign_in users(:one)

    get edit_password_path

    assert_response :success
    assert_select "h1", text: "Change Password"
    assert_select "form[action='#{password_path}']"
  end

  test "staff can open change password page" do
    sign_in users(:two)

    get edit_password_path

    assert_response :success
    assert_select "h1", text: "Change Password"
  end

  test "user can change password with current password" do
    sign_in users(:two)

    patch password_path, params: {
      user: {
        current_password: "password123",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to new_staff_transaction_path
    assert_equal true, users(:two).reload.valid_password?("newpassword123")
  end

  test "user sees errors when current password is invalid" do
    sign_in users(:one)

    patch password_path, params: {
      user: {
        current_password: "wrong-password",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".alert.alert-danger"
  end
end
