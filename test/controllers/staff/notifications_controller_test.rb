require "test_helper"

module Staff
  class NotificationsControllerTest < ActionDispatch::IntegrationTest
    test "staff can view device notifications page" do
      sign_in users(:two)

      with_firebase_web_push_env do
        get staff_notifications_path
      end

      assert_response :success
      assert_select "h1", text: "Notifications"
      assert_select "a.nav-link.active[href='#{staff_notifications_path}']", text: /Notifications/
      assert_select "#topbar a.btn-icon[href='#{new_staff_transaction_path}'][aria-label='New Transaction']", 1
      assert_select ".user-menu [data-sidebar-mode-switch][aria-label='Show side navbar as icon-only bar']", 1
      assert_select ".page-actions a.btn[href='#{new_staff_transaction_path}']", 0
      assert_select "[data-push-opt-in-panel][data-push-source='staff_notifications']", 1
      assert_select "[data-push-opt-in-panel] [data-push-button] span", text: "Enable Notifications"
      assert_select "[data-push-opt-in-panel] [data-push-disable-button] span", text: "Disable Notifications"
      assert_select ".badge", text: "Recommended", minimum: 1
    end

    test "staff notifications page shows fallback when web push is unavailable" do
      sign_in users(:two)

      get staff_notifications_path

      assert_response :success
      assert_select "#topbar a.btn-icon[href='#{new_staff_transaction_path}'][aria-label='New Transaction']", 1
      assert_select ".user-menu [data-sidebar-mode-switch][aria-label='Show side navbar as icon-only bar']", 1
      assert_select ".page-actions a.btn[href='#{new_staff_transaction_path}']", 0
      assert_select "[data-push-opt-in-panel]", 0
      assert_select "h2", text: "Push Notifications Are Unavailable"
      assert_match(/Ask an admin to finish the notification setup/i, response.body)
    end
  end
end
