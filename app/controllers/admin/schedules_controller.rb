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
          redirect_to admin_notifications_path, **scheduler_run_flash_for(result)
        end
      end
    end

    def send_now
      schedule = NotificationSchedule.find(params[:id])
      result = Notifications::Broadcaster.call(
        title: schedule.title, body: schedule.message, category: :scheduled,
        target_type: schedule.target_type, target_customer_type: schedule.target_customer_type,
        channels: schedule.channels, notification_schedule: schedule, campaign: schedule.campaign,
        offer_payload: schedule.campaign&.offer_payload || {}, created_by: current_user
      )
      # Only consume the occurrence when something actually went out — an empty /
      # all-skipped manual send must not suppress the automatic run.
      schedule.update!(last_sent_at: Time.current) if delivery_counts(result.summary)[:sent].positive?

      respond_to do |format|
        format.json do
          render json: {
            schedule: serialize_schedule(schedule),
            delivery: result.summary
          }, status: :ok
        end
        format.html do
          redirect_to admin_notifications_path, **schedule_send_now_flash_for(schedule, result)
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
        :active,
        :target_type,
        :target_customer_type,
        :campaign_id,
        channels: []
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
        "active",
        "target_type",
        "target_customer_type",
        "campaign_id"
      ).merge(
        "channels" => schedule.channel_list,
        "schedule_summary" => schedule.schedule_summary
      )
    end

    def scheduler_run_notice_for(result)
      return result.message if result.skipped

      base_message = "Scheduler run finished. #{result.sent} schedules sent, #{result.failed} failed."
      first_error = Array(result.details).filter_map { |detail| detail[:error] || detail["error"] }.first
      return base_message if first_error.blank?

      "#{base_message} #{first_error}"
    end

    def scheduler_run_flash_for(result)
      return { alert: result.message } if result.skipped
      if result.due.to_i.zero?
        return {
          alert: "No schedules are due right now. Schedules run only after their scheduled IST time. Use Send Now to broadcast immediately."
        }
      end

      flash_key = result.failed.to_i.positive? ? :alert : :notice
      { flash_key => scheduler_run_notice_for(result) }
    end

    def schedule_send_now_notice_for(schedule, result)
      counts = delivery_counts(result.summary)
      if counts[:total].zero?
        return "No reachable recipients on the selected channels, so \"#{schedule.title}\" was not sent."
      end

      "Sent \"#{schedule.title}\" now. #{counts[:sent]} delivered, #{counts[:skipped]} skipped, #{counts[:failed]} failed."
    end

    def schedule_send_now_flash_for(schedule, result)
      counts = delivery_counts(result.summary)
      flash_key = counts[:total].zero? || counts[:failed].positive? ? :alert : :notice
      { flash_key => schedule_send_now_notice_for(schedule, result) }
    end

    # Flatten a Broadcaster per-channel summary ({channel => {status => n}}) into
    # sent/skipped/failed/total tallies for flash copy. Statuses are the
    # NotificationRecipient enum (sent/failed/invalidated/skipped); invalidated
    # (dead tokens) folds into failed, matching NotificationDeliveriesController
    # and the Android summarizer.
    def delivery_counts(summary)
      totals = Hash.new(0)
      (summary || {}).each_value do |by_status|
        by_status.each { |status, count| totals[status.to_s] += count.to_i }
      end
      {
        sent: totals["sent"],
        skipped: totals["skipped"],
        failed: totals["failed"] + totals["invalidated"],
        total: totals.values.sum
      }
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
