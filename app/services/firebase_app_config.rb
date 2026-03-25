require "json"
require "stringio"

class FirebaseAppConfig
  FIREBASE_SDK_VERSION = "12.11.0".freeze
  FIREBASE_MESSAGING_SCOPE = "https://www.googleapis.com/auth/firebase.messaging".freeze
  WEB_CONFIG_KEYS = {
    apiKey: "FIREBASE_API_KEY",
    authDomain: "FIREBASE_AUTH_DOMAIN",
    storageBucket: "FIREBASE_STORAGE_BUCKET",
    messagingSenderId: "FIREBASE_MESSAGING_SENDER_ID",
    appId: "FIREBASE_APP_ID",
    measurementId: "FIREBASE_MEASUREMENT_ID"
  }.freeze

  class ConfigurationError < StandardError; end

  def self.project_id
    ENV["FIREBASE_PROJECT_ID"].presence ||
      service_account_payload["project_id"].presence ||
      ENV["GOOGLE_CLOUD_PROJECT"].presence ||
      ENV["GOOGLE_CLOUD_PROJECT_ID"].presence
  end

  def self.vapid_key
    ENV["FIREBASE_WEB_VAPID_KEY"].presence
  end

  def self.notification_link
    ENV["PUSH_NOTIFICATION_LINK"].presence || "/loyalty"
  end

  def self.web_config
    WEB_CONFIG_KEYS.each_with_object(projectId: project_id) do |(client_key, env_key), config|
      config[client_key] = ENV[env_key].presence if ENV[env_key].present?
    end.compact
  end

  def self.web_push_ready?
    web_configured? && vapid_key.present?
  end

  def self.web_configured?
    web_config.slice(:apiKey, :messagingSenderId, :appId, :projectId).values.all?(&:present?)
  end

  def self.push_delivery_ready?
    project_id.present?
  end

  def self.credentials
    if service_account_json.present?
      Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(service_account_json),
        scope: FIREBASE_MESSAGING_SCOPE
      )
    else
      Google::Auth.get_application_default([FIREBASE_MESSAGING_SCOPE])
    end
  rescue StandardError => error
    raise ConfigurationError, "Firebase credentials are not configured: #{error.message}"
  end

  def self.service_account_json
    ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].presence
  end

  def self.service_account_payload
    return {} if service_account_json.blank?

    JSON.parse(service_account_json)
  rescue JSON::ParserError
    {}
  end
end
