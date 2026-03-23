require "test_helper"

class PwaControllerTest < ActionDispatch::IntegrationTest
  def with_release_sha(value)
    original_value = ENV["RELEASE_SHA"]
    ENV["RELEASE_SHA"] = value
    yield
  ensure
    ENV["RELEASE_SHA"] = original_value
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
      assert_equal "Fuel Loyalty", manifest["name"]
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
      assert_includes response.body, "fuel-loyalty-static-test-release"
      assert_includes response.body, "/icon-192.png?v=test-release"
      assert_includes response.body, "/icon.png?v=test-release"
      assert_includes response.body, "/icon.svg?v=test-release"
      assert_includes response.body, "/manifest.json?v=test-release"
      assert_includes response.body, "/assets/bootstrap.min-"
      assert_includes response.body, "/assets/application-"
    end
  end
end
