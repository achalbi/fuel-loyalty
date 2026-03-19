class PointsRedeemer
  Result = Struct.new(:customer, :points_redeemed, keyword_init: true)

  def self.call(...)
    new(...).call
  end

  def initialize(phone_number:, points:)
    @phone_number = phone_number
    @points = points
  end

  def call
    customer = find_customer!
    points_to_redeem = normalized_points

    if points_to_redeem <= 0
      raise ActiveRecord::RecordInvalid.new(build_redeem_record(customer, points_to_redeem).tap { |record| record.errors.add(:points, "must be greater than 0") })
    end

    if customer.total_points < points_to_redeem
      raise ActiveRecord::RecordInvalid.new(build_redeem_record(customer, points_to_redeem).tap { |record| record.errors.add(:points, "cannot exceed available points") })
    end

    customer.points_ledgers.create!(
      points: -points_to_redeem,
      entry_type: :redeem
    )

    Result.new(customer: customer, points_redeemed: points_to_redeem)
  end

  private

  attr_reader :phone_number, :points

  def build_redeem_record(customer, points_to_redeem)
    customer.points_ledgers.build(points: -points_to_redeem, entry_type: :redeem)
  end

  def find_customer!
    Customer.find_by!(phone_number: Customer.normalize_phone_number(phone_number))
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordInvalid.new(Customer.new(phone_number: phone_number).tap { |customer| customer.errors.add(:phone_number, "was not found") })
  end

  def normalized_points
    points.to_i
  end
end
