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
        # Broadcasts this schedule immediately and stamps last_sent_at on success.
        def send_now
          schedule = NotificationSchedule.find(params[:id])
          result = FirebasePushService.new.broadcast(title: schedule.title, message: schedule.message)
          schedule.update!(last_sent_at: Time.current) if result.sent.to_i.positive?
          render json: {
            schedule: NotificationScheduleSerializer.call(schedule),
            delivery: result.as_json,
          }, status: :ok
        rescue FirebaseAppConfig::ConfigurationError => error
          render_error(status: 422, code: "configuration_error", message: error.message)
        end

        private

        # Accepts params nested under notification_schedule OR top-level (API-friendly
        # fallback) via the shared resource_params helper.
        def schedule_params
          resource_params(:notification_schedule)
            .permit(:title, :message, :frequency, :scheduled_time, :scheduled_date,
                    :day_of_week, :day_of_month, :active)
        end
      end
    end
  end
end
