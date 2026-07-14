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

  test "returns the configured cash reward value for redeemed points" do
    RewardSetting.current.update!(cash_value_per_point: 0.5)
    customer = Customer.create!(name: "Redeem Cash User", phone_number: "9333333344")
    customer.points_ledgers.create!(points: 500, entry_type: :earn)

    result = PointsRedeemer.call(phone_number: customer.phone_number, points: 500)

    assert_equal BigDecimal("250.0"), result.cash_reward_amount
    assert_equal BigDecimal("250.0"), customer.reload.points_ledgers.order(:created_at).last.cash_reward_amount
  end

  test "rejects redemption when rewards are paused for the customer" do
    customer = Customer.create!(name: "Paused Redeem User", phone_number: "9333333355", rewards_paused: true)
    customer.points_ledgers.create!(points: 500, entry_type: :earn)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: customer.phone_number, points: 500)
    end

    assert_includes error.record.errors.full_messages.to_sentence, "cannot be redeemed while rewards are paused for this customer"
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

  test "uses the configured global minimum redeemable points as the redemption increment" do
    RewardSetting.current.update!(minimum_redeemable_points: 250)
    customer = Customer.create!(name: "Redeem Global Min User", phone_number: "9666666699")
    customer.points_ledgers.create!(points: 550, entry_type: :earn)

    result = PointsRedeemer.call(phone_number: customer.phone_number, points: 250)

    assert_equal 250, result.points_redeemed
    assert_equal 300, customer.reload.total_points
  end

  test "rejects redemption when points are not in multiples of the configured global minimum" do
    RewardSetting.current.update!(minimum_redeemable_points: 250)
    customer = Customer.create!(name: "Redeem Global Step User", phone_number: "9666666700")
    customer.points_ledgers.create!(points: 500, entry_type: :earn)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: customer.phone_number, points: 200)
    end

    assert_includes error.record.errors.full_messages.to_sentence, "must be in multiples of 250"
  end

  test "rejects redemption below the configured vehicle type minimum" do
    vehicle_types(:lcv).update!(minimum_redeemable_points: 300)
    customer = Customer.create!(name: "Redeem Threshold User", phone_number: "9666666677")
    customer.vehicles.create!(vehicle_number: "TN10AB1234", fuel_type: :diesel, vehicle_kind: vehicle_types(:lcv).code,
      commercial_company_name: "Acme Freight", commercial_contact_name: "Ravi Kumar", commercial_address: "12 Transport Nagar, Chennai")
    customer.points_ledgers.create!(points: 450, entry_type: :earn)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: customer.phone_number, points: 200)
    end

    assert_includes error.record.errors.full_messages.to_sentence, "must be at least 300 points"
  end

  test "rejects redemption when the configured vehicle type minimum has not been reached yet" do
    vehicle_types(:lcv).update!(minimum_redeemable_points: 300)
    customer = Customer.create!(name: "Redeem Locked User", phone_number: "9666666688")
    customer.vehicles.create!(vehicle_number: "TN10AB4321", fuel_type: :diesel, vehicle_kind: vehicle_types(:lcv).code,
      commercial_company_name: "Acme Freight", commercial_contact_name: "Ravi Kumar", commercial_address: "12 Transport Nagar, Chennai")
    customer.points_ledgers.create!(points: 250, entry_type: :earn)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: customer.phone_number, points: 300)
    end

    assert_includes error.record.errors.full_messages.to_sentence, "must have at least 300 available points to redeem"
  end

  test "rejects redemption when the phone number is not 10 digits" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      PointsRedeemer.call(phone_number: "12345", points: 100)
    end

    assert_includes error.record.errors.full_messages, "Phone number must be a 10 digit number"
  end
end
