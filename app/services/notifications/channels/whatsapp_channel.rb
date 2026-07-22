module Notifications
  module Channels
    # WhatsApp delivery (F4). Gated on the customer's opt-in (the Dispatcher only
    # builds a recipient for opted-in customers with a phone). When a live
    # provider is configured (WHATSAPP_PROVIDER + creds), the message is sent
    # through it via a pre-approved template; otherwise the recipient is recorded
    # `skipped` — never silently dropped.
    class WhatsappChannel
      def initialize(provider: Notifications::WhatsappProvider.configured)
        @provider = provider
      end

      def deliver(recipient:, message:)
        return recipient.mark_skipped!(reason: "no WhatsApp number/opt-in") if recipient.to_address.blank?
        return recipient.mark_skipped!(reason: "WhatsApp provider not configured") if @provider.nil?

        outcome = @provider.deliver(to: recipient.to_address, body: body_for(message))
        if outcome.ok
          recipient.mark_sent!(provider_message_id: outcome.provider_message_id)
        else
          recipient.mark_failed!(error: outcome.error.presence || "WhatsApp send failed")
        end
      end

      private

      # The template's single body variable = title + message.
      def body_for(message)
        [message.title, message.body].compact_blank.join(" — ")
      end
    end
  end
end
