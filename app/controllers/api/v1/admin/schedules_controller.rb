module Api
  module V1
    module Admin
      # Admin JSON endpoints for push-notification schedules.
      #
      # Mirrors the web Admin::SchedulesController JSON contract, but authorization
      # is the admin-only gate in Api::V1::Admin::BaseController (the web relied on
      # AdminApiAuthenticatable's admin-session/bearer-token check with no Pundit
      # policy). The bearer-token path is intentionally NOT implemented here; there
      # is no NotificationSchedulePolicy, so no `authorize` call is made.
      class SchedulesController < Api::V1::Admin::BaseController
        # GET /api/v1/admin/schedules
        def index
          schedules = NotificationSchedule.recent_first
          render json: { schedules: schedules.map { |schedule| NotificationScheduleSerializer.call(schedule) } },
                 status: :ok
        end

        # POST /api/v1/admin/schedules
        # notification_schedule[title, message, frequency, scheduled_time,
        #   scheduled_date, day_of_week, day_of_month, active]
        def create
          schedule = NotificationSchedule.new(schedule_params)
          schedule.save! # RecordInvalid -> base renders uniform 422 envelope
          render json: NotificationScheduleSerializer.call(schedule), status: :created
        end

        # PATCH/PUT /api/v1/admin/schedules/:id
        def update
          schedule = NotificationSchedule.find(params[:id])
          schedule.update!(schedule_params)
          render json: NotificationScheduleSerializer.call(schedule), status: :ok
        end

        # DELETE /api/v1/admin/schedules/:id
        def destroy
          schedule = NotificationSchedule.find(params[:id])
          schedule.destroy!
          head :no_content
        end

        # POST /api/v1/admin/schedules/run
        # Runs the lease-guarded cron sweep; returns the runner result hash.
        def run
          result = NotificationScheduleRunner.new.run(current_time: Time.current)
          render json: result.as_json, status: :ok
        end

        # POST /api/v1/admin/schedules/:id/send_now
        # Sends this schedule immediately over its configured channels/audience
        # (via the shared Broadcaster) and stamps last_sent_at.
        def send_now
          schedule = NotificationSchedule.find(params[:id])
          result = broadcast_schedule(schedule)
          # Only consume the occurrence when something actually delivered.
          schedule.update!(last_sent_at: Time.current) if delivered?(result.summary)
          render json: {
            schedule: NotificationScheduleSerializer.call(schedule),
            delivery: result.summary,
          }, status: :ok
        end

        private

        def broadcast_schedule(schedule)
          Notifications::Broadcaster.call(
            title: schedule.title, body: schedule.message, category: :scheduled,
            target_type: schedule.target_type, target_customer_type: schedule.target_customer_type,
            channels: schedule.channels, notification_schedule: schedule, campaign: schedule.campaign,
            offer_payload: schedule.campaign&.offer_payload || {}, created_by: current_user
          )
        end

        def delivered?(summary)
          (summary || {}).any? { |_channel, by_status| by_status.to_h.fetch("sent", 0).to_i.positive? }
        end

        # Accepts params nested under notification_schedule OR top-level (API-friendly
        # fallback) via the shared resource_params helper.
        def schedule_params
          resource_params(:notification_schedule)
            .permit(:title, :message, :frequency, :scheduled_time, :scheduled_date,
                    :day_of_week, :day_of_month, :active,
                    :target_type, :target_customer_type, :campaign_id, channels: [])
        end
      end
    end
  end
end
