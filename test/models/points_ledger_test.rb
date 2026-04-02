require "test_helper"

class PointsLedgerTest < ActiveSupport::TestCase
  test "snapshots cash reward amount when the ledger entry is created" do
    RewardSetting.current.update!(cash_value_per_point: 0.5)
    customer = Customer.create!(name: "Ledger Snapshot", phone_number: "9777700001")

    ledger_entry = customer.points_ledgers.create!(points: 20, entry_type: :earn)

    assert_equal BigDecimal("10.0"), ledger_entry.cash_reward_amount
  end

  test "keeps the original cash reward amount after reward settings change" do
    RewardSetting.current.update!(cash_value_per_point: 0.5)
    customer = Customer.create!(name: "Ledger Frozen", phone_number: "9777700002")
    ledger_entry = customer.points_ledgers.create!(points: 20, entry_type: :earn)

    RewardSetting.current.update!(cash_value_per_point: 1.0)

    assert_equal BigDecimal("10.0"), ledger_entry.reload.cash_reward_amount
  end

  test "leaves cash reward amount blank when no cash reward setting is configured" do
    RewardSetting.current.update!(cash_value_per_point: nil)
    customer = Customer.create!(name: "Ledger No Cash", phone_number: "9777700003")

    ledger_entry = customer.points_ledgers.create!(points: 20, entry_type: :earn)

    assert_nil ledger_entry.cash_reward_amount
  end
end
