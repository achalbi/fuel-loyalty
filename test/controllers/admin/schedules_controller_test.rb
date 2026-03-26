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
        with_stubbed_push_service(result) do
          post admin_run_schedules_path
        end
      end

      assert_redirected_to admin_notifications_path
      assert NotificationSchedule.last.last_sent_at.present?
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
