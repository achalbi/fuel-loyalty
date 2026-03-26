require "test_helper"

module Admin
  class SchedulesControllerTest < ActionDispatch::IntegrationTest
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

    test "admin can create a schedule" do
      sign_in users(:one)

      assert_difference -> { NotificationSchedule.count }, 1 do
        post admin_schedules_path, params: {
          notification_schedule: {
            title: "Daily Reminder",
            message: "Come back soon",
            frequency: "daily",
            scheduled_time: "09:00",
            active: "1"
          }
        }
      end

      assert_redirected_to admin_notifications_path
      assert_equal "daily", NotificationSchedule.last.frequency
    end

    test "admin can run the scheduler manually" do
      sign_in users(:one)
      schedule = NotificationSchedule.create!(
        title: "Daily Reminder",
        message: "Come back soon",
        frequency: "daily",
        scheduled_time: "09:00",
        active: true
      )
      result = FirebasePushService::Result.new(
        requested: 1,
        sent: 1,
        failed: 0,
        invalidated: 0,
        batches: 1,
        errors: []
      )

      travel_to Time.zone.local(2026, 3, 25, 10, 0, 0) do
        with_stubbed_push_service(result) do
          post admin_run_schedules_path
        end
      end

      assert_redirected_to admin_notifications_path
      follow_redirect!
      assert_match(/1 schedules sent, 0 failed/i, response.body)
      assert schedule.reload.last_sent_at.present?
    end

    test "scheduler run explains when no schedules are due yet" do
      sign_in users(:one)
      schedule = NotificationSchedule.create!(
        title: "Later Reminder",
        message: "Come back tonight",
        frequency: "daily",
        scheduled_time: "23:00",
        active: true
      )

      travel_to Time.zone.local(2026, 3, 25, 10, 0, 0) do
        post admin_run_schedules_path
      end

      assert_redirected_to admin_notifications_path
      follow_redirect!
      assert_match(/No schedules are due right now/i, response.body)
      refute schedule.reload.last_sent_at.present?
    end

    test "bearer token can run the scheduler as json" do
      NotificationSchedule.create!(
        title: "Daily Reminder",
        message: "Come back soon",
        frequency: "daily",
        scheduled_time: "09:00",
        active: true
      )
      result = FirebasePushService::Result.new(
        requested: 1,
        sent: 1,
        failed: 0,
        invalidated: 0,
        batches: 1,
        errors: []
      )

      travel_to Time.zone.local(2026, 3, 25, 10, 0, 0) do
        with_admin_notification_token("push-secret") do
          with_stubbed_push_service(result) do
            post admin_run_schedules_path,
                 headers: { "Authorization" => "Bearer push-secret" },
                 as: :json
          end
        end
      end

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal 1, payload["sent"]
      assert_equal 0, payload["failed"]
      assert_equal true, payload["acquired"]
      assert_equal false, payload["skipped"]
    end

    test "scheduler endpoint reports when another run is already in progress" do
      sign_in users(:one)
      SchedulerLease.create!(
        key: NotificationScheduleRunner::LEASE_KEY,
        running: true,
        lease_token: "existing-token",
        started_at: Time.current,
        last_heartbeat_at: Time.current
      )

      post admin_run_schedules_path

      assert_redirected_to admin_notifications_path
      follow_redirect!
      assert_match(/already in progress/i, response.body)
    end
  end
end
