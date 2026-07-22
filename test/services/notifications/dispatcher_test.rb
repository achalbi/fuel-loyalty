require "test_helper"

module Notifications
  class DispatcherTest < ActiveSupport::TestCase
    # A fake channel that always succeeds, so we can test fan-out + gating
    # without a live provider.
    class FakeChannel
      def deliver(recipient:, message:)
        recipient.mark_sent!(provider_message_id: "fake-#{recipient.id}")
      end
    end

    setup do
      @customer = customers(:one) # has phone 9000000001
      @customer.update!(customer_type: :otp, whatsapp_opt_in: true, sms_opt_in: false)
      PushSubscription.register!(token: "tok-cust-1", platform: "android", customer: @customer)
      PushSubscription.register!(token: "tok-anon", platform: "web") # anonymous
    end

    def dispatch(message)
      audience = AudienceResolver.call(
        target_type: message.target_type, target_customer_type: message.target_customer_type,
        customer_ids: [@customer.id]
      )
      Dispatcher.new(message: message, audience: audience,
                     channels: { "push" => FakeChannel.new, "whatsapp" => FakeChannel.new, "sms" => FakeChannel.new }).call
    end

    test "customer_type push targets only that type's linked tokens (not anonymous)" do
      message = NotificationMessage.create!(title: "Offer", body: "20% off", category: :offer,
                                            target_type: :customer_type, target_customer_type: "otp", channels: "push")
      dispatch(message)
      recipients = message.notification_recipients
      assert_equal 1, recipients.count
      assert_equal @customer.id, recipients.first.customer_id
      assert recipients.first.sent?
    end

    test "all push includes anonymous tokens" do
      message = NotificationMessage.create!(title: "Hi", category: :broadcast, target_type: :all, channels: "push")
      dispatch(message)
      assert_equal 2, message.notification_recipients.count # linked + anonymous
    end

    test "multi-channel respects opt-in: whatsapp yes, sms skipped for opted-out" do
      message = NotificationMessage.create!(title: "Offer", body: "gift", category: :offer,
                                            target_type: :selected, channels: "push,whatsapp,sms")
      dispatch(message)
      channels = message.notification_recipients.group(:channel).count
      assert_equal 1, channels["whatsapp"], "opted-in customer gets a whatsapp row"
      assert_nil channels["sms"], "sms opt-out builds no row"
    end
  end
end
