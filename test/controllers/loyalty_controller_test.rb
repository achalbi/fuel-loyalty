require "test_helper"

class LoyaltyControllerTest < ActionDispatch::IntegrationTest
  test "renders public loyalty lookup form" do
    get new_loyalty_path

    assert_response :success
    assert_select "h1", "Loyalty Lookup"
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
