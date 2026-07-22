require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "creates a push subscription" do
    assert_difference -> { PushSubscription.count }, 1 do
      post push_subscriptions_path, params: {
        token: "token-123",
        platform: "android"
      }, as: :json
    end

    assert_response :created
    assert_equal "android", PushSubscription.last.platform
    assert PushSubscription.last.active?
  end

  test "upserts an existing push subscription" do
    subscription = PushSubscription.create!(
      token: "token-123",
      platform: "web",
      last_used_at: 2.days.ago,
      active: false
    )

    assert_no_difference -> { PushSubscription.count } do
      post push_subscriptions_path, params: {
        token: "token-123",
        platform: "android"
      }, as: :json
    end

    assert_response :ok
    assert_equal "android", subscription.reload.platform
    assert subscription.active?
    assert_in_delta Time.current.to_i, subscription.last_used_at.to_i, 5
  end

  test "links the subscription to a signed-in staff user" do
    sign_in users(:two)

    post push_subscriptions_path, params: { token: "token-staff", platform: "web" }, as: :json

    assert_response :created
    assert_equal users(:two).id, PushSubscription.find_by(token: "token-staff").user_id
  end

  test "links the subscription to a customer by phone number" do
    post push_subscriptions_path, params: {
      token: "token-cust", platform: "android", phone_number: customers(:one).phone_number
    }, as: :json

    assert_response :created
    subscription = PushSubscription.find_by(token: "token-cust")
    assert_equal customers(:one).id, subscription.customer_id
    assert_not_nil subscription.consent_at, "linking via phone stamps the push consent"
  end

  test "stays anonymous for an unknown phone number" do
    post push_subscriptions_path, params: {
      token: "token-anon", platform: "android", phone_number: "9999999999"
    }, as: :json

    assert_response :created
    subscription = PushSubscription.find_by(token: "token-anon")
    assert_nil subscription.customer_id
    assert_nil subscription.user_id
  end

  test "an anonymous re-register keeps a previously learned customer link" do
    post push_subscriptions_path, params: {
      token: "token-keep", platform: "android", phone_number: customers(:one).phone_number
    }, as: :json
    assert_equal customers(:one).id, PushSubscription.find_by(token: "token-keep").customer_id

    post push_subscriptions_path, params: { token: "token-keep", platform: "android" }, as: :json
    assert_equal customers(:one).id, PushSubscription.find_by(token: "token-keep").reload.customer_id
  end

  test "deactivates a push subscription" do
    subscription = PushSubscription.create!(
      token: "token-123",
      platform: "android",
      last_used_at: Time.current,
      active: true
    )

    delete push_subscriptions_path, params: { token: subscription.token }, as: :json

    assert_response :no_content
    refute subscription.reload.active?
  end
end
