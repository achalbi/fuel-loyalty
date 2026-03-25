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
