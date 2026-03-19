class TransactionCreator
  Result = Struct.new(:customer, :transaction, :points_earned, keyword_init: true)

  def self.call(...)
    new(...).call
  end

  def initialize(user:, phone_number:, fuel_amount:, vehicle_id:)
    @user = user
    @phone_number = phone_number
    @fuel_amount = fuel_amount
    @vehicle_id = vehicle_id
  end

  def call
    ActiveRecord::Base.transaction do
      customer = find_customer!
      vehicle = find_vehicle_for!(customer)

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

  attr_reader :fuel_amount, :phone_number, :user, :vehicle_id

  def find_customer!
    customer = Customer.find_by!(phone_number: Customer.normalize_phone_number(phone_number))
    return customer if customer.active?

    raise ActiveRecord::RecordInvalid.new(customer.tap { |record| record.errors.add(:base, "Customer must be active to record transactions") })
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordInvalid.new(Customer.new(phone_number: phone_number).tap { |customer| customer.errors.add(:phone_number, "was not found") })
  end

  def find_vehicle_for!(customer)
    customer.vehicles.find(vehicle_id)
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordInvalid.new(Transaction.new.tap { |transaction| transaction.errors.add(:vehicle, "must belong to the selected customer") })
  end
end
