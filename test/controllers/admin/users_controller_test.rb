require "test_helper"

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    test "admin can view users index" do
      sign_in users(:one)

      get admin_users_path

      assert_response :success
      assert_select "h1", text: "Users"
      assert_select "button.admin-users-create-action[data-bs-toggle='modal'][data-bs-target='#addUserModal'][aria-label='Add User']", text: /\+ Add User/
      assert_select "#addUserModal"
      assert_select ".admin-users-list"
      assert_select ".admin-user-item", minimum: 2
      assert_select ".admin-user-item__name", text: /Admin/
      assert_select ".admin-user-item__name", text: /Staff/
      assert_select ".admin-user-item__phone", text: /\+91 9000000011/
      assert_select ".admin-user-item__email", text: /admin@example.com/
      assert_select "a.admin-user-item__view[href='#{admin_user_path(users(:one))}'][aria-label='View Admin']"
      assert_select "button.admin-user-item__edit[data-bs-target='#editUserModal-#{users(:one).id}'][aria-label='Edit Admin']"
      assert_select "#editUserModal-#{users(:one).id}"
    end

    test "admin can view the new user page with a name field" do
      sign_in users(:one)

      get new_admin_user_path

      assert_response :success
      assert_select "h1", text: "Add User"
      assert_select "label", text: "Name"
      assert_select "input[name='user[name]'][required]"
      assert_select "label", text: "Username (Login)"
      assert_select "label", text: "Access Status"
      assert_select "select[name='user[active]']"
    end

    test "admin can view the edit user page with a name field" do
      sign_in users(:one)

      get edit_admin_user_path(users(:two))

      assert_response :success
      assert_select "h1", text: "Edit User"
      assert_select "label", text: "Name"
      assert_select "input[name='user[name]'][value='#{users(:two).name}']"
      assert_select "input[name='user[username]'][value='#{users(:two).username}']"
      assert_select "label", text: "Access Status"
      assert_select "select[name='user[active]'] option[selected]", text: "Active"
    end

    test "admin can view the user show page" do
      sign_in users(:one)

      get admin_user_path(users(:two))

      assert_response :success
      assert_select "h1", text: users(:two).name
      assert_select ".admin-user-detail__label", text: "Name"
      assert_select ".admin-user-detail__value", text: users(:two).name
      assert_select ".admin-user-detail__label", text: "Username"
      assert_select ".admin-user-detail__value", text: users(:two).username
      assert_select ".admin-user-detail__label", text: "Status"
      assert_select ".admin-user-detail__value", text: "Active"
      assert_includes response.body, %(data-confirm-modal="true")
      assert_includes response.body, %(data-confirm-message="Attempt soft delete for #{users(:two).display_name}? Historical records will be kept. Active users must be deactivated first.")
    end

    test "admin create failure re-renders index modal with errors" do
      sign_in users(:one)

      assert_no_difference("User.count") do
        post admin_users_path, params: {
          user: {
            name: "",
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
      assert_select "#addUserModal[data-auto-open-modal='true'][data-reset-on-close='reload'][data-reset-on-close-url='#{admin_users_path}']"
      assert_select "#addUserModal .alert.alert-danger"
    end

    test "admin create failure with blank email does not show duplicate email error" do
      sign_in users(:one)

      assert_no_difference("User.count") do
        post admin_users_path, params: {
          user: {
            name: "New Staff",
            username: "new_staff",
            phone_number: "",
            email: "",
            role: "staff",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "#addUserModal .alert.alert-danger"
      assert_no_match(/Email has already been taken/, response.body)
    end

    test "admin update failure with blank email and duplicate phone only shows phone error" do
      sign_in users(:one)
      users(:one).update!(email: "")

      patch admin_user_path(users(:two)), params: {
        user: {
          name: users(:two).name,
          username: users(:two).username,
          phone_number: users(:one).phone_number,
          email: "",
          active: true,
          role: "staff",
          password: "",
          password_confirmation: ""
        }
      }

      assert_response :unprocessable_entity
      assert_select "#editUserModal-#{users(:two).id}[data-auto-open-modal='true'] .alert.alert-danger", text: /Phone number has already been taken/
      assert_no_match(/Email has already been taken/, response.body)
    end

    test "admin can create a staff user" do
      sign_in users(:one)

      assert_difference("User.count", 1) do
        post admin_users_path, params: {
          user: {
            name: "Staff Two",
            username: "staff.two+login@example.com",
            phone_number: "91111 22222",
            email: "staff_two@example.com",
            active: false,
            role: "staff",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end

      assert_redirected_to admin_users_path
      created_user = User.order(:created_at).last
      assert_equal "Staff Two", created_user.name
      assert_equal "staff", created_user.role
      assert_not created_user.active?
      assert_equal "staff.two+login@example.com", created_user.username
      assert_equal "9111122222", created_user.phone_number
      assert_equal "staff_two@example.com", created_user.email
    end

    test "admin can update a user role to admin" do
      sign_in users(:one)

      patch admin_user_path(users(:two)), params: {
        user: {
          name: "Station Staff",
          username: users(:two).username,
          phone_number: users(:two).phone_number,
          email: "staff-promoted@example.com",
          active: false,
          role: "admin",
          password: "",
          password_confirmation: ""
        }
      }

      assert_redirected_to admin_users_path
      assert_equal "Station Staff", users(:two).reload.name
      assert_equal "admin", users(:two).reload.role
      assert_not users(:two).reload.active?
      assert_equal "staff-promoted@example.com", users(:two).reload.email
    end

    test "admin update failure re-renders index modal with errors" do
      sign_in users(:one)

      patch admin_user_path(users(:one)), params: {
        user: {
          name: "",
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
          name: users(:one).name,
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
