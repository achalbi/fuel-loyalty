module Notifications
  # Fans a persisted NotificationMessage out to per-recipient, per-channel
  # notification_recipients rows and delivers each via its channel, respecting
  # per-channel opt-in / token gating. Returns the per-channel status counts.
  # Channels are injectable so tests can drive it without a live provider.
  class Dispatcher
    def self.call(...) = new(...).call

    def initialize(message:, audience:, channels: nil)
      @message = message
      @audience = audience
      @channels = channels || default_channels
    end

    def call
      @message.channel_list.each do |channel_name|
        channel = @channels[channel_name]
        next unless channel

        recipients_for(channel_name).each { |recipient| channel.deliver(recipient: recipient, message: @message) }
      end
      summary
    end

    def summary
      @message.notification_recipients.reload.group(:channel, :status).count.each_with_object({}) do |((channel, status), count), memo|
        (memo[channel] ||= Hash.new(0))[status] += count
      end
    end

    private

    def default_channels
      {
        "push" => Channels::PushChannel.new,
        "whatsapp" => Channels::WhatsappChannel.new,
        "sms" => Channels::SmsChannel.new,
      }
    end

    def recipients_for(channel_name)
      case channel_name
      when "push" then push_recipients
      when "whatsapp" then contact_recipients(:whatsapp, :whatsapp_opt_in)
      when "sms" then contact_recipients(:sms, :sms_opt_in)
      else []
      end
    end

    def push_recipients
      scope = @audience.all? ? PushSubscription.active : PushSubscription.active.where(customer_id: @audience.customers.select(:id))
      scope.includes(:customer).map do |subscription|
        @message.notification_recipients.create!(
          channel: :push, customer_id: subscription.customer_id, push_subscription: subscription, status: :pending
        )
      end
    end

    def contact_recipients(channel, opt_in_column)
      @audience.customers.where(opt_in_column => true).where.not(phone_number: nil).map do |customer|
        @message.notification_recipients.create!(
          channel: channel, customer: customer, to_address: customer.phone_number, status: :pending
        )
      end
    end
  end
end
