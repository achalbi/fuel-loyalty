class TransactionCreator
  Result = Struct.new(:customer, :transaction, :points_earned, :rewards_paused, keyword_init: true)

  def self.call(...)
    new(...).call
  end

  def initialize(user:, vehicle_id:, fuel_amount: nil, litres: nil, discount_amount: 0, fuel_pump_nozzle_id: nil, fuel_pump_id: nil, lookup_mode: "phone", phone_number: nil, vehicle_number: nil, payment_mode: "cash")
    @user = user
    @lookup_mode = lookup_mode
    @phone_number = phone_number
    @vehicle_number = vehicle_number
    @fuel_amount = fuel_amount
    @litres = litres
    @discount_amount = discount_amount
    @vehicle_id = vehicle_id
    @fuel_pump_id = fuel_pump_id
    @fuel_pump_nozzle_id = fuel_pump_nozzle_id
    @payment_mode = payment_mode
  end

  def call
    result = ActiveRecord::Base.transaction do
      customer, vehicle = resolve_customer_and_vehicle!
      fuel_pump, fuel_pump_nozzle = resolve_fuel_pump_and_nozzle!(vehicle)
      validated_payment_mode = resolve_payment_mode!

      amount = resolve_amount!(vehicle)

      transaction = customer.transactions.create!(
        user: user,
        vehicle: vehicle,
        fuel_amount: amount[:net],
        litres: amount[:litres],
        selling_price_snapshot: amount[:snapshot],
        gross_amount: amount[:gross],
        discount_amount: amount[:discount],
        amount_source: amount[:source],
        product: amount[:product],
        payment_mode: validated_payment_mode,
        fuel_pump: fuel_pump,
        fuel_pump_nozzle: fuel_pump_nozzle
      )
      rewards_paused = customer.rewards_paused? || RewardSetting.current.rewards_paused?
      if rewards_paused
        points = 0
      else
        points = PointsCalculator.call(amount[:net], fuel_type: vehicle.fuel_type, vehicle_kind: vehicle.vehicle_kind, litres: amount[:litres])

        customer.points_ledgers.create!(
          fuel_transaction: transaction,
          points: points,
          entry_type: :earn
        )
      end

      Result.new(customer: customer, transaction: transaction, points_earned: points, rewards_paused: rewards_paused)
    end

    # F3 — after the ledger row commits, fire an auto loyalty-milestone
    # notification if this transaction crossed a new points rung. Never let a
    # notification failure roll back or break the recorded transaction.
    if result.points_earned.to_i.positive?
      LoyaltyMilestoneNotifier.call(result.customer)
    end

    result
  end

  private

  attr_reader :fuel_amount, :fuel_pump_id, :fuel_pump_nozzle_id, :lookup_mode, :payment_mode, :phone_number, :user, :vehicle_id, :vehicle_number

  # Litres are the source of truth (LOCKED Q1): when litres are given, ₹ is
  # derived from the catalog selling price; otherwise fall back to a typed ₹
  # amount (legacy/admin). Returns the columns to persist on the transaction.
  def resolve_amount!(vehicle)
    if @litres.present?
      litres = BigDecimal(@litres.to_s)
      invalid!("Litres must be greater than zero.") unless litres.positive?

      snapshot = FuelPricing.current_price(vehicle.fuel_type)
      invalid!("No selling price is configured for #{FuelType.label_for(vehicle.fuel_type)}. Set it in Products.") if snapshot.blank?
      snapshot = BigDecimal(snapshot.to_s)

      gross = (litres * snapshot).round(2)
      discount = resolve_discount!(gross)
      net = gross - discount

      {
        litres: litres, snapshot: snapshot, gross: gross, discount: discount, net: net,
        source: :derived, product: Product.active.fuel.find_by(fuel_type_code: vehicle.fuel_type)
      }
    else
      invalid!("Fuel amount must be greater than zero.") if @fuel_amount.blank? || BigDecimal(@fuel_amount.to_s) <= 0
      # A typed ₹ amount is the gross the meter showed; any discount given at the
      # counter comes off it, so points are earned on what the customer paid.
      gross = BigDecimal(@fuel_amount.to_s)
      discount = resolve_discount!(gross)

      { litres: nil, snapshot: nil, gross: gross, discount: discount, net: gross - discount, source: :manual_amount, product: nil }
    end
  end

  def resolve_discount!(gross)
    discount = BigDecimal((@discount_amount.presence || 0).to_s)
    invalid!("Discount cannot be negative.") if discount.negative?
    invalid!("Discount cannot exceed the fuel amount.") if (gross - discount) <= 0

    discount
  end

  def invalid!(message)
    record = Transaction.new
    record.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, record
  end

  def resolve_customer_and_vehicle!
    if vehicle_lookup?
      vehicle = find_vehicle_by_lookup!
      customer = vehicle.customer
      ensure_customer_active!(customer)
      [customer, vehicle]
    else
      customer = find_customer!
      vehicle = find_vehicle_for!(customer)
      [customer, vehicle]
    end
  end

  def vehicle_lookup?
    lookup_mode.to_s == "vehicle"
  end

  def find_customer!
    validate_phone_number!

    customer = Customer.find_by!(phone_number: normalized_phone_number)
    ensure_customer_active!(customer)
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordInvalid.new(Customer.new(phone_number: phone_number).tap { |customer| customer.errors.add(:phone_number, "was not found") })
  end

  def ensure_customer_active!(customer)
    return customer if customer.active?

    raise ActiveRecord::RecordInvalid.new(customer.tap { |record| record.errors.add(:base, "Customer must be active to record transactions") })
  end

  def validate_phone_number!
    return if Customer.valid_phone_number?(phone_number)

    raise ActiveRecord::RecordInvalid.new(
      Customer.new(phone_number: normalized_phone_number.presence || phone_number).tap do |customer|
        customer.errors.add(:phone_number, Customer::PHONE_NUMBER_ERROR_MESSAGE)
      end
    )
  end

  def normalized_phone_number
    @normalized_phone_number ||= Customer.normalize_phone_number(phone_number)
  end

  def validate_vehicle_number!
    return if Vehicle.valid_vehicle_number?(vehicle_number)

    raise ActiveRecord::RecordInvalid.new(
      Vehicle.new(vehicle_number: normalized_vehicle_number.presence || vehicle_number).tap do |vehicle|
        vehicle.errors.add(:vehicle_number, "is invalid")
      end
    )
  end

  def normalized_vehicle_number
    @normalized_vehicle_number ||= Vehicle.normalize_vehicle_number(vehicle_number)
  end

  def find_vehicle_by_lookup!
    validate_vehicle_number!

    vehicle = Vehicle.includes(:customer).find(vehicle_id)

    return vehicle if vehicle.vehicle_number == normalized_vehicle_number

    raise ActiveRecord::RecordInvalid.new(
      Transaction.new.tap do |transaction|
        transaction.errors.add(:vehicle, "must match the entered vehicle number")
      end
    )
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordInvalid.new(
      Transaction.new.tap do |transaction|
        transaction.errors.add(:vehicle, "must be selected from the matched customer list")
      end
    )
  end

  def find_vehicle_for!(customer)
    customer.vehicles.find(vehicle_id)
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordInvalid.new(Transaction.new.tap { |transaction| transaction.errors.add(:vehicle, "must belong to the selected customer") })
  end

  # Only an admin can reach My Pump (S-MYPUMP), so only an admin is told to use it.
  def unassigned_pump_message
    if user.admin?
      "Set up My Pump with at least one active nozzle before recording a transaction"
    else
      "Ask an admin to assign your pump with at least one active nozzle before recording a transaction"
    end
  end

  def resolve_fuel_pump_and_nozzle!(vehicle)
    return resolve_selected_pump! unless RewardSetting.current.nozzle_feature_enabled?

    fuel_pump = user.transaction_fuel_pump

    unless fuel_pump
      raise ActiveRecord::RecordInvalid.new(
        Transaction.new.tap do |transaction|
          # S-MYPUMP: staff can no longer self-assign, so don't tell them to.
          transaction.errors.add(:base, unassigned_pump_message)
        end
      )
    end

    fuel_pump_nozzle = user.transaction_fuel_pump_nozzles.find_by(id: fuel_pump_nozzle_id)

    unless fuel_pump_nozzle
      raise ActiveRecord::RecordInvalid.new(
        Transaction.new.tap do |transaction|
          transaction.errors.add(:fuel_pump_nozzle, "must be selected from your assigned nozzles")
        end
      )
    end

    if normalized_fuel_type_code(fuel_pump_nozzle.fuel_type_code) != normalized_fuel_type_code(vehicle.fuel_type)
      raise ActiveRecord::RecordInvalid.new(
        Transaction.new.tap do |transaction|
          transaction.errors.add(:fuel_pump_nozzle, "must match the selected vehicle's fuel type")
        end
      )
    end

    [fuel_pump, fuel_pump_nozzle]
  end

  def resolve_selected_pump!
    fuel_pump = FuelPump.active.find_by(id: fuel_pump_id)

    unless fuel_pump
      raise ActiveRecord::RecordInvalid.new(
        Transaction.new.tap do |transaction|
          transaction.errors.add(:fuel_pump, "must be selected from active pumps")
        end
      )
    end

    [fuel_pump, nil]
  end

  def normalized_fuel_type_code(value)
    value.to_s.parameterize(separator: "_").presence
  end

  def resolve_payment_mode!
    normalized_payment_mode = payment_mode.to_s
    return normalized_payment_mode if Transaction.payment_modes.key?(normalized_payment_mode)

    raise ActiveRecord::RecordInvalid.new(
      Transaction.new.tap do |transaction|
        transaction.errors.add(:payment_mode, "must be cash or credit")
      end
    )
  end
end
