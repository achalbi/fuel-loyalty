require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "requires a customer name" do
    customer = Customer.new(name: "", phone_number: "9876543210")

    assert_not customer.valid?
    assert_includes customer.errors.full_messages, "Name can't be blank"
  end

  test "normalizes and validates a 10 digit phone number" do
    customer = Customer.new(name: "Ravi", phone_number: "98765 43210")

    assert customer.valid?
    assert_equal "9876543210", customer.phone_number
  end

  test "rejects phone numbers that are not 10 digits" do
    customer = Customer.new(name: "Ravi", phone_number: "987654321")

    assert_not customer.valid?
    assert_includes customer.errors.full_messages, "Phone number must be a 10 digit number"
  end

  test "uses the lowest configured minimum redeemable points across registered vehicle types" do
    customer = customers(:one)
    vehicle_types(:two_wheeler).update!(minimum_redeemable_points: 200)
    vehicle_types(:lmv).update!(minimum_redeemable_points: 300)

    assert_equal 200, customer.minimum_redeemable_points
  end

  test "falls back to the default redeemable minimum when the customer has no vehicles" do
    customer = Customer.create!(name: "No Vehicle User", phone_number: "9876543210")

    assert_equal VehicleType::DEFAULT_MINIMUM_REDEEMABLE_POINTS, customer.minimum_redeemable_points
  end

  test "uses the global reward setting minimum when it is configured" do
    RewardSetting.current.update!(minimum_redeemable_points: 250)
    customer = customers(:one)
    vehicle_types(:two_wheeler).update!(minimum_redeemable_points: 200)
    vehicle_types(:lmv).update!(minimum_redeemable_points: 300)

    assert_equal 250, customer.minimum_redeemable_points
  end

  test "transacted_between returns only customers with a transaction in the range" do
    staff = users(:two)
    recent = Customer.create!(name: "Recent", phone_number: "9812340001")
    recent_vehicle = recent.vehicles.create!(vehicle_number: "TN20AA0001", fuel_type: :petrol, vehicle_kind: :two_wheeler)
    recent.transactions.create!(user: staff, vehicle: recent_vehicle, fuel_amount: 400, created_at: 1.day.ago)

    stale = Customer.create!(name: "Stale", phone_number: "9812340002")
    stale_vehicle = stale.vehicles.create!(vehicle_number: "TN20AA0002", fuel_type: :petrol, vehicle_kind: :two_wheeler)
    stale.transactions.create!(user: staff, vehicle: stale_vehicle, fuel_amount: 400, created_at: 40.days.ago)

    range = 7.days.ago.beginning_of_day..Time.current.end_of_day
    ids = Customer.transacted_between(range).pluck(:id)

    assert_includes ids, recent.id
    assert_not_includes ids, stale.id
  end
end
