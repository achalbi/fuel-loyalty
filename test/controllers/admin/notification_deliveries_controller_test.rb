require "test_helper"

module Admin
  class NotificationDeliveriesControllerTest < ActionDispatch::IntegrationTest
    def with_stubbed_push_service(result)
      firebase_push_service_singleton = FirebasePushService.singleton_class
      original_new = firebase_push_service_singleton.instance_method(:new)
      fake_service = Object.new
      fake_service.define_singleton_method(:broadcast) do |title:, message:|
        result
      end

      firebase_push_service_singleton.define_method(:new) do |*|
        fake_service
      end

      yield
    ensure
      firebase_push_service_singleton.define_method(:new, original_new)
    end

    def with_admin_notification_token(value)
      original_value = ENV["ADMIN_NOTIFICATION_API_TOKEN"]
      ENV["ADMIN_NOTIFICATION_API_TOKEN"] = value
      yield
    ensure
      ENV["ADMIN_NOTIFICATION_API_TOKEN"] = original_value
    end

    test "admin can send a notification from the web UI" do
      sign_in users(:one)
      result = FirebasePushService::Result.new(
        requested: 3,
        sent: 3,
        failed: 0,
        invalidated: 0,
        batches: 1,
        errors: []
      )

      with_stubbed_push_service(result) do
        post admin_send_notifications_path, params: {
          notification: {
            title: "Fuel Offer",
            message: "Save more this week"
          }
        }
      end

      assert_redirected_to admin_notifications_path
    end

    test "bearer token can send a notification as json" do
      result = FirebasePushService::Result.new(
        requested: 2,
        sent: 2,
        failed: 0,
        invalidated: 0,
        batches: 1,
        errors: []
      )

      with_admin_notification_token("push-secret") do
        with_stubbed_push_service(result) do
          post admin_send_notifications_path,
               params: { title: "Fuel Offer", message: "Save more this week" },
               headers: { "Authorization" => "Bearer push-secret" },
               as: :json
        end
      end

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal 2, payload["sent"]
      assert_equal 0, payload["failed"]
    end

    test "json request returns validation error when title is missing" do
      with_admin_notification_token("push-secret") do
        post admin_send_notifications_path,
             params: { message: "Save more this week" },
             headers: { "Authorization" => "Bearer push-secret" },
             as: :json
      end

      assert_response :unprocessable_entity
      payload = JSON.parse(response.body)
      assert_match(/title/i, payload["error"])
    end
  end
end
