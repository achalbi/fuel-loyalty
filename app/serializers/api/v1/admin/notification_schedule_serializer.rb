module Api
  module V1
    module Admin
      # JSON payload for a NotificationSchedule. Mirrors the web
      # Admin::SchedulesController#serialize_schedule key set (the 10 column keys
      # plus schedule_summary). Date/datetime -> iso8601; scheduled_time stays the
      # raw "HH:MM" string (it is a string column, not a time type).
      class NotificationScheduleSerializer
        def self.call(schedule)
          {
            id: schedule.id,
            title: schedule.title,
            message: schedule.message,
            frequency: schedule.frequency,
            scheduled_time: schedule.scheduled_time,
            scheduled_date: schedule.scheduled_date&.iso8601,
            day_of_week: schedule.day_of_week,
            day_of_month: schedule.day_of_month,
            last_sent_at: schedule.last_sent_at&.iso8601,
            active: schedule.active,
            channels: schedule.channel_list,
            target_type: schedule.target_type,
            target_customer_type: schedule.target_customer_type,
            campaign_id: schedule.campaign_id,
            schedule_summary: schedule.schedule_summary,
          }
        end
      end
    end
  end
end
