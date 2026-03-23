require "test_helper"

class PwaControllerTest < ActionDispatch::IntegrationTest
  test "serves the web app manifest" do
    get pwa_manifest_path

    assert_response :success
    assert_equal "application/manifest+json", response.media_type
    assert_equal(
      ["max-age=300", "public", "s-maxage=300", "stale-while-revalidate=30"],
      response.headers["Cache-Control"].split(", ").sort
    )

    manifest = JSON.parse(response.body)
    assert_equal "Fuel Loyalty", manifest["name"]
    assert_equal "/loyalty?source=pwa", manifest["start_url"]
    assert_includes manifest["icons"].map { |icon| icon["src"] }, "/icon-192.png"
  end

  test "serves the service worker at the root scope" do
    get pwa_service_worker_path

    assert_response :success
    assert_includes response.media_type, "javascript"
    assert_equal "no-cache", response.headers["Cache-Control"]
    assert_equal "/", response.headers["Service-Worker-Allowed"]
    assert_includes response.body, "fuel-loyalty-static-"
    assert_includes response.body, "/assets/bootstrap.min-"
    assert_includes response.body, "/assets/application-"
  end
end
