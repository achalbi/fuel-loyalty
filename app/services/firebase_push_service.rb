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

  private

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

  def build_payload(subscription:, title:, message:)
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
