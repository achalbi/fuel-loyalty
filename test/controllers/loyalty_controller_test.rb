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
    assert_select "link[rel='manifest'][href='#{pwa_manifest_path}']"
    assert_select "link[href*='cdn.jsdelivr']", count: 0
    assert_select "link[href*='fonts.googleapis']", count: 0
    assert_select "script[src*='cdn.jsdelivr']", count: 0
    assert_select "link[href*='/assets/bootstrap.min']", count: 1
    assert_select "link[href*='/assets/tabler-icons.min']", count: 1
    assert_select "link[href*='/assets/application']", count: 1
    assert_select "script[src*='/assets/bootstrap.bundle.min']", count: 1
  end

  test "returns 304 for a fresh loyalty shell request" do
    get new_loyalty_path

    assert_response :success

    get new_loyalty_path, headers: {
      "If-None-Match" => response.headers["ETag"],
      "If-Modified-Since" => response.headers["Last-Modified"]
    }

    assert_response :not_modified
    assert_equal(
      ["max-age=0", "public", "s-maxage=60", "stale-if-error=86400", "stale-while-revalidate=30"],
      response.headers["Cache-Control"].split(", ").sort
    )
  end

  test "shows loyalty details for an existing customer" do
    customers(:one).points_ledgers.create!(points: -2, entry_type: :redeem)

    post loyalty_path, params: { loyalty: { phone_number: customers(:one).phone_number } }

    assert_redirected_to loyalty_result_path(phone_number: customers(:one).phone_number)
    follow_redirect!

    assert_response :success
    assert_select "h1", "Arun"
    assert_select "div", text: /3/
    assert_select "td", text: /\u20b9500\.00/
    assert_select "td", text: "Points Redeemed"
  end

  test "returns validation feedback when the customer is not found" do
    post loyalty_path, params: { loyalty: { phone_number: "9999999999" } }

    follow_redirect!
    assert_response :unprocessable_entity
    assert_select ".alert", /No customer found/
  end

  test "shows full loyalty history when requested" do
    customer = customers(:one)

    6.times do |index|
      customer.points_ledgers.create!(points: -(index + 1), entry_type: :redeem, created_at: Time.current + index.minutes)
    end

    get loyalty_result_path(phone_number: customer.phone_number, full_history: 1)

    assert_response :success
    assert_select "a", "Show Last 5"
    assert_select "tbody tr", minimum: 7
  end
end
