require "test_helper"

class TransactionCreatorTest < ActiveSupport::TestCase
  test "creates a transaction and ledger entry for an existing customer vehicle" do
    RewardSetting.current.update!(cash_value_per_point: 0.5)
    user = User.create!(name: "Staff Test", username: "staff_test", phone_number: "9011111111", password: "password123", password_confirmation: "password123", role: :staff)
    petrol_nozzle, = assign_pump_to_user(user)
    customer = Customer.create!(name: "Ravi", phone_number: "9876543210")
    vehicle = customer.vehicles.create!(vehicle_number: "TN01AB1234", fuel_type: :petrol, vehicle_kind: :two_wheeler)

    assert_no_difference -> { Customer.count } do
      assert_difference -> { Transaction.count }, 1 do
        assert_difference -> { PointsLedger.count }, 1 do
          result = TransactionCreator.call(
            user: user,
            phone_number: "98765 43210",
            fuel_amount: 550,
            vehicle_id: vehicle.id,
            fuel_pump_nozzle_id: petrol_nozzle.id
          )

          assert_equal 10, result.points_earned
          assert_equal "9876543210", result.customer.phone_number
          assert_equal 10, result.customer.total_points
          assert_equal vehicle, result.transaction.vehicle
          assert_equal "cash", result.transaction.payment_mode
          assert_equal BigDecimal("5.0"), result.customer.points_ledgers.order(:created_at).last.cash_reward_amount
        end
      end
    end
  end

  test "stores credit payment mode when selected" do
    user = User.create!(name: "Staff Credit", username: "staff_credit_mode", phone_number: "9018888888", password: "password123", password_confirmation: "password123", role: :staff)
    petrol_nozzle, = assign_pump_to_user(user)
    customer = Customer.create!(name: "Credit User", phone_number: "9876541111")
    vehicle = customer.vehicles.create!(vehicle_number: "TN09AB1234", fuel_type: :petrol, vehicle_kind: :two_wheeler)

    result = TransactionCreator.call(
      user: user,
      phone_number: customer.phone_number,
      fuel_amount: 250,
      vehicle_id: vehicle.id,
      fuel_pump_nozzle_id: petrol_nozzle.id,
      payment_mode: "credit"
    )

    assert_equal "credit", result.transaction.payment_mode
  end

  test "creates a transaction without awarding points when rewards are paused for the customer" do
    user = User.create!(name: "Staff Paused Rewards", username: "staff_paused_rewards", phone_number: "9019999999", password: "password123", password_confirmation: "password123", role: :staff)
    petrol_nozzle, = assign_pump_to_user(user)
    customer = Customer.create!(name: "Paused Customer", phone_number: "9876542222", rewards_paused: true)
    vehicle = customer.vehicles.create!(vehicle_number: "TN13AB1234", fuel_type: :petrol, vehicle_kind: :two_wheeler)

    assert_difference -> { Transaction.count }, 1 do
      assert_no_difference -> { PointsLedger.count } do
        result = TransactionCreator.call(
          user: user,
          phone_number: customer.phone_number,
          fuel_amount: 250,
          vehicle_id: vehicle.id,
          fuel_pump_nozzle_id: petrol_nozzle.id
        )

        assert_equal 0, result.points_earned
        assert_equal true, result.rewards_paused
      end
    end
  end

  test "uses vehicle type reward rate overrides when present" do
    user = User.create!(name: "Staff Vehicle Reward", username: "staff_vehicle_reward", phone_number: "9012345678", password: "password123", password_confirmation: "password123", role: :staff)
    petrol_nozzle, = assign_pump_to_user(user)
    vehicle_types(:two_wheeler).update!(reward_points_per_100: 4)
    customer = Customer.create!(name: "Ravi Override", phone_number: "9876501111")
    vehicle = customer.vehicles.create!(vehicle_number: "TN01CD1234", fuel_type: :petrol, vehicle_kind: :two_wheeler)

    result = TransactionCreator.call(
      user: user,
      phone_number: customer.phone_number,
      fuel_amount: 550,
      vehicle_id: vehicle.id,
      fuel_pump_nozzle_id: petrol_nozzle.id
    )

    assert_equal 20, result.points_earned
    assert_equal 20, result.customer.reload.total_points
  end

  test "rejects transactions for inactive customers" do
    user = User.create!(name: "Staff Inactive", username: "staff_inactive", phone_number: "9022222222", password: "password123", password_confirmation: "password123", role: :staff)
    petrol_nozzle, = assign_pump_to_user(user)
    customer = Customer.create!(name: "Mohan", phone_number: "9876500000", active: false)
    vehicle = customer.vehicles.create!(vehicle_number: "TN10AB4321", fuel_type: :diesel, vehicle_kind: :lmv)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      TransactionCreator.call(
        user: user,
        phone_number: customer.phone_number,
        fuel_amount: 500,
        vehicle_id: vehicle.id,
        fuel_pump_nozzle_id: petrol_nozzle.id
      )
    end

    assert_includes error.record.errors.full_messages, "Customer must be active to record transactions"
  end

  test "rejects transactions when the phone number is not 10 digits" do
    user = User.create!(name: "Staff Invalid Phone", username: "staff_invalid_phone", phone_number: "9033333333", password: "password123", password_confirmation: "password123", role: :staff)
    petrol_nozzle, = assign_pump_to_user(user)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      TransactionCreator.call(
        user: user,
        phone_number: "12345",
        fuel_amount: 500,
        vehicle_id: vehicles(:one).id,
        fuel_pump_nozzle_id: petrol_nozzle.id
      )
    end

    assert_includes error.record.errors.full_messages, "Phone number must be a 10 digit number"
  end

  test "creates a transaction and ledger entry when recording by vehicle number" do
    user = User.create!(name: "Staff Vehicle Lookup", username: "staff_vehicle_lookup", phone_number: "9044444444", password: "password123", password_confirmation: "password123", role: :staff)
    _, diesel_nozzle = assign_pump_to_user(user)
    customer = Customer.create!(name: "Priya", phone_number: "9765432109")
    vehicle = customer.vehicles.create!(vehicle_number: "KA01AB1234", fuel_type: :diesel, vehicle_kind: :lmv)

    assert_difference -> { Transaction.count }, 1 do
      assert_difference -> { PointsLedger.count }, 1 do
        result = TransactionCreator.call(
          user: user,
          lookup_mode: "vehicle",
          vehicle_number: "KA 01 AB 1234",
          vehicle_id: vehicle.id,
          fuel_amount: 900,
          fuel_pump_nozzle_id: diesel_nozzle.id
        )

        assert_equal customer, result.customer
        assert_equal vehicle, result.transaction.vehicle
        assert_equal 9, result.points_earned
      end
    end
  end

  test "rejects vehicle lookup when the vehicle number is invalid" do
    user = User.create!(name: "Staff Invalid Vehicle", username: "staff_invalid_vehicle", phone_number: "9055555555", password: "password123", password_confirmation: "password123", role: :staff)
    petrol_nozzle, = assign_pump_to_user(user)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      TransactionCreator.call(
        user: user,
        lookup_mode: "vehicle",
        vehicle_number: "invalid-vehicle",
        vehicle_id: vehicles(:one).id,
        fuel_amount: 500,
        fuel_pump_nozzle_id: petrol_nozzle.id
      )
    end

    assert_includes error.record.errors.full_messages, "Vehicle number is invalid"
  end

  test "rejects vehicle lookup when the selected vehicle does not match the entered number" do
    user = User.create!(name: "Staff Vehicle Mismatch", username: "staff_vehicle_mismatch", phone_number: "9066666666", password: "password123", password_confirmation: "password123", role: :staff)
    petrol_nozzle, = assign_pump_to_user(user)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      TransactionCreator.call(
        user: user,
        lookup_mode: "vehicle",
        vehicle_number: vehicles(:three).vehicle_number,
        vehicle_id: vehicles(:one).id,
        fuel_amount: 500,
        fuel_pump_nozzle_id: petrol_nozzle.id
      )
    end

    assert_includes error.record.errors.full_messages, "Vehicle must match the entered vehicle number"
  end

  test "records a transaction for the selected customer when multiple customers share a vehicle number" do
    user = User.create!(name: "Staff Shared Vehicle", username: "staff_shared_vehicle", phone_number: "9077777777", password: "password123", password_confirmation: "password123", role: :staff)
    _, diesel_nozzle = assign_pump_to_user(user)
    other_customer = Customer.create!(name: "Shared Vehicle Owner", phone_number: "9888888888")
    duplicate_vehicle = other_customer.vehicles.create!(
      vehicle_number: vehicles(:one).vehicle_number,
      fuel_type: :diesel,
      vehicle_kind: :lmv
    )

    assert_difference -> { Transaction.count }, 1 do
      result = TransactionCreator.call(
        user: user,
        lookup_mode: "vehicle",
        vehicle_number: vehicles(:one).vehicle_number,
        vehicle_id: duplicate_vehicle.id,
        fuel_amount: 500,
        fuel_pump_nozzle_id: diesel_nozzle.id
      )

      assert_equal other_customer, result.customer
      assert_equal duplicate_vehicle, result.transaction.vehicle
      assert_equal other_customer.id, result.transaction.customer_id
    end
  end

  test "rejects transactions when the selected nozzle does not match the vehicle fuel type" do
    user = User.create!(name: "Staff Fuel Mismatch", username: "staff_fuel_mismatch", phone_number: "9088888888", password: "password123", password_confirmation: "password123", role: :staff)
    _, diesel_nozzle = assign_pump_to_user(user)
    customer = Customer.create!(name: "Mismatch User", phone_number: "9898989898")
    vehicle = customer.vehicles.create!(vehicle_number: "TN11AB1234", fuel_type: :petrol, vehicle_kind: :lmv)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      TransactionCreator.call(
        user: user,
        phone_number: customer.phone_number,
        vehicle_id: vehicle.id,
        fuel_amount: 400,
        fuel_pump_nozzle_id: diesel_nozzle.id
      )
    end

    assert_includes error.record.errors.full_messages, "Fuel pump nozzle must match the selected vehicle's fuel type"
  end

  test "accepts a matching nozzle when the vehicle stores a legacy mixed-case fuel type" do
    user = User.create!(name: "Staff Legacy Fuel", username: "staff_legacy_fuel", phone_number: "9099999999", password: "password123", password_confirmation: "password123", role: :staff)
    petrol_nozzle, = assign_pump_to_user(user)
    customer = Customer.create!(name: "Legacy Fuel User", phone_number: "9876501234")
    vehicle = customer.vehicles.create!(vehicle_number: "TN12AB1234", fuel_type: :petrol, vehicle_kind: :lmv)
    vehicle.update_column(:fuel_type, "Petrol")

    assert_difference -> { Transaction.count }, 1 do
      assert_difference -> { PointsLedger.count }, 1 do
        result = TransactionCreator.call(
          user: user,
          phone_number: customer.phone_number,
          vehicle_id: vehicle.id,
          fuel_amount: 400,
          fuel_pump_nozzle_id: petrol_nozzle.id
        )

        assert_equal vehicle, result.transaction.vehicle
        assert_equal petrol_nozzle, result.transaction.fuel_pump_nozzle
      end
    end
  end

  private

  def assign_pump_to_user(user)
    fuel_pump = FuelPump.create!(
      active: true,
      nozzles_attributes: [
        { fuel_type_code: "petrol", active: true },
        { fuel_type_code: "diesel", active: true }
      ]
    )

    petrol_nozzle = fuel_pump.nozzles.find_by!(fuel_type_code: "petrol")
    diesel_nozzle = fuel_pump.nozzles.find_by!(fuel_type_code: "diesel")

    user.update!(
      fuel_pump_id: fuel_pump.id,
      assigned_fuel_pump_nozzle_ids: [petrol_nozzle.id, diesel_nozzle.id]
    )

    [petrol_nozzle, diesel_nozzle]
  end
end
