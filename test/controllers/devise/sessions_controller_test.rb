require "test_helper"

module Devise
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    def with_release_sha(value)
      original_value = ENV["RELEASE_SHA"]
      ENV["RELEASE_SHA"] = value
      yield
    ensure
      ENV["RELEASE_SHA"] = original_value
    end

    test "sign in page shows the install app call to action" do
      get new_user_session_path

      assert_response :success
      assert_select "a[href='#{new_loyalty_path}']", text: /Back to Loyalty Lookup/
      assert_select "[data-pwa-install-panel]", 1
      assert_select "[data-pwa-install-button]", text: /Install App/
      assert_select "[data-pwa-install-status]", /Install Ace Fuel Loyalty|Add Ace Fuel Loyalty/
    end

    test "sign in page uses cache-busted pwa asset links" do
      with_release_sha("test-release") do
        manifest_path = pwa_manifest_path(v: "test-release")

        get new_user_session_path

        assert_response :success
        assert_includes @response.body, %(rel="manifest" href="#{manifest_path}")
        assert_includes @response.body, %(href="/icon-192.png?v=test-release")
        assert_includes @response.body, %(href="/icon.png?v=test-release")
        assert_includes @response.body, %(href="/icon.svg?v=test-release")
      end
    end
  end
end
