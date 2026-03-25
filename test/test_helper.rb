ENV["RAILS_ENV"] ||= "test"
ENV["DATABASE_URL"] = ENV.fetch("TEST_DATABASE_URL", "postgresql://postgres:postgres@db:5432/app_test") if ENV["RAILS_ENV"] == "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    host! "www.example.test"
  end

  def with_firebase_web_push_env(overrides = {})
    defaults = {
      "FIREBASE_API_KEY" => "test-api-key",
      "FIREBASE_AUTH_DOMAIN" => "fuel-loyalty.firebaseapp.com",
      "FIREBASE_PROJECT_ID" => "fuel-loyalty",
      "FIREBASE_STORAGE_BUCKET" => "fuel-loyalty.firebasestorage.app",
      "FIREBASE_MESSAGING_SENDER_ID" => "629935221011",
      "FIREBASE_APP_ID" => "1:629935221011:web:test-app",
      "FIREBASE_MEASUREMENT_ID" => "G-TEST123",
      "FIREBASE_WEB_VAPID_KEY" => "test-vapid-key"
    }.merge(overrides.transform_keys(&:to_s))

    original_values = defaults.keys.index_with { |key| ENV[key] }
    defaults.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original_values&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
