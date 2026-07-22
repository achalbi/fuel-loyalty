require "json"
require "net/http"
require "securerandom"
require "uri"

class FirebasePushService
  BATCH_SIZE = 500
  DEFAULT_BATCH_DELAY_SECONDS = 0.05
  DEFAULT_TIMEOUT_SECONDS = 15
  INVALID_TOKEN_CODES = %w[UNREGISTERED INVALID_ARGUMENT].freeze
  NOTIFICATION_ICON_PATH = "/notification-pump-icon.svg".freeze
  NOTIFICATION_BADGE_PATH = "/notification-pump-badge.svg".freeze
  # Must match the channel created in the Android client (AceFuelApp.PUSH_CHANNEL_ID)
  # and the manifest default_notification_channel_id, so backgrounded devices display
  # the system-tray notification on a valid channel.
  ANDROID_NOTIFICATION_CHANNEL_ID = "fuel_loyalty_broadcast".freeze

  # Single-recipient dispatch outcome (Phase 3 targeted sends). status is one of
  # :sent / :failed / :invalidated.
  Outcome = Struct.new(:status, :provider_message_id, :error, keyword_init: true)

  Result = Struct.new(:requested, :sent, :failed, :invalidated, :batches, :errors, keyword_init: true) do
    def as_json(*)
      {
        requested: requested,
        sent: sent,
        failed: failed,
        invalidated: invalidated,
        batches: batches,
        errors: errors
      }
    end
  end

  def initialize(subscriptions: PushSubscription.active, batch_size: BATCH_SIZE, batch_delay: DEFAULT_BATCH_DELAY_SECONDS)
    @subscriptions = subscriptions
    @batch_size = batch_size
    @batch_delay = batch_delay
  end

  def broadcast(title:, message:)
    validate_configuration!

    result = Result.new(requested: @subscriptions.active.count, sent: 0, failed: 0, invalidated: 0, batches: 0, errors: [])
    access_token = fetch_access_token
    endpoint_uri = URI.parse(endpoint)

    @subscriptions.active.order(:id).in_batches(of: @batch_size) do |batch|
      records = batch.to_a
      next if records.empty?

      result.batches += 1

      Net::HTTP.start(
        endpoint_uri.host,
        endpoint_uri.port,
        use_ssl: true,
        open_timeout: DEFAULT_TIMEOUT_SECONDS,
        read_timeout: DEFAULT_TIMEOUT_SECONDS
      ) do |http|
        records.each do |subscription|
          deliver_to_subscription(http:, endpoint_uri:, access_token:, subscription:, title:, message:, result:)
        end
      end

      sleep(@batch_delay) if @batch_delay.to_f.positive?
    end

    result
  end

  # Fetch a dispatch access token once so a Dispatcher can reuse it across many
  # single-recipient deliveries (avoids an OAuth round-trip per recipient).
  def access_token_for_dispatch
    validate_configuration!
    fetch_access_token
  end

  # Send to a single subscription; returns an Outcome. `data` (e.g. an offer
  # payload) is merged into the FCM data block. Pass a pre-fetched access_token
  # to avoid re-fetching per recipient.
  def deliver_one(subscription:, title:, message:, data: {}, access_token: nil)
    access_token ||= access_token_for_dispatch
    endpoint_uri = URI.parse(endpoint)

    Net::HTTP.start(endpoint_uri.host, endpoint_uri.port, use_ssl: true,
      open_timeout: DEFAULT_TIMEOUT_SECONDS, read_timeout: DEFAULT_TIMEOUT_SECONDS) do |http|
      request = Net::HTTP::Post.new(endpoint_uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json; charset=utf-8"
      request.body = build_payload(subscription:, title:, message:, data:).to_json

      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        subscription.touch_last_used!
        parsed = parse_json(response.body)
        return Outcome.new(status: :sent, provider_message_id: parsed.is_a?(Hash) ? parsed["name"] : nil)
      end

      parsed_error = parse_json(response.body)
      if invalid_token_error?(parsed_error)
        subscription.deactivate!
        return Outcome.new(status: :invalidated, error: error_message_for(parsed_error, response.message))
      end
      Outcome.new(status: :failed, error: error_message_for(parsed_error, response.message))
    end
  rescue StandardError => error
    Outcome.new(status: :failed, error: error.message)
  end

  private

  # FCM data values must be strings; JSON-encode nested payloads (the offer).
  def stringify_data(data)
    (data || {}).each_with_object({}) do |(key, value), memo|
      next if value.nil?

      memo[key.to_s] = value.is_a?(String) ? value : value.to_json
    end
  end

  def validate_configuration!
    return if FirebaseAppConfig.push_delivery_ready?

    raise FirebaseAppConfig::ConfigurationError, "FIREBASE_PROJECT_ID or a Firebase service account must be configured."
  end

  def fetch_access_token
    credentials = FirebaseAppConfig.credentials
    token_payload = credentials.fetch_access_token!
    token_payload.fetch("access_token")
  rescue KeyError, StandardError => error
    raise FirebaseAppConfig::ConfigurationError, "Could not fetch a Firebase access token: #{error.message}"
  end

  def endpoint
    "https://fcm.googleapis.com/v1/projects/#{FirebaseAppConfig.project_id}/messages:send"
  end

  def deliver_to_subscription(http:, endpoint_uri:, access_token:, subscription:, title:, message:, result:)
    request = Net::HTTP::Post.new(endpoint_uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json; charset=utf-8"
    request.body = build_payload(subscription:, title:, message:).to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      subscription.touch_last_used!
      result.sent += 1
      return
    end

    parsed_error = parse_json(response.body)
    result.failed += 1

    if invalid_token_error?(parsed_error)
      subscription.deactivate!
      result.invalidated += 1
    end

    result.errors << {
      subscription_id: subscription.id,
      status: response.code.to_i,
      error: error_message_for(parsed_error, response.message)
    }
  rescue StandardError => error
    result.failed += 1
    result.errors << {
      subscription_id: subscription.id,
      status: nil,
      error: error.message
    }
  end

  def build_payload(subscription:, title:, message:, data: {})
    {
      message: {
        token: subscription.token,
          notification: {
            title: title,
            body: message
          },
        data: {
          title: title,
          message: message,
          link: FirebaseAppConfig.notification_link,
          notification_id: SecureRandom.uuid
        }.merge(stringify_data(data)),
        android: {
          priority: "high",
          notification: {
            channel_id: ANDROID_NOTIFICATION_CHANNEL_ID,
            default_sound: true,
            notification_priority: "PRIORITY_HIGH"
          }
        },
        webpush: {
          headers: {
            Urgency: "high",
            TTL: "86400"
          },
          notification: {
            title: title,
            body: message,
            icon: asset_url(NOTIFICATION_ICON_PATH),
            badge: asset_url(NOTIFICATION_BADGE_PATH),
            tag: "fuel-loyalty-broadcast"
          },
          fcm_options: {
            link: asset_url(FirebaseAppConfig.notification_link)
          }
        }
      }
    }
  end

  def asset_url(path)
    return path if ENV["APP_URL"].blank?

    URI.join("#{ENV['APP_URL'].chomp('/')}/", path.delete_prefix("/")).to_s
  rescue URI::InvalidURIError
    path
  end

  def parse_json(value)
    JSON.parse(value)
  rescue JSON::ParserError, TypeError
    {}
  end

  def invalid_token_error?(parsed_error)
    details = parsed_error.dig("error", "details")
    return false unless details.is_a?(Array)

    details.any? do |detail|
      detail["@type"] == "type.googleapis.com/google.firebase.fcm.v1.FcmError" &&
        INVALID_TOKEN_CODES.include?(detail["errorCode"])
    end
  end

  def error_message_for(parsed_error, fallback)
    parsed_error.dig("error", "message").presence || fallback
  end
end
