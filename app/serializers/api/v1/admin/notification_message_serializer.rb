module Api
  module V1
    module Admin
      # A logged send + its per-channel delivery counts (F2/F3 history).
      class NotificationMessageSerializer
        def self.call(message)
          {
            id: message.id,
            title: message.title,
            body: message.body,
            category: message.category,
            target_type: message.target_type,
            target_customer_type: message.target_customer_type,
            channels: message.channel_list,
            offer_payload: message.offer_payload,
            created_by: message.created_by&.display_name,
            delivery: message.delivery_summary,
            recipient_count: message.notification_recipients.size,
            created_at: message.created_at&.iso8601,
          }
        end
      end
    end
  end
end
