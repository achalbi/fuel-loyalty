class PointsRedeemer
  REDEMPTION_INCREMENT = 100
  Result = Struct.new(:customer, :points_redeemed, keyword_init: true)

  def self.call(...)
    new(...).call
  end

  def self.max_redeemable_points(available_points)
    (available_points.to_i / REDEMPTION_INCREMENT) * REDEMPTION_INCREMENT
  end

  def initialize(phone_number:, points:)
    @phone_number = phone_number
    @points = points
  end

  def call
    customer = find_customer!
    points_to_redeem = normalized_points
    max_redeemable_points = self.class.max_redeemable_points(customer.total_points)

    if max_redeemable_points < REDEMPTION_INCREMENT
      invalid_redemption!(customer, points_to_redeem, "must have at least #{REDEMPTION_INCREMENT} available points to redeem")
    end

    if points_to_redeem <= 0
      invalid_redemption!(customer, points_to_redeem, "must be greater than 0")
    end

    if (points_to_redeem % REDEMPTION_INCREMENT) != 0
      invalid_redemption!(customer, points_to_redeem, "must be in multiples of #{REDEMPTION_INCREMENT}")
    end

    if points_to_redeem > max_redeemable_points
      invalid_redemption!(customer, points_to_redeem, "cannot exceed #{max_redeemable_points} redeemable points")
    end

    customer.points_ledgers.create!(
      points: -points_to_redeem,
      entry_type: :redeem
    )

    Result.new(customer: customer, points_redeemed: points_to_redeem)
  end

  private

  attr_reader :phone_number, :points

  def invalid_redemption!(customer, points_to_redeem, message)
    raise ActiveRecord::RecordInvalid.new(
      build_redeem_record(customer, points_to_redeem).tap do |record|
        record.errors.add(:points, message)
      end
    )
  end

  def build_redeem_record(customer, points_to_redeem)
    customer.points_ledgers.build(points: -points_to_redeem, entry_type: :redeem)
  end

  def find_customer!
    validate_phone_number!

    Customer.find_by!(phone_number: normalized_phone_number)
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordInvalid.new(Customer.new(phone_number: phone_number).tap { |customer| customer.errors.add(:phone_number, "was not found") })
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

  def normalized_points
    points.to_i
  end
end
