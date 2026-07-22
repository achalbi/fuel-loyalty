require "test_helper"

module Admin
  class NotificationDeliveriesControllerTest < ActionDispatch::IntegrationTest
    def with_admin_notification_token(value)
      original_value = ENV["ADMIN_NOTIFICATION_API_TOKEN"]
      ENV["ADMIN_NOTIFICATION_API_TOKEN"] = value
      yield
    ensure
      ENV["ADMIN_NOTIFICATION_API_TOKEN"] = original_value
    end

    test "admin can send a targeted notification from the web UI (logged)" do
      sign_in users(:one)
      # A linked, active push token so the send has a recipient to log.
      PushSubscription.register!(token: "web-tok-1", platform: "web", customer: customers(:one))

      assert_difference -> { NotificationMessage.count }, 1 do
        post admin_send_notifications_path, params: {
          notification: { title: "Fuel Offer", message: "Save more this week",
                          channels: ["push"], target_type: "all" },
        }
      end

      assert_redirected_to admin_notifications_path
      message = NotificationMessage.order(:id).last
      assert_equal "Fuel Offer", message.title
      assert_equal 1, message.notification_recipients.count # push not configured in test → skipped, still logged
      assert message.notification_recipients.first.skipped?
    end

    test "bearer token send returns the message id and per-channel delivery" do
      with_admin_notification_token("push-secret") do
        post admin_send_notifications_path,
             params: { title: "Fuel Offer", message: "Save more this week" },
             headers: { "Authorization" => "Bearer push-secret" },
             as: :json
      end

      assert_response :success
      payload = JSON.parse(response.body)
      assert payload["notification_message_id"].present?
      assert payload.key?("delivery")
    end

    test "json request returns validation error when title is missing" do
      with_admin_notification_token("push-secret") do
        post admin_send_notifications_path,
             params: { message: "Save more this week" },
             headers: { "Authorization" => "Bearer push-secret" },
             as: :json
      end

      assert_response :unprocessable_entity
      assert_match(/title/i, JSON.parse(response.body)["error"])
    end
  end
end
