require "test_helper"

class LoyaltyMilestoneNotifierTest < ActiveSupport::TestCase
  setup do
    RewardSetting.current.update!(milestone_step: 500)
    @customer = customers(:one)
    PushSubscription.register!(token: "milestone-tok", platform: "android", customer: @customer)
  end

  def award(points)
    @customer.points_ledgers.create!(points: points, entry_type: :earn)
  end

  test "crossing a rung sends one loyalty_milestone notification and advances the marker" do
    award(520)
    assert_difference -> { NotificationMessage.where(category: :loyalty_milestone).count }, 1 do
      LoyaltyMilestoneNotifier.call(@customer)
    end
    assert_equal 500, @customer.reload.last_milestone_points
    message = NotificationMessage.loyalty_milestone.last
    assert_equal 1, message.notification_recipients.count
    assert_match(/500 points/, message.title)
  end

  test "does not re-fire within the same rung" do
    award(520)
    LoyaltyMilestoneNotifier.call(@customer)
    assert_no_difference -> { NotificationMessage.count } do
      LoyaltyMilestoneNotifier.call(@customer.reload)
    end
  end

  test "fires again only when the next rung is crossed" do
    award(520)
    LoyaltyMilestoneNotifier.call(@customer)
    award(500) # now 1020 → crosses 1000
    assert_difference -> { NotificationMessage.count }, 1 do
      LoyaltyMilestoneNotifier.call(@customer.reload)
    end
    assert_equal 1000, @customer.reload.last_milestone_points
  end

  test "below the first rung sends nothing" do
    award(300)
    assert_no_difference -> { NotificationMessage.count } do
      LoyaltyMilestoneNotifier.call(@customer)
    end
    assert_equal 0, @customer.reload.last_milestone_points
  end
end
