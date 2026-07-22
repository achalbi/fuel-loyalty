require "test_helper"

module Admin
  class SchedulesControllerTest < ActionDispatch::IntegrationTest
    # send_now/run route through Notifications::Broadcaster now; stub its class
    # method to return a known per-channel summary, optionally recording the
    # kwargs each call received into [calls].
    def with_stubbed_broadcaster(summary, calls = nil)
      singleton = Notifications::Broadcaster.singleton_class
      original = singleton.instance_method(:call)
      Notifications::Broadcaster.define_singleton_method(:call) do |**kwargs|
        calls&.push(kwargs)
        Notifications::Broadcaster::Result.new(message: nil, summary: summary)
      end
      yield
    ensure
      singleton.define_method(:call, original)
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
      travel_to Time.zone.local(2026, 3, 25, 10, 0, 0) do
        with_stubbed_broadcaster({ "push" => { "sent" => 1 } }) do
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

    test "admin can create a schedule with channels and a customer-type audience" do
      sign_in users(:one)

      post admin_schedules_path, params: {
        notification_schedule: {
          title: "Segment Blast",
          message: "Credit customers only",
          frequency: "daily",
          scheduled_time: "09:00",
          active: "1",
          channels: %w[push whatsapp],
          target_type: "customer_type",
          target_customer_type: "credit"
        }
      }, as: :json

      assert_response :created
      payload = JSON.parse(response.body)
      assert_equal %w[push whatsapp], payload["channels"]
      assert_equal "customer_type", payload["target_type"]
      assert_equal "credit", payload["target_customer_type"]

      schedule = NotificationSchedule.order(:created_at).last
      assert_equal "push,whatsapp", schedule.channels
    end

    test "send_now forwards the schedule's channels and audience to the broadcaster" do
      sign_in users(:one)
      schedule = NotificationSchedule.create!(
        title: "Segment Send",
        message: "Credit customers only",
        frequency: "daily",
        scheduled_time: "09:00",
        channels: %w[push whatsapp],
        target_type: "customer_type",
        target_customer_type: "credit",
        active: true
      )

      calls = []
      with_stubbed_broadcaster({ "push" => { "sent" => 1 } }, calls) do
        post send_now_admin_schedule_path(schedule), as: :json
      end

      assert_response :success
      call = calls.first
      assert_equal "push,whatsapp", call[:channels]
      assert_equal "customer_type", call[:target_type]
      assert_equal "credit", call[:target_customer_type]
      assert_equal :scheduled, call[:category]
    end

    test "send_now does not stamp last_sent_at when nothing was delivered" do
      sign_in users(:one)
      schedule = NotificationSchedule.create!(
        title: "Unreachable",
        message: "No one opted in",
        frequency: "daily",
        scheduled_time: "09:00",
        active: true
      )

      with_stubbed_broadcaster({ "push" => { "skipped" => 3 } }) do
        post send_now_admin_schedule_path(schedule)
      end

      assert_nil schedule.reload.last_sent_at
    end

    test "bearer token can run the scheduler as json" do
      NotificationSchedule.create!(
        title: "Daily Reminder",
        message: "Come back soon",
        frequency: "daily",
        scheduled_time: "09:00",
        active: true
      )
      travel_to Time.zone.local(2026, 3, 25, 10, 0, 0) do
        with_admin_notification_token("push-secret") do
          with_stubbed_broadcaster({ "push" => { "sent" => 1 } }) do
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

    test "admin can send a paused saved schedule immediately" do
      sign_in users(:one)
      schedule = NotificationSchedule.create!(
        title: "Paused Reminder",
        message: "Still send this now",
        frequency: "daily",
        scheduled_time: "18:00",
        active: false
      )
      travel_to Time.zone.local(2026, 3, 25, 10, 0, 0) do
        with_stubbed_broadcaster({ "push" => { "sent" => 2 } }) do
          post send_now_admin_schedule_path(schedule)
        end
      end

      assert_redirected_to admin_notifications_path
      follow_redirect!
      assert_match(/Paused Reminder/i, response.body)
      assert_match(/2 delivered, 0 skipped, 0 failed\./i, response.body)
      assert schedule.reload.last_sent_at.present?
      refute schedule.active?
    end

    test "bearer token can send a saved schedule immediately as json" do
      schedule = NotificationSchedule.create!(
        title: "Immediate Reminder",
        message: "Send this now",
        frequency: "weekly",
        scheduled_time: "09:00",
        day_of_week: 1,
        active: true
      )
      travel_to Time.zone.local(2026, 3, 25, 10, 0, 0) do
        with_admin_notification_token("push-secret") do
          with_stubbed_broadcaster({ "push" => { "sent" => 1 } }) do
            post send_now_admin_schedule_path(schedule),
                 headers: { "Authorization" => "Bearer push-secret" },
                 as: :json
          end
        end
      end

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal schedule.id, payload.dig("schedule", "id")
      assert_equal 1, payload.dig("delivery", "push", "sent")
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
