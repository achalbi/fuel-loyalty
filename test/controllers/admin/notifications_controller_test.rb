require "test_helper"

module Admin
  class NotificationsControllerTest < ActionDispatch::IntegrationTest
    test "admin can view notifications management" do
      sign_in users(:one)

      get admin_notifications_path

      assert_response :success
      assert_select "h1", "Notifications"
      assert_select "form[action='#{admin_send_notifications_path}']", 1
      assert_select "form[action='#{admin_schedules_path}']", 1
      assert_select "form[action='#{admin_run_schedules_path}']", 1
    end
  end
end
