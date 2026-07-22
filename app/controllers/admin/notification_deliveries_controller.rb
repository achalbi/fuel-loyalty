module Admin
  # F2 — targeted, multi-channel ad-hoc send (web). Persists a NotificationMessage
  # and fans it out through the notification engine, replacing the old
  # fire-and-forget FirebasePushService#broadcast.
  class NotificationDeliveriesController < ApplicationController
    include AdminApiAuthenticatable

    def create
      attrs = delivery_params
      attrs.require(:title)
      attrs.require(:message)

      result = Notifications::Broadcaster.call(
        title: attrs[:title], body: attrs[:message],
        target_type: attrs[:target_type], target_customer_type: attrs[:target_customer_type],
        customer_ids: attrs[:customer_ids], channels: attrs[:channels].presence || ["push"],
        created_by: current_user
      )

      respond_to do |format|
        format.json { render json: { notification_message_id: result.message.id, delivery: result.summary }, status: :ok }
        format.html { redirect_to admin_notifications_path, notice: summary_flash(result.summary) }
      end
    rescue ActionController::ParameterMissing => error
      respond_with_error(error.message, status: :unprocessable_entity)
    end

    private

    def delivery_params
      params.fetch(:notification, params).permit(
        :title, :message, :target_type, :target_customer_type, channels: [], customer_ids: []
      )
    end

    # "Sent 12 · skipped 3 · failed 0" across every channel/status.
    def summary_flash(summary)
      totals = Hash.new(0)
      summary.each_value { |by_status| by_status.each { |status, count| totals[status] += count } }
      return "No reachable recipients for that audience/channel." if totals.values.sum.zero?

      "Notification sent — #{totals['sent']} delivered · #{totals['skipped']} skipped · #{totals['failed'] + totals['invalidated']} failed."
    end

    def respond_with_error(message, status:)
      respond_to do |format|
        format.json { render json: { error: message }, status: status }
        format.html { redirect_to admin_notifications_path, alert: message }
      end
    end
  end
end
