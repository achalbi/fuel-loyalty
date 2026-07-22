require "test_helper"

module Api
  module V1
    module Admin
      class NotificationsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
          customers(:one).update!(customer_type: :otp)
          PushSubscription.register!(token: "api-tok-1", platform: "android", customer: customers(:one))
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "targeted send logs a message + recipients and returns delivery counts" do
          assert_difference -> { NotificationMessage.count }, 1 do
            post api_v1_admin_notifications_send_path, params: {
              notification: { title: "Offer", message: "20% off", category: "offer",
                              target_type: "customer_type", target_customer_type: "otp", channels: ["push"] },
            }, headers: auth_headers(@admin)
          end
          assert_response :ok
          body = response.parsed_body
          assert body["notification_message_id"].present?
          message = NotificationMessage.find(body["notification_message_id"])
          assert_equal "offer", message.category
          assert_equal 1, message.notification_recipients.count
        end

        test "history + recipients endpoints return the log" do
          post api_v1_admin_notifications_send_path, params: {
            notification: { title: "Hi", message: "hello", target_type: "all", channels: ["push"] },
          }, headers: auth_headers(@admin)
          id = response.parsed_body["notification_message_id"]

          get api_v1_admin_notifications_path, headers: auth_headers(@admin)
          assert_response :ok
          assert_includes response.parsed_body["notifications"].map { |n| n["id"] }, id

          get "/api/v1/admin/notifications/#{id}/recipients", headers: auth_headers(@admin)
          assert_response :ok
          assert response.parsed_body["recipients"].is_a?(Array)
        end

        test "staff cannot send or read notifications" do
          post api_v1_admin_notifications_send_path, params: { notification: { title: "x", message: "y" } },
            headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
