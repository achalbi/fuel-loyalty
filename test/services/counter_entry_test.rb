require "test_helper"

class CounterEntryTest < ActiveSupport::TestCase
  # Item 2 — one counter capture writes both records, so neither the points
  # ledger (C5) nor the settlement discount pull-through (D3) loses its source.
  setup do
    Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 100)
    @user = User.create!(name: "Counter Cara", username: "counter_cara", phone_number: "9017880001",
                         password: "password123", password_confirmation: "password123", role: :staff)
    @pump, @petrol_nozzle = assign_pump_to_user(@user)
    @customer = Customer.create!(name: "Counter Colin", phone_number: "9876600901")
    @vehicle = @customer.vehicles.create!(vehicle_number: "TN41AB1234", fuel_type: :petrol, vehicle_kind: :two_wheeler)
  end

  test "one capture writes both a visit entry and a loyalty transaction" do
    result = CounterEntry.record(user: @user, params: {
      lookup_mode: "vehicle", vehicle_number: @vehicle.vehicle_number, vehicle_id: @vehicle.id,
      litres: "40", discount_amount: "150", payment_mode: "cash",
      fuel_pump_nozzle_id: @petrol_nozzle.id, transport_name: "NL Roadways", driver_name: "Ravi",
      driver_phone_number: "9000011133", fleet_otp: "1"
    })

    visit = result.visit_entry
    assert_equal BigDecimal("40"), visit.litres
    assert_equal BigDecimal("150"), visit.discount_amount
    assert_equal "NL Roadways", visit.transport_name
    assert visit.fleet_otp
    assert_equal @customer.id, visit.customer_id

    txn = result.transaction
    assert_not_nil txn
    assert_equal visit.transaction_id, txn.id
    assert_equal BigDecimal("4000"), txn.gross_amount   # 40 L × ₹100
    assert_equal BigDecimal("150"), txn.discount_amount
    assert_equal BigDecimal("3850"), txn.fuel_amount
    assert_equal "cash", txn.payment_mode               # explicit, not inferred from Fleet/OTP
    assert result.points_earned.to_i.positive?
  end

  test "a typed rupee amount still produces a visit carrying litres" do
    # Litres stay the source of truth even when the FSM types what the meter
    # showed: ₹ is converted at the catalog price.
    result = CounterEntry.record(user: @user, params: {
      lookup_mode: "vehicle", vehicle_number: @vehicle.vehicle_number, vehicle_id: @vehicle.id,
      fuel_amount: "2500", payment_mode: "cash", fuel_pump_nozzle_id: @petrol_nozzle.id
    })

    assert_equal BigDecimal("25"), result.visit_entry.litres # 2500 ÷ 100
    assert_equal BigDecimal("2500"), result.transaction.gross_amount
  end

  test "the captured driver becomes a customer contact" do
    assert_difference -> { @customer.customer_contacts.count }, 1 do
      CounterEntry.record(user: @user, params: {
        lookup_mode: "vehicle", vehicle_number: @vehicle.vehicle_number, vehicle_id: @vehicle.id,
        litres: "10", fuel_pump_nozzle_id: @petrol_nozzle.id,
        driver_name: "Suresh", driver_phone_number: "9000011144"
      })
    end

    contact = @customer.customer_contacts.order(:id).last
    assert_equal "driver", contact.role
    assert_equal "Suresh", contact.name
  end

  test "an unregistered plate records the visit without a transaction" do
    result = CounterEntry.record(user: @user, params: {
      lookup_mode: "vehicle", vehicle_number: "TN99ZZ9999", litres: "12",
      fuel_type_code: "petrol", fuel_pump_nozzle_id: @petrol_nozzle.id
    })

    assert_equal "TN99ZZ9999", result.visit_entry.vehicle_number
    assert_nil result.visit_entry.customer_id
    assert_nil result.transaction
    assert_nil result.points_earned
  end

  test "the phone-lookup path fills the plate in from the chosen vehicle" do
    result = CounterEntry.record(user: @user, params: {
      lookup_mode: "phone", phone_number: @customer.phone_number, vehicle_id: @vehicle.id,
      litres: "5", fuel_pump_nozzle_id: @petrol_nozzle.id
    })

    assert_equal @vehicle.vehicle_number, result.visit_entry.vehicle_number
    assert_equal @vehicle.id, result.visit_entry.vehicle_id
  end

  test "nothing is written when the transaction is rejected" do
    # The pair is atomic: a discount that swallows the sale must not leave a
    # visit entry behind.
    assert_no_difference [-> { VisitEntry.count }, -> { Transaction.count }] do
      assert_raises(ActiveRecord::RecordInvalid) do
        CounterEntry.record(user: @user, params: {
          lookup_mode: "vehicle", vehicle_number: @vehicle.vehicle_number, vehicle_id: @vehicle.id,
          litres: "10", discount_amount: "5000", fuel_pump_nozzle_id: @petrol_nozzle.id
        })
      end
    end
  end

  test "a paused customer still gets the visit and the transaction, minus points" do
    @customer.update!(rewards_paused: true)

    result = CounterEntry.record(user: @user, params: {
      lookup_mode: "vehicle", vehicle_number: @vehicle.vehicle_number, vehicle_id: @vehicle.id,
      litres: "10", fuel_pump_nozzle_id: @petrol_nozzle.id
    })

    assert result.rewards_paused
    assert_equal 0, result.points_earned
    assert_not_nil result.transaction
    assert_not_nil result.visit_entry
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
    user.update!(fuel_pump_id: fuel_pump.id, assigned_fuel_pump_nozzle_ids: fuel_pump.nozzles.pluck(:id))
    [fuel_pump, petrol_nozzle]
  end
end
