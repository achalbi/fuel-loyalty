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
end
