module Notifications
  module Channels
    # WhatsApp delivery (req 16). Gated on the customer's opt-in (checked by the
    # Dispatcher when it builds the recipient) and on an approved template +
    # provider (MSG91/Twilio). No live provider is wired in this build, so a
    # recipient is recorded `skipped` with a clear reason — never silently sent.
    # Live delivery is a documented extension: set WHATSAPP_PROVIDER + API key in
    # Secret Manager and register the templates, then implement #deliver_via_provider.
    class WhatsappChannel
      def deliver(recipient:, message:)
        return recipient.mark_skipped!(reason: "no WhatsApp number/opt-in") if recipient.to_address.blank?

        recipient.mark_skipped!(reason: "WhatsApp provider not configured")
      end
    end
  end
end
