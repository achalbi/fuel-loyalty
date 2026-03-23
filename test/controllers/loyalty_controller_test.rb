require "test_helper"

class LoyaltyControllerTest < ActionDispatch::IntegrationTest
  test "renders public loyalty lookup form" do
    get new_loyalty_path

    assert_response :success
    assert_equal(
      ["max-age=0", "public", "s-maxage=60", "stale-if-error=86400", "stale-while-revalidate=30"],
      response.headers["Cache-Control"].split(", ").sort
    )
    assert_not_nil response.headers["ETag"]
    assert_select "h1", "Loyalty Lookup"
    assert_select "form[action='#{loyalty_result_path}'][method='get']", 1
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

  test "shows loyalty details for an existing customer" do
    customers(:one).points_ledgers.create!(points: -2, entry_type: :redeem)

    get loyalty_result_path(phone_number: customers(:one).phone_number)

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

  test "shows redeemable points when the customer has enough balance" do
    customer = customers(:one)
    customer.points_ledgers.create!(points: 195, entry_type: :earn)

    get loyalty_result_path(phone_number: customer.phone_number)

    assert_response :success
    assert_select ".loyalty-result-hero__value[data-loyalty-points-target='200'][aria-label='200 points']", "0"
    assert_select "[data-loyalty-redeem-status]", /Rewards unlocked:\s*200 points/
  end

  test "titleizes the customer name in the loyalty hero" do
    customer = customers(:one)
    customer.update!(name: "arun kumar")

    get loyalty_result_path(phone_number: customer.phone_number)

    assert_response :success
    assert_select "h1", "Arun Kumar"
  end

  test "returns validation feedback when the customer is not found" do
    get loyalty_result_path(phone_number: "9999999999")

    assert_response :unprocessable_entity
    assert_select ".alert", /No customer found/
  end

  test "returns validation feedback when the phone number is not 10 digits" do
    get loyalty_result_path(phone_number: "12345")

    assert_response :unprocessable_entity
    assert_select ".alert", /Phone number must be a 10 digit number/
  end

  test "shows full loyalty history when requested" do
    customer = customers(:one)

    6.times do |index|
      customer.points_ledgers.create!(points: -(index + 1), entry_type: :redeem, created_at: Time.current + index.minutes)
    end

    get loyalty_result_path(phone_number: customer.phone_number, full_history: 1)

    assert_response :success
    assert_select "a", "Show Last 5"
    assert_select "[data-loyalty-activity]", minimum: 7
  end
end
