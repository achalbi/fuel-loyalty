module AdminNotificationsPageState
  extend ActiveSupport::Concern

  private

  def load_notifications_page_state(schedule: NotificationSchedule.new, edit_schedule: nil)
    @schedule = schedule
    @edit_schedule = edit_schedule
    @notification_schedules = NotificationSchedule.recent_first
    @push_subscription_count = PushSubscription.active.count
    @push_subscription_total_count = PushSubscription.count
    @push_subscription_platforms = PushSubscription.active.group(:platform).count.sort.to_h
  end
end
