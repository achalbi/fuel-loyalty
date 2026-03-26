require "test_helper"

module Admin
  class NotificationsControllerTest < ActionDispatch::IntegrationTest
    test "admin can view notifications management" do
      sign_in users(:one)
      schedule = NotificationSchedule.create!(
        title: "Morning Offer",
        message: "Open the app today",
        frequency: "daily",
        scheduled_time: "09:00",
        active: false
      )

      get admin_notifications_path

      assert_response :success
      assert_select "h1", "Notifications"
      assert_select "form[action='#{admin_send_notifications_path}']", 1
      assert_select "form[action='#{admin_schedules_path}']", 1
      assert_select "form[action='#{admin_run_schedules_path}']", 1
      assert_select "form[action='#{send_now_admin_schedule_path(schedule)}']", 1
      assert_select "form[action='#{send_now_admin_schedule_path(schedule)}'] button", text: /Send Now/
    end
  end
end
