require "test_helper"

class ContactLogTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:one)
    @user = users(:one)
  end

  def build(attrs = {})
    ContactLog.new({ customer: @customer, user: @user, channel: "call", outcome: "reached" }.merge(attrs))
  end

  test "valid with channel, outcome, customer and user" do
    assert build.valid?
  end

  test "defaults contacted_at to now on create" do
    log = build
    log.save!
    assert_not_nil log.contacted_at
    assert_in_delta Time.current.to_f, log.contacted_at.to_f, 5
  end

  test "rejects an unknown channel" do
    log = build(channel: "carrier_pigeon")
    assert_not log.valid?
    assert_includes log.errors[:channel], "is not included in the list"
  end

  test "rejects an unknown outcome" do
    assert_not build(outcome: "ghosted").valid?
  end

  test "rejects a future contacted_at" do
    log = build(contacted_at: 2.days.from_now)
    assert_not log.valid?
    assert_includes log.errors[:contacted_at], "cannot be in the future"
  end

  test "allows a blank contacted_role but rejects an unknown one" do
    assert build(contacted_role: nil).valid?
    assert_not build(contacted_role: "captain").valid?
  end

  test "recent_first orders by contacted_at desc" do
    older = build.tap { |l| l.contacted_at = 3.days.ago }.tap(&:save!)
    newer = build.tap { |l| l.contacted_at = 1.hour.ago }.tap(&:save!)
    assert_equal [newer.id, older.id], @customer.contact_logs.recent_first.pluck(:id)
  end
end
