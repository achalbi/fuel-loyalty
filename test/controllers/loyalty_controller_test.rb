require "test_helper"

class LoyaltyControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "renders public loyalty lookup form" do
    get new_loyalty_path

    assert_response :success
    assert_equal(
      ["max-age=0", "public", "s-maxage=60", "stale-if-error=86400", "stale-while-revalidate=30"],
      response.headers["Cache-Control"].split(", ").sort
    )
    assert_not_nil response.headers["ETag"]
    assert_select "h1", "Loyalty Lookup"
    assert_select "form[action='#{loyalty_path}'][method='post']", 1
    assert_select "link[rel='manifest'][href^='#{pwa_manifest_path}']"
    assert_select "link[href*='cdn.jsdelivr']", count: 0
    assert_select "link[href*='fonts.googleapis']", count: 0
    assert_select "script[src*='cdn.jsdelivr']", count: 0
    assert_select "link[href*='/assets/bootstrap.min']", count: 1
    assert_select "link[href*='/assets/tabler-icons.min']", count: 1
    assert_select "link[href*='/assets/application']", count: 1
    assert_select "script[src*='/assets/bootstrap.bundle.min']", count: 1
    assert_select "input[placeholder='10 digit phone number']", 1
    assert_select "[data-pwa-install-panel][data-install-source='loyalty_page']", 1
    assert_select "[data-pwa-install-button]", text: /Install App/
    assert_select "[data-pwa-install-status]", /Install Fuel Loyalty|Add Fuel Loyalty/
    assert_select "input[placeholder='10 digit phone number'][maxlength='10'][data-phone-number-field='true']", 1
    assert_includes response.body, 'pattern="\d{10}"'
  end

  test "renders firebase push configuration when web push is configured" do
    with_firebase_web_push_env do
      get new_loyalty_path

      assert_response :success
      assert_select "script[type='module']", text: /firebase-app\.js/
      assert_includes response.body, "firebase-analytics.js"
      assert_includes response.body, "firebase-messaging.js"
      assert_includes response.body, "onForegroundMessage"
      assert_includes response.body, "showForegroundNotification"
      assert_includes response.body, "/notification-pump-icon.svg"
      assert_includes response.body, "/notification-pump-badge.svg"
      assert_includes response.body, "\"storageBucket\":\"fuel-loyalty.firebasestorage.app\""
      assert_includes response.body, "\"measurementId\":\"G-TEST123\""
      assert_includes response.body, "\"subscriptionEndpoint\":\"#{push_subscriptions_path}\""
      assert_select "[data-push-opt-in-panel] [data-push-disable-button] span", text: "Disable Notifications"
    end
  end

  test "renders the firebase sdk without push opt-in when only web config is present" do
    with_firebase_web_push_env("FIREBASE_WEB_VAPID_KEY" => nil) do
      get new_loyalty_path

      assert_response :success
      assert_select "script[type='module']", text: /firebase-app\.js/
      assert_select "[data-push-opt-in-panel]", count: 0
    end
  end

  test "allows supported mobile safari browsers" do
    get new_loyalty_path, headers: { "User-Agent" => iphone_safari_user_agent }

    assert_response :success
    assert_select "h1", "Loyalty Lookup"
  end

  test "allows supported samsung internet browsers" do
    get new_loyalty_path, headers: { "User-Agent" => samsung_internet_user_agent }

    assert_response :success
    assert_select "h1", "Loyalty Lookup"
  end

  test "blocks unsupported internet explorer browsers" do
    get new_loyalty_path, headers: { "User-Agent" => internet_explorer_user_agent }

    assert_response :not_acceptable
    assert_includes response.body, "Your browser is not supported"
  end

  test "returns 304 for a fresh loyalty shell request" do
    get new_loyalty_path

    assert_response :success
    etag = response.headers["ETag"]

    get new_loyalty_path, headers: {
      "If-None-Match" => etag,
      "If-Modified-Since" => 1.day.ago.httpdate
    }

    assert_response :not_modified
    assert_equal(
      ["max-age=0", "public", "s-maxage=60", "stale-if-error=86400", "stale-while-revalidate=30"],
      response.headers["Cache-Control"].split(", ").sort
    )
  end

  test "does not publicly cache loyalty lookup when a user is signed in" do
    sign_in users(:one)

    get new_loyalty_path

    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "legacy post lookup works without a csrf token" do
    original_value = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post loyalty_path, params: { loyalty: { phone_number: customers(:one).phone_number } }

    assert_response :redirect
    assert_predicate redirect_query["lookup_token"], :present?
    assert_not_includes response.location, "phone_number="
  ensure
    ActionController::Base.allow_forgery_protection = original_value
  end

  test "shows loyalty details for an existing customer" do
    customers(:one).points_ledgers.create!(points: -2, entry_type: :redeem)

    post loyalty_path, params: { loyalty: { phone_number: customers(:one).phone_number } }
    follow_redirect!

    assert_response :success
    assert_select "h1", "Arun"
    assert_select "[data-loyalty-points-hero]", 1
    assert_select "[data-loyalty-confetti]", 1
    assert_select ".loyalty-result-hero__value[data-loyalty-points-target='3'][aria-label='3 points']", "0"
    assert_select "[data-loyalty-redeem-status]", /97 points more.*unlock rewards/
    assert_select "[data-loyalty-activity]", 2
    assert_select ".loyalty-activity-item__summary", text: /-2/
    assert_select "[data-loyalty-fuel-badge]", count: 1, text: "P"
    assert_select ".loyalty-activity-item__details .loyalty-activity-item__detail", 4
    assert_select ".loyalty-activity-item__detail strong", text: "TN01AA1111"
    assert_select ".loyalty-activity-item__detail strong", text: /\u20b9500\.00/
  end

  test "loyalty lookup ignores stale devise sign out notices" do
    sign_in users(:one)

    delete destroy_user_session_path
    assert_response :redirect

    post loyalty_path, params: { loyalty: { phone_number: customers(:one).phone_number } }
    assert_response :redirect

    follow_redirect!

    assert_response :success
    assert_select ".alert", text: /Signed out successfully\./, count: 0
    assert_select "h1", "Arun"
  end

  test "shows redeemable points when the customer has enough balance" do
    customer = customers(:one)
    customer.points_ledgers.create!(points: 195, entry_type: :earn)

    get loyalty_result_path(lookup_token: loyalty_lookup_token_for(customer.phone_number))

    assert_response :success
    assert_select ".loyalty-result-hero__value[data-loyalty-points-target='200'][aria-label='200 points']", "0"
    assert_select "[data-loyalty-redeem-status]", /Rewards unlocked:\s*200 points/
  end

  test "titleizes the customer name in the loyalty hero" do
    customer = customers(:one)
    customer.update!(name: "arun kumar")

    get loyalty_result_path(lookup_token: loyalty_lookup_token_for(customer.phone_number))

    assert_response :success
    assert_select "h1", "Arun Kumar"
  end

  test "returns validation feedback when the customer is not found" do
    get loyalty_result_path(lookup_token: loyalty_lookup_token_for("9999999999"))

    assert_response :unprocessable_entity
    assert_select ".alert", /No customer found/
  end

  test "returns validation feedback when the phone number is not 10 digits" do
    post loyalty_path, params: { loyalty: { phone_number: "12345" } }

    assert_response :unprocessable_entity
    assert_select ".alert", /Phone number must be a 10 digit number/
  end

  test "shows full loyalty history when requested" do
    customer = customers(:one)

    6.times do |index|
      customer.points_ledgers.create!(points: -(index + 1), entry_type: :redeem, created_at: Time.current + index.minutes)
    end

    post loyalty_path, params: { loyalty: { phone_number: customer.phone_number } }
    assert_response :redirect

    get loyalty_result_path(lookup_token: redirect_query.fetch("lookup_token"), full_history: 1)

    assert_response :success
    assert_select "a[href*='lookup_token=']", minimum: 1
    assert_select "a[href*='phone_number=']", count: 0
    assert_select "a", "Show Last 5"
    assert_select "[data-loyalty-activity]", minimum: 7
  end

  test "redirects to the lookup form when no phone number is stored" do
    get loyalty_result_path

    assert_redirected_to new_loyalty_path
  end

  test "redirects to the lookup form when the token is invalid" do
    get loyalty_result_path(lookup_token: "invalid-token")

    assert_redirected_to new_loyalty_path
    follow_redirect!
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_select ".alert", /lookup link has expired/
  end

  test "redirects to the lookup form when the token is expired" do
    token = loyalty_lookup_token_for(customers(:one).phone_number)

    travel LoyaltyLookupToken::EXPIRY + 1.second do
      get loyalty_result_path(lookup_token: token)
    end

    assert_redirected_to new_loyalty_path
  end

  private

  def loyalty_lookup_token_for(phone_number)
    LoyaltyLookupToken.generate(phone_number)
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

  def redirect_query
    Rack::Utils.parse_nested_query(URI.parse(response.location).query)
  end

  def iphone_safari_user_agent
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
  end

  def samsung_internet_user_agent
    "Mozilla/5.0 (Linux; Android 13; SAMSUNG SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/24.0 Chrome/117.0.0.0 Mobile Safari/537.36"
  end

  def internet_explorer_user_agent
    "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
  end
end
