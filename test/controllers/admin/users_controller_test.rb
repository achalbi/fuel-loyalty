require "test_helper"

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    test "admin can view users index" do
      sign_in users(:one)

      get admin_users_path

      assert_response :success
      assert_select "h1", text: "Users"
      assert_select "button.customer-details-quick-action.admin-users-create-action[data-bs-toggle='modal'][data-bs-target='#addUserModal'][aria-label='Add User']", text: "+"
      assert_select "#addUserModal"
      assert_select ".admin-users-list"
      assert_select ".admin-user-item", minimum: 2
      assert_select ".admin-user-item__name", text: /Admin/
      assert_select ".admin-user-item__name", text: /Staff/
      assert_select ".admin-user-item__phone", text: /\+91 9000000011/
      assert_select ".admin-user-item__email", text: /admin@example.com/
      assert_select "button.admin-user-item__edit[data-bs-target='#editUserModal-#{users(:one).id}'][aria-label='Edit Admin']"
      assert_select "#editUserModal-#{users(:one).id}"
    end

    test "admin create failure re-renders index modal with errors" do
      sign_in users(:one)

      assert_no_difference("User.count") do
        post admin_users_path, params: {
          user: {
            username: "",
            phone_number: "123",
            email: "not-an-email",
            role: "staff",
            password: "short",
            password_confirmation: "mismatch"
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "#addUserModal[data-auto-open-modal='true']"
      assert_select "#addUserModal .alert.alert-danger"
    end

    test "admin can create a staff user" do
      sign_in users(:one)

      assert_difference("User.count", 1) do
        post admin_users_path, params: {
          user: {
            username: "staff_two",
            phone_number: "91111 22222",
            email: "staff_two@example.com",
            role: "staff",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end

      assert_redirected_to admin_users_path
      created_user = User.order(:created_at).last
      assert_equal "staff", created_user.role
      assert_equal "staff_two", created_user.username
      assert_equal "9111122222", created_user.phone_number
      assert_equal "staff_two@example.com", created_user.email
    end

    test "admin can update a user role to admin" do
      sign_in users(:one)

      patch admin_user_path(users(:two)), params: {
        user: {
          username: users(:two).username,
          phone_number: users(:two).phone_number,
          email: "staff-promoted@example.com",
          role: "admin",
          password: "",
          password_confirmation: ""
        }
      }

      assert_redirected_to admin_users_path
      assert_equal "admin", users(:two).reload.role
      assert_equal "staff-promoted@example.com", users(:two).reload.email
    end

    test "admin update failure re-renders index modal with errors" do
      sign_in users(:one)

      patch admin_user_path(users(:one)), params: {
        user: {
          username: "",
          phone_number: "123",
          email: "not-an-email",
          role: "staff",
          password: "",
          password_confirmation: ""
        }
      }

      assert_response :unprocessable_entity
      assert_select "#editUserModal-#{users(:one).id}[data-auto-open-modal='true']"
      assert_select "#editUserModal-#{users(:one).id} .alert.alert-danger"
      assert_equal "admin", users(:one).reload.role
    end

    test "admin cannot demote the last admin" do
      sign_in users(:one)

      patch admin_user_path(users(:one)), params: {
        user: {
          username: users(:one).username,
          phone_number: users(:one).phone_number,
          email: users(:one).email,
          role: "staff",
          password: "",
          password_confirmation: ""
      }
      }

      assert_response :unprocessable_entity
      assert_select "#editUserModal-#{users(:one).id}[data-auto-open-modal='true']"
      assert_select "#editUserModal-#{users(:one).id} .alert.alert-danger", text: /at least one admin user/
      assert_equal "admin", users(:one).reload.role
    end
  end
end
