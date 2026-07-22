module Notifications
  module Channels
    # SMS delivery (req 16). Gated on the customer's opt-in and on a
    # DLT-registered template + provider. No live provider is wired in this
    # build, so a recipient is recorded `skipped` — never silently sent. Live
    # delivery is a documented extension: set SMS_PROVIDER + API key, register
    # the DLT entity/template, then implement #deliver_via_provider.
    class SmsChannel
      def deliver(recipient:, message:)
        return recipient.mark_skipped!(reason: "no mobile number/opt-in") if recipient.to_address.blank?

        recipient.mark_skipped!(reason: "SMS provider not configured")
      end
    end
  end
end
