class NotificationScheduleRunner
  Result = Struct.new(:checked, :due, :sent, :failed, :details, keyword_init: true) do
    def as_json(*)
      {
        checked: checked,
        due: due,
        sent: sent,
        failed: failed,
        details: details
      }
    end
  end

  def self.is_due?(schedule, current_time)
    return false unless schedule.active?

    current_time = current_time.in_time_zone(Time.zone)
    occurrence_time = occurrence_at(schedule, current_time)
    return false if occurrence_time.blank?
    return false if current_time < occurrence_time

    schedule.last_sent_at.blank? || schedule.last_sent_at.in_time_zone(Time.zone) < occurrence_time
  end

  def self.occurrence_at(schedule, current_time)
    case schedule.frequency
    when "once"
      return if schedule.scheduled_date.blank?

      schedule.scheduled_at_on(schedule.scheduled_date)
    when "daily"
      schedule.scheduled_at_on(current_time.to_date)
    when "weekly"
      return if schedule.day_of_week.blank?

      week_start = current_time.to_date.beginning_of_week(:sunday)
      schedule.scheduled_at_on(week_start + schedule.day_of_week.days)
    when "monthly"
      return if schedule.day_of_month.blank?

      day = [schedule.day_of_month, current_time.to_date.end_of_month.day].min
      schedule.scheduled_at_on(Date.new(current_time.year, current_time.month, day))
    end
  rescue ArgumentError
    nil
  end

  def initialize(push_service: FirebasePushService.new)
    @push_service = push_service
  end

  def run(current_time: Time.current)
    current_time = current_time.in_time_zone(Time.zone)
    schedules = NotificationSchedule.active.recent_first.to_a
    result = Result.new(checked: schedules.length, due: 0, sent: 0, failed: 0, details: [])

    schedules.each do |schedule|
      next unless self.class.is_due?(schedule, current_time)

      result.due += 1

      begin
        delivery_result = @push_service.broadcast(title: schedule.title, message: schedule.message)
        schedule.update!(last_sent_at: current_time, active: schedule.frequency == "once" ? false : schedule.active)
        result.sent += 1
        result.details << {
          schedule_id: schedule.id,
          title: schedule.title,
          result: delivery_result.as_json
        }
      rescue StandardError => error
        result.failed += 1
        result.details << {
          schedule_id: schedule.id,
          title: schedule.title,
          error: error.message
        }
      end
    end

    result
  end
end
