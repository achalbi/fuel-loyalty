require "test_helper"

module Notifications
  module Channels
    class WhatsappChannelTest < ActiveSupport::TestCase
      Fake = Struct.new(:outcome) do
        attr_reader :last
        def deliver(to:, body:)
          @last = { to: to, body: body }
          outcome
        end
      end

      def recipient(to_address: "9876543210")
        message = NotificationMessage.create!(title: "Offer", body: "20% off", category: :offer, channels: "whatsapp")
        message.notification_recipients.create!(channel: :whatsapp, customer: customers(:one), to_address: to_address, status: :pending)
      end

      test "sends via the provider and marks the recipient sent" do
        provider = Fake.new(Msg91WhatsappClient::Outcome.new(ok: true, provider_message_id: "req-9"))
        r = recipient
        WhatsappChannel.new(provider: provider).deliver(recipient: r, message: r.notification_message)
        assert r.reload.sent?
        assert_equal "req-9", r.provider_message_id
        assert_equal "Offer — 20% off", provider.last[:body]
      end

      test "a provider failure marks the recipient failed" do
        provider = Fake.new(Msg91WhatsappClient::Outcome.new(ok: false, error: "template not approved"))
        r = recipient
        WhatsappChannel.new(provider: provider).deliver(recipient: r, message: r.notification_message)
        assert r.reload.failed?
        assert_equal "template not approved", r.error
      end

      test "no configured provider records skipped, not sent" do
        r = recipient
        WhatsappChannel.new(provider: nil).deliver(recipient: r, message: r.notification_message)
        assert r.reload.skipped?
      end

      test "a blank number records skipped" do
        r = recipient(to_address: "")
        WhatsappChannel.new(provider: Fake.new(nil)).deliver(recipient: r, message: r.notification_message)
        assert r.reload.skipped?
      end
    end
  end
end
