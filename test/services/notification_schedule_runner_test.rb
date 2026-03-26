require "test_helper"

class NotificationScheduleRunnerTest < ActiveSupport::TestCase
  FakePushService = Struct.new(:calls) do
    def broadcast(title:, message:)
      calls << { title:, message: }
      FirebasePushService::Result.new(
        requested: 1,
        sent: 1,
        failed: 0,
        invalidated: 0,
        batches: 1,
        errors: []
      )
    end
  end

  test "is_due? returns true only after the daily scheduled time" do
    schedule = NotificationSchedule.new(
      title: "Daily Check-in",
      message: "Good morning",
      frequency: "daily",
      scheduled_time: "09:30",
      active: true
    )

    travel_to Time.zone.local(2026, 3, 25, 9, 0, 0) do
      refute NotificationScheduleRunner.is_due?(schedule, Time.current)
    end

    travel_to Time.zone.local(2026, 3, 25, 10, 0, 0) do
      assert NotificationScheduleRunner.is_due?(schedule, Time.current)
    end
  end

  test "scheduled times use the application time zone" do
    schedule = NotificationSchedule.new(
      title: "Daily Check-in",
      message: "Good morning",
      frequency: "daily",
      scheduled_time: "09:30",
      active: true
    )

    scheduled_time = schedule.scheduled_at_on(Date.new(2026, 3, 25))

    assert_equal "Asia/Kolkata", Time.zone.tzinfo.identifier
    assert_equal 19_800, scheduled_time.utc_offset
    assert_equal 9, scheduled_time.hour
    assert_equal 30, scheduled_time.min
  end

  test "is_due? respects weekly and monthly cadence fields" do
    travel_to Time.zone.local(2026, 3, 25, 11, 0, 0) do
      weekly_schedule = NotificationSchedule.new(
        title: "Weekly Offer",
        message: "Wednesday update",
        frequency: "weekly",
        scheduled_time: "10:30",
        day_of_week: Date.current.wday,
        active: true
      )
      monthly_schedule = NotificationSchedule.new(
        title: "Monthly Offer",
        message: "Month-end update",
        frequency: "monthly",
        scheduled_time: "10:30",
        day_of_month: Date.current.day,
        active: true
      )

      assert NotificationScheduleRunner.is_due?(weekly_schedule, Time.current)
      assert NotificationScheduleRunner.is_due?(monthly_schedule, Time.current)
    end
  end

  test "run sends due schedules and disables one-time schedules after success" do
    push_service = FakePushService.new([])
    schedule = NotificationSchedule.create!(
      title: "One Time Alert",
      message: "Today only",
      frequency: "once",
      scheduled_time: "09:00",
      scheduled_date: Date.new(2026, 3, 25),
      active: true
    )

    travel_to Time.zone.local(2026, 3, 25, 10, 15, 0) do
      result = NotificationScheduleRunner.new(push_service: push_service).run(current_time: Time.current)

      assert_equal 1, result.checked
      assert_equal 1, result.due
      assert_equal 1, result.sent
      assert_equal 0, result.failed
      assert result.acquired
      refute result.skipped
      assert_equal [{ title: "One Time Alert", message: "Today only" }], push_service.calls

      schedule.reload
      refute schedule.active?
      assert_in_delta Time.current.to_i, schedule.last_sent_at.to_i, 5
    end
  end

  test "run skips when another scheduler execution holds the lease" do
    push_service = FakePushService.new([])
    SchedulerLease.create!(
      key: NotificationScheduleRunner::LEASE_KEY,
      running: true,
      lease_token: "existing-token",
      started_at: Time.current,
      last_heartbeat_at: Time.current
    )

    result = NotificationScheduleRunner.new(push_service: push_service).run(current_time: Time.current)

    assert_equal 0, result.checked
    assert_equal 0, result.sent
    refute result.acquired
    assert result.skipped
    assert_equal [], push_service.calls
  end

  test "run can recover a stale scheduler lease" do
    push_service = FakePushService.new([])
    schedule = NotificationSchedule.create!(
      title: "Recovered Daily Alert",
      message: "Recovered",
      frequency: "daily",
      scheduled_time: "09:00",
      active: true
    )
    SchedulerLease.create!(
      key: NotificationScheduleRunner::LEASE_KEY,
      running: true,
      lease_token: "stale-token",
      started_at: 20.minutes.ago,
      last_heartbeat_at: 20.minutes.ago
    )

    travel_to Time.zone.local(2026, 3, 26, 10, 0, 0) do
      result = NotificationScheduleRunner.new(push_service: push_service).run(current_time: Time.current)

      assert result.acquired
      refute result.skipped
      assert_equal 1, result.sent
      assert_equal [{ title: "Recovered Daily Alert", message: "Recovered" }], push_service.calls

      schedule.reload
      assert_in_delta Time.current.to_i, schedule.last_sent_at.to_i, 5
    end
  end
end
