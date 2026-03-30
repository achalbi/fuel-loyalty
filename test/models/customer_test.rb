require "test_helper"

class CustomerTest < ActiveSupport::TestCase
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
end
