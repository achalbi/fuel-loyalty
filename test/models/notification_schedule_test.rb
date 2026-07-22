require "test_helper"

class NotificationScheduleTest < ActiveSupport::TestCase
  def build(**overrides)
    NotificationSchedule.new({
      title: "Reminder",
      message: "Come back soon",
      frequency: "daily",
      scheduled_time: "09:00",
      active: true
    }.merge(overrides))
  end

  test "channels default to push and normalize from an array" do
    assert_equal %w[push], build.tap(&:validate).channel_list

    schedule = build(channels: %w[whatsapp push whatsapp])
    schedule.validate
    assert_equal "push,whatsapp", schedule.channels
    assert_equal %w[push whatsapp], schedule.channel_list
  end

  test "channels accept a comma string and drop unknown values, keeping at least push" do
    assert_equal %w[push sms], build(channels: "sms, push, telepathy").channel_list
    assert_equal %w[push], build(channels: %w[carrier-pigeon]).channel_list
    assert_equal %w[push], build(channels: []).channel_list
  end

  test "target_type is limited to all or customer_type" do
    assert build(target_type: "all").valid?
    assert build(target_type: "customer_type", target_customer_type: "credit").valid?

    schedule = build(target_type: "individual")
    refute schedule.valid?
    assert_includes schedule.errors[:target_type], "is not included in the list"
  end

  test "customer_type target requires a valid customer_type" do
    blank = build(target_type: "customer_type")
    refute blank.valid?
    assert_predicate blank.errors[:target_customer_type], :present?

    bad = build(target_type: "customer_type", target_customer_type: "vip")
    refute bad.valid?

    ok = build(target_type: "customer_type", target_customer_type: "credit")
    assert ok.valid?
  end

  test "target_customer_type is cleared when the audience is everyone" do
    schedule = build(target_type: "all", target_customer_type: "credit")
    schedule.validate
    assert_nil schedule.target_customer_type
  end
end
