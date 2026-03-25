module Admin
  class SchedulesController < ApplicationController
    include AdminApiAuthenticatable
    include AdminNotificationsPageState

    def index
      schedules = NotificationSchedule.recent_first

      respond_to do |format|
        format.json { render json: schedules.map { |schedule| serialize_schedule(schedule) } }
        format.html { redirect_to admin_notifications_path }
      end
    end

    def create
      @schedule = NotificationSchedule.new(schedule_params)

      if @schedule.save
        respond_to do |format|
          format.json { render json: serialize_schedule(@schedule), status: :created }
          format.html { redirect_to admin_notifications_path, notice: "Schedule created successfully." }
        end
      else
        respond_with_schedule_errors(schedule: @schedule, status: :unprocessable_entity)
      end
    end

    def update
      @schedule = NotificationSchedule.find(params[:id])

      if @schedule.update(schedule_params)
        respond_to do |format|
          format.json { render json: serialize_schedule(@schedule), status: :ok }
          format.html { redirect_to admin_notifications_path, notice: "Schedule updated successfully." }
        end
      else
        respond_with_schedule_errors(schedule: @schedule, edit: true, status: :unprocessable_entity)
      end
    end

    def destroy
      schedule = NotificationSchedule.find(params[:id])
      schedule.destroy!

      respond_to do |format|
        format.json { head :no_content }
        format.html { redirect_to admin_notifications_path, notice: "Schedule deleted successfully." }
      end
    end

    def run
      result = NotificationScheduleRunner.new.run(current_time: Time.current)

      respond_to do |format|
        format.json { render json: result.as_json, status: :ok }
        format.html do
          redirect_to admin_notifications_path,
                      notice: "Scheduler run finished. #{result.sent} schedules sent, #{result.failed} failed."
        end
      end
    end

    private

    def schedule_params
      params.fetch(:notification_schedule, params).permit(
        :title,
        :message,
        :frequency,
        :scheduled_time,
        :scheduled_date,
        :day_of_week,
        :day_of_month,
        :active
      )
    end

    def serialize_schedule(schedule)
      schedule.slice(
        "id",
        "title",
        "message",
        "frequency",
        "scheduled_time",
        "scheduled_date",
        "day_of_week",
        "day_of_month",
        "last_sent_at",
        "active"
      ).merge(
        "schedule_summary" => schedule.schedule_summary
      )
    end

    def respond_with_schedule_errors(schedule:, edit: false, status:)
      respond_to do |format|
        format.json { render json: { errors: schedule.errors.full_messages }, status: status }
        format.html do
          load_notifications_page_state(
            schedule: edit ? NotificationSchedule.new : schedule,
            edit_schedule: edit ? schedule : nil
          )
          flash.now[:alert] = schedule.errors.full_messages.to_sentence
          render "admin/notifications/show", status: status
        end
      end
    end
  end
end
