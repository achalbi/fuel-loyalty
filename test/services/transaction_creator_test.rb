require "test_helper"

class TransactionCreatorTest < ActiveSupport::TestCase
  test "creates a transaction and ledger entry for an existing customer vehicle" do
    user = User.create!(email: "staff-test@example.com", username: "staff_test", password: "password123", role: :staff)
    customer = Customer.create!(name: "Ravi", phone_number: "9876543210")
    vehicle = customer.vehicles.create!(vehicle_number: "TN01AB1234", fuel_type: :petrol, vehicle_kind: :two_wheeler)

    assert_no_difference -> { Customer.count } do
      assert_difference -> { Transaction.count }, 1 do
        assert_difference -> { PointsLedger.count }, 1 do
          result = TransactionCreator.call(
            user: user,
            phone_number: "98765 43210",
            fuel_amount: 550,
            vehicle_id: vehicle.id
          )

          assert_equal 10, result.points_earned
          assert_equal "9876543210", result.customer.phone_number
          assert_equal 10, result.customer.total_points
          assert_equal vehicle, result.transaction.vehicle
        end
      end
    end
  end

  test "rejects transactions for inactive customers" do
    user = User.create!(email: "staff-inactive@example.com", username: "staff_inactive", password: "password123", role: :staff)
    customer = Customer.create!(name: "Mohan", phone_number: "9876500000", active: false)
    vehicle = customer.vehicles.create!(vehicle_number: "TN10AB4321", fuel_type: :diesel, vehicle_kind: :lmv)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      TransactionCreator.call(
        user: user,
        phone_number: customer.phone_number,
        fuel_amount: 500,
        vehicle_id: vehicle.id
      )
    end

    assert_includes error.record.errors.full_messages, "Customer must be active to record transactions"
  end

  test "rejects transactions when the phone number is not 10 digits" do
    user = User.create!(email: "staff-invalid-phone@example.com", username: "staff_invalid_phone", password: "password123", role: :staff)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      TransactionCreator.call(
        user: user,
        phone_number: "12345",
        fuel_amount: 500,
        vehicle_id: vehicles(:one).id
      )
    end

    assert_includes error.record.errors.full_messages, "Phone number must be a 10 digit number"
  end
end
