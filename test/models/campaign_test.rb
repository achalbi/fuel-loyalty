require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  def build_campaign(**attrs)
    Campaign.new({
      name: "Promo", reward_kind: :bonus_points, bonus_points: 100,
      min_purchase_amount: 500, period: :rolling_days, period_days: 30, target_type: :all, channels: "push"
    }.merge(attrs))
  end

  test "a valid bonus-points campaign" do
    assert build_campaign.valid?
  end

  test "a discount needs exactly one of amount or percent" do
    both = build_campaign(reward_kind: :discount, bonus_points: nil, discount_amount: 50, discount_percent: 10)
    assert_not both.valid?
    assert_includes both.errors[:base].to_sentence, "exactly one"

    neither = build_campaign(reward_kind: :discount, bonus_points: nil)
    assert_not neither.valid?
  end

  test "at least one threshold is required" do
    campaign = build_campaign(min_purchase_amount: nil, min_purchase_litres: nil)
    assert_not campaign.valid?
    assert_includes campaign.errors[:base].to_sentence, "minimum purchase"
  end

  test "selected target needs at least one customer; individual needs exactly one" do
    selected = build_campaign(target_type: :selected)
    assert_not selected.valid?

    individual = build_campaign(target_type: :individual,
                                campaign_targets_attributes: [{ customer_id: customers(:one).id }, { customer_id: customers(:two).id }])
    assert_not individual.valid?, "two targets is not an individual campaign"
  end

  test "fixed window requires start <= end; rolling requires positive days" do
    bad_window = build_campaign(period: :fixed_window, period_days: nil, window_start: Date.new(2026, 7, 20), window_end: Date.new(2026, 7, 10))
    assert_not bad_window.valid?

    bad_days = build_campaign(period: :rolling_days, period_days: 0)
    assert_not bad_days.valid?
  end

  test "window_for resolves each period" do
    ref = Date.new(2026, 7, 15) # a Wednesday
    assert_equal (Date.new(2026, 7, 6)..ref), build_campaign(period: :rolling_days, period_days: 10).window_for(ref)
    assert_equal ref.beginning_of_month..ref.end_of_month, build_campaign(period: :monthly).window_for(ref)
    fixed = build_campaign(period: :fixed_window, period_days: nil, window_start: Date.new(2026, 7, 1), window_end: Date.new(2026, 7, 31))
    assert_equal (Date.new(2026, 7, 1)..Date.new(2026, 7, 31)), fixed.window_for(ref)
  end

  test "offer_payload carries the structured reward" do
    campaign = build_campaign(reward_kind: :discount, bonus_points: nil, discount_percent: 15)
    assert_equal "discount", campaign.offer_payload[:kind]
    assert_equal 15.0, campaign.offer_payload[:discount_percent]
    assert_match(/15% off/, campaign.offer_headline)
  end
end
