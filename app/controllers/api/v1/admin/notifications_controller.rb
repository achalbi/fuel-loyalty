module Api
  module V1
    module Admin
      # Admin JSON: targeted, multi-channel ad-hoc sends (F2) with a persistent
      # delivery log + history. Authorized by the admin gate in BaseController.
      class NotificationsController < Api::V1::Admin::BaseController
        # POST /api/v1/admin/notifications/send — action named `deliver` to avoid
        # shadowing Object#send. notification[title, message, channels[],
        # target_type, target_customer_type, customer_ids[], category].
        def deliver
          attrs = send_params
          attrs.require(:title)

          result = Notifications::Broadcaster.call(
            title: attrs[:title],
            body: attrs[:message].presence || attrs[:body],
            category: attrs[:category].presence || :broadcast,
            target_type: attrs[:target_type],
            target_customer_type: attrs[:target_customer_type],
            customer_ids: attrs[:customer_ids],
            channels: attrs[:channels].presence || "push",
            created_by: current_user
          )
          render json: { notification_message_id: result.message.id, delivery: result.summary }, status: :ok
        end

        # GET /api/v1/admin/notifications?category=
        def index
          scope = NotificationMessage.recent_first.includes(:notification_recipients, :created_by)
          scope = scope.where(category: params[:category]) if NotificationMessage.categories.key?(params[:category].to_s)
          render json: { notifications: scope.limit(50).map { |m| NotificationMessageSerializer.call(m) } }, status: :ok
        end

        # GET /api/v1/admin/notifications/:id/recipients
        def recipients
          message = NotificationMessage.find(params[:id])
          rows = message.notification_recipients.recent_first.includes(:customer).limit(200)
          render json: { recipients: rows.map { |r| recipient_json(r) } }, status: :ok
        end

        private

        def send_params
          params.fetch(:notification, params).permit(
            :title, :message, :body, :category, :target_type, :target_customer_type,
            channels: [], customer_ids: []
          )
        end

        def recipient_json(recipient)
          {
            customer_id: recipient.customer_id,
            customer_name: recipient.customer&.display_name,
            channel: recipient.channel,
            status: recipient.status,
            error: recipient.error,
            provider_message_id: recipient.provider_message_id,
            sent_at: recipient.sent_at&.iso8601,
          }
        end
      end
    end
  end
end
