class TransactionCreator
  Result = Struct.new(:customer, :transaction, :points_earned, keyword_init: true)

  def self.call(...)
    new(...).call
  end

  def initialize(user:, fuel_amount:, vehicle_id:, lookup_mode: "phone", phone_number: nil, vehicle_number: nil)
    @user = user
    @lookup_mode = lookup_mode
    @phone_number = phone_number
    @vehicle_number = vehicle_number
    @fuel_amount = fuel_amount
    @vehicle_id = vehicle_id
  end

  def call
    ActiveRecord::Base.transaction do
      customer, vehicle = resolve_customer_and_vehicle!

      transaction = customer.transactions.create!(user: user, vehicle: vehicle, fuel_amount: fuel_amount)
      points = PointsCalculator.call(fuel_amount, fuel_type: vehicle.fuel_type)

      customer.points_ledgers.create!(
        fuel_transaction: transaction,
        points: points,
        entry_type: :earn
      )

      Result.new(customer: customer, transaction: transaction, points_earned: points)
    end
  end

  private

  attr_reader :fuel_amount, :lookup_mode, :phone_number, :user, :vehicle_id, :vehicle_number

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
end
