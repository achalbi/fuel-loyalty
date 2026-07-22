module Notifications
  module Channels
    # Delivers a NotificationRecipient over FCM push, reusing one access token
    # across the whole dispatch. When Firebase isn't configured, every push
    # recipient is recorded `skipped` rather than erroring.
    class PushChannel
      def initialize(service: FirebasePushService.new)
        @service = service
      end

      def deliver(recipient:, message:)
        subscription = recipient.push_subscription
        return recipient.mark_skipped!(reason: "no active push token") if subscription.nil? || !subscription.active?
        return recipient.mark_skipped!(reason: "push provider not configured") unless configured?

        outcome = @service.deliver_one(
          subscription: subscription, title: message.title, message: message.body.to_s,
          data: push_data(message), access_token: access_token
        )

        case outcome.status
        when :sent then recipient.mark_sent!(provider_message_id: outcome.provider_message_id)
        when :invalidated then recipient.mark_failed!(error: outcome.error, invalidated: true)
        else recipient.mark_failed!(error: outcome.error)
        end
      rescue FirebaseAppConfig::ConfigurationError => error
        recipient.mark_skipped!(reason: error.message)
      end

      private

      def configured?
        FirebaseAppConfig.push_delivery_ready?
      end

      def access_token
        @access_token ||= @service.access_token_for_dispatch
      end

      def push_data(message)
        { category: message.category, offer: message.offer_payload.presence }.compact
      end
    end
  end
end
