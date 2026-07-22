require "test_helper"

module Campaigns
  class RunnerTest < ActiveSupport::TestCase
    setup do
      @staff = users(:two)
      @customer = customers(:one)
      @vehicle = vehicles(:one)
      # Two ₹500 fills today → ₹1000 in a rolling 30-day window.
      2.times { @customer.transactions.create!(user: @staff, vehicle: @vehicle, fuel_amount: 500, payment_mode: "cash") }
    end

    def bonus_campaign(**overrides)
      # Target only customer one so fixture transactions for other customers
      # don't widen the candidate set.
      Campaign.create!({
        name: "Spend 800 get 200", reward_kind: :bonus_points, bonus_points: 200,
        min_purchase_amount: 800, period: :rolling_days, period_days: 30,
        target_type: :selected, channels: "push", status: :active,
        campaign_targets_attributes: [{ customer_id: @customer.id }]
      }.merge(overrides))
    end

    test "qualifies a customer over the ₹ threshold and grants bonus points once" do
      campaign = bonus_campaign
      assert_difference -> { PointsLedger.where(entry_type: :adjust).count }, 1 do
        result = Runner.call(campaign, notify: false)
        assert_equal 1, result.qualified
        assert_equal 1, result.rewarded
      end
      qualification = campaign.campaign_qualifications.find_by(customer: @customer)
      assert qualification.rewarded?
      assert_equal 200, qualification.reward_points_ledger.points
    end

    test "re-running the same window never double-grants" do
      campaign = bonus_campaign
      Runner.call(campaign, notify: false)
      assert_no_difference -> { PointsLedger.count } do
        result = Runner.call(campaign, notify: false)
        assert_equal 1, result.qualified
        assert_equal 0, result.rewarded, "already-granted qualifier is not re-rewarded"
      end
    end

    test "a rolling campaign re-run on later days never re-grants (stable idempotency key)" do
      campaign = bonus_campaign # rolling_days 30, min ₹800; customer one has ₹1500 today
      today = Date.current
      first = Runner.call(campaign, notify: false, reference: today)
      assert_equal 1, first.rewarded

      # The window slides a day forward, but the qualification key is anchored, so
      # no new row and no second grant.
      assert_no_difference -> { PointsLedger.count } do
        later = Runner.call(campaign, notify: false, reference: today + 1)
        assert_equal 0, later.rewarded
      end
      assert_equal 1, campaign.campaign_qualifications.count, "one qualification row, not one per run day"
    end

    test "a non-active campaign grants nothing" do
      campaign = bonus_campaign(status: :paused)
      assert_no_difference -> { PointsLedger.count } do
        result = Runner.call(campaign, notify: false)
        assert_equal 0, result.rewarded
      end
    end

    test "a customer below the threshold does not qualify" do
      campaign = bonus_campaign(min_purchase_amount: 2000)
      result = Runner.call(campaign, notify: false)
      assert_equal 0, result.qualified
    end

    test "a paused customer is skipped for bonus points but stays a qualifier" do
      @customer.update!(rewards_paused: true)
      campaign = bonus_campaign
      assert_no_difference -> { PointsLedger.count } do
        result = Runner.call(campaign, notify: false)
        assert_equal 1, result.qualified
        assert_equal 0, result.rewarded
      end
      assert_not campaign.campaign_qualifications.find_by(customer: @customer).rewarded?
    end

    test "notify builds one offer message to the qualifiers and never double-notifies" do
      @customer.update!(customer_type: :otp)
      PushSubscription.register!(token: "camp-tok", platform: "android", customer: @customer)
      campaign = bonus_campaign

      assert_difference -> { NotificationMessage.where(category: :offer).count }, 1 do
        Runner.call(campaign, notify: true)
      end
      message = NotificationMessage.offer.last
      assert_equal campaign.id, message.campaign_id
      assert_equal 1, message.notification_recipients.count

      assert_no_difference -> { NotificationMessage.count } do
        Runner.call(campaign, notify: true) # already notified
      end
    end
  end
end
