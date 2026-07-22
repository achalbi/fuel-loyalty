require "test_helper"

module Api
  module V1
    module Admin
      class SchedulesControllerTest < ActionDispatch::IntegrationTest
        setup { @admin = users(:one) }

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        # Mirror the web test's Broadcaster stub so send_now doesn't actually dispatch.
        def with_stubbed_broadcaster(summary)
          singleton = Notifications::Broadcaster.singleton_class
          original = singleton.instance_method(:call)
          Notifications::Broadcaster.define_singleton_method(:call) do |**|
            Notifications::Broadcaster::Result.new(message: nil, summary: summary)
          end
          yield
        ensure
          singleton.define_method(:call, original)
        end

        test "create accepts channels + a customer-type audience and the serializer returns them" do
          post api_v1_admin_schedules_path, params: {
            notification_schedule: {
              title: "Segment", message: "Credit only", frequency: "daily",
              scheduled_time: "09:00", active: true,
              channels: %w[push whatsapp], target_type: "customer_type", target_customer_type: "credit"
            }
          }, headers: auth_headers(@admin)

          assert_response :created
          body = response.parsed_body
          assert_equal %w[push whatsapp], body["channels"]
          assert_equal "customer_type", body["target_type"]
          assert_equal "credit", body["target_customer_type"]
          assert_nil body["campaign_id"]
        end

        test "create defaults channels to push and audience to all" do
          post api_v1_admin_schedules_path, params: {
            notification_schedule: {
              title: "Basic", message: "Everyone", frequency: "daily", scheduled_time: "09:00", active: true
            }
          }, headers: auth_headers(@admin)

          assert_response :created
          body = response.parsed_body
          assert_equal %w[push], body["channels"]
          assert_equal "all", body["target_type"]
        end

        test "create rejects a customer_type audience without a valid customer type" do
          post api_v1_admin_schedules_path, params: {
            notification_schedule: {
              title: "Bad", message: "m", frequency: "daily", scheduled_time: "09:00",
              target_type: "customer_type"
            }
          }, headers: auth_headers(@admin)

          assert_response :unprocessable_entity
        end

        test "send_now returns the per-channel delivery summary" do
          schedule = NotificationSchedule.create!(
            title: "Now", message: "m", frequency: "daily", scheduled_time: "09:00",
            channels: %w[push], active: true
          )

          with_stubbed_broadcaster({ "push" => { "sent" => 4 } }) do
            post send_now_api_v1_admin_schedule_path(schedule), headers: auth_headers(@admin)
          end

          assert_response :ok
          body = response.parsed_body
          assert_equal 4, body.dig("delivery", "push", "sent")
          assert schedule.reload.last_sent_at.present?
        end

        test "non-admin cannot create a schedule" do
          post api_v1_admin_schedules_path, params: {
            notification_schedule: { title: "x", message: "m", frequency: "daily", scheduled_time: "09:00" }
          }, headers: auth_headers(users(:two))

          assert_response :forbidden
        end
      end
    end
  end
end
