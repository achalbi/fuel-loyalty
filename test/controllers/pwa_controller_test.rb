require "test_helper"

class PwaControllerTest < ActionDispatch::IntegrationTest
  def with_release_sha(value)
    original_value = ENV["RELEASE_SHA"]
    ENV["RELEASE_SHA"] = value
    yield
  ensure
    ENV["RELEASE_SHA"] = original_value
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

  test "serves the web app manifest" do
    with_release_sha("test-release") do
      get pwa_manifest_path(v: "test-release")

      assert_response :success
      assert_equal "application/manifest+json", response.media_type
      assert_equal(
        ["max-age=300", "public", "s-maxage=300", "stale-while-revalidate=30"],
        response.headers["Cache-Control"].split(", ").sort
      )

      manifest = JSON.parse(response.body)
      assert_equal "Ace Fuel Loyalty", manifest["name"]
      assert_equal "Ace Fuel Loyalty", manifest["short_name"]
      assert_equal "/loyalty?source=pwa", manifest["start_url"]
      assert_includes manifest["icons"].map { |icon| icon["src"] }, "/icon-192.png?v=test-release"
      assert_includes manifest["icons"].map { |icon| icon["src"] }, "/icon.png?v=test-release"
      assert_includes manifest["icons"].map { |icon| icon["src"] }, "/icon.svg?v=test-release"
    end
  end

  test "serves the service worker at the root scope" do
    with_release_sha("test-release") do
      get pwa_service_worker_path

      assert_response :success
      assert_includes response.media_type, "javascript"
      assert_equal "no-cache", response.headers["Cache-Control"]
      assert_equal "/", response.headers["Service-Worker-Allowed"]
      assert_includes response.body, "const CACHE_VERSION = \"test-release\";"
      assert_includes response.body, "const STATIC_CACHE = `fuel-loyalty-static-${CACHE_VERSION}`;"
      assert_includes response.body, "/icon-192.png?v=test-release"
      assert_includes response.body, "/icon.png?v=test-release"
      assert_includes response.body, "/icon.svg?v=test-release"
      assert_includes response.body, "/notification-pump-icon.svg?v=test-release"
      assert_includes response.body, "/notification-pump-badge.svg?v=test-release"
      assert_includes response.body, "/manifest.json?v=test-release"
      assert_includes response.body, "/assets/bootstrap.min-"
      assert_includes response.body, "/assets/application-"
      assert_includes response.body, "if (/\\b(?:private|no-store)\\b/i.test(cacheControl)) return;"
    end
  end

  test "embeds firebase push config into the service worker when configured" do
    with_release_sha("test-release") do
      with_firebase_web_push_env do
        get pwa_service_worker_path

        assert_response :success
        assert_includes response.body, "const FIREBASE_PUSH_ENABLED = true;"
        assert_includes response.body, "\"storageBucket\":\"fuel-loyalty.firebasestorage.app\""
        assert_includes response.body, "\"measurementId\":\"G-TEST123\""
        assert_match(/self\.addEventListener\("notificationclick".*importScripts/m, response.body)
      end
    end
  end
end
