require "test_helper"

class PointsRedeemerTest < ActiveSupport::TestCase
  test "creates a redeem ledger entry when enough points are available" do
    customer = customers(:one)

    assert_difference -> { PointsLedger.count }, 1 do
      result = PointsRedeemer.call(phone_number: customer.phone_number, points: 3)

      assert_equal customer, result.customer
      assert_equal 3, result.points_redeemed
      assert_equal 2, customer.reload.total_points
      assert_equal "redeem", customer.points_ledgers.order(:created_at).last.entry_type
    end
  end

  test "rejects redemption when points exceed available balance" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: customers(:one).phone_number, points: 10)
    end

    assert_includes error.record.errors.full_messages.to_sentence, "cannot exceed available points"
  end
end
