require "test_helper"

class PointsRedeemerTest < ActiveSupport::TestCase
  test "creates a redeem ledger entry when enough redeemable points are available in multiples of 100" do
    customer = Customer.create!(name: "Redeem User", phone_number: "9333333333")
    customer.points_ledgers.create!(points: 550, entry_type: :earn)

    assert_difference -> { PointsLedger.count }, 1 do
      result = PointsRedeemer.call(phone_number: customer.phone_number, points: 500)

      assert_equal customer, result.customer
      assert_equal 500, result.points_redeemed
      assert_equal 50, customer.reload.total_points
      assert_equal "redeem", customer.points_ledgers.order(:created_at).last.entry_type
    end
  end

  test "rejects redemption when points exceed maximum redeemable balance rounded to 100" do
    customer = Customer.create!(name: "Redeem Limit User", phone_number: "9444444444")
    customer.points_ledgers.create!(points: 550, entry_type: :earn)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: customer.phone_number, points: 600)
    end

    assert_includes error.record.errors.full_messages.to_sentence, "cannot exceed 500 redeemable points"
  end

  test "rejects redemption when points are not in multiples of 100" do
    customer = Customer.create!(name: "Redeem Step User", phone_number: "9555555555")
    customer.points_ledgers.create!(points: 500, entry_type: :earn)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: customer.phone_number, points: 150)
    end

    assert_includes error.record.errors.full_messages.to_sentence, "must be in multiples of 100"
  end

  test "rejects redemption when customer has less than 100 points available" do
    customer = Customer.create!(name: "Redeem Min User", phone_number: "9666666666")
    customer.points_ledgers.create!(points: 50, entry_type: :earn)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: customer.phone_number, points: 100)
    end

    assert_includes error.record.errors.full_messages.to_sentence, "must have at least 100 available points to redeem"
  end

  test "rejects redemption when the phone number is not 10 digits" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: "12345", points: 100)
    end

    assert_includes error.record.errors.full_messages, "Phone number must be a 10 digit number"
  end
end
