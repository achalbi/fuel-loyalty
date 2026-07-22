module Notifications
  # The single entry point both the web and API ad-hoc sends (and, later,
  # schedules + campaigns) go through: persist a NotificationMessage, resolve
  # its audience, dispatch over its channels, and return the per-channel counts.
  # Replaces the old fire-and-forget FirebasePushService#broadcast call.
  class Broadcaster
    Result = Struct.new(:message, :summary, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(title:, body:, category: :broadcast, target_type: "all", target_customer_type: nil,
                   customer_ids: nil, channels: "push", created_by: nil, offer_payload: {}, notification_schedule: nil)
      @title = title
      @body = body
      @category = NotificationMessage.categories.key?(category.to_s) ? category.to_s : "broadcast"
      target = target_type.to_s.presence || "all"
      @target_type = NotificationMessage.target_types.key?(target) ? target : "all"
      @target_customer_type = target_customer_type
      @customer_ids = customer_ids
      @channels = channels
      @created_by = created_by
      @offer_payload = offer_payload || {}
      @notification_schedule = notification_schedule
    end

    def call
      message = NotificationMessage.create!(
        title: @title, body: @body, category: @category,
        target_type: @target_type, target_customer_type: @target_customer_type.presence,
        channels: normalized_channels, created_by: @created_by, offer_payload: @offer_payload,
        notification_schedule: @notification_schedule
      )
      audience = AudienceResolver.call(
        target_type: @target_type, target_customer_type: @target_customer_type, customer_ids: @customer_ids
      )
      summary = Dispatcher.new(message: message, audience: audience).call
      Result.new(message: message, summary: summary)
    end

    private

    def normalized_channels
      list = @channels.is_a?(Array) ? @channels : @channels.to_s.split(",")
      cleaned = list.map { |value| value.to_s.strip.downcase }.select { |value| NotificationMessage::CHANNELS.include?(value) }.uniq
      cleaned.presence&.join(",") || "push"
    end
  end
end
