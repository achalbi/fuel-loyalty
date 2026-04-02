class PointsRedeemer
  DEFAULT_REDEMPTION_INCREMENT = 100
  REDEMPTION_INCREMENT = DEFAULT_REDEMPTION_INCREMENT
  Result = Struct.new(:customer, :points_redeemed, :cash_reward_amount, keyword_init: true)

  def self.call(...)
    new(...).call
  end

  def self.redemption_increment
    RewardSetting.current.redemption_increment
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    DEFAULT_REDEMPTION_INCREMENT
  end

  def self.max_redeemable_points(available_points, minimum_redeemable_points: redemption_increment, redemption_increment: self.redemption_increment)
    normalized_available_points = available_points.to_i
    normalized_increment = [redemption_increment.to_i, 1].max
    normalized_minimum_points = [minimum_redeemable_points.to_i, normalized_increment].max
    return 0 if normalized_available_points < normalized_minimum_points

    (normalized_available_points / normalized_increment) * normalized_increment
  end

  def initialize(phone_number:, points:)
    @phone_number = phone_number
    @points = points
  end

  def call
    customer = find_customer!
    points_to_redeem = normalized_points
    minimum_redeemable_points = customer.minimum_redeemable_points
    redemption_increment = self.class.redemption_increment
    max_redeemable_points = self.class.max_redeemable_points(
      customer.total_points,
      minimum_redeemable_points: minimum_redeemable_points,
      redemption_increment: redemption_increment
    )

    if max_redeemable_points < minimum_redeemable_points
      invalid_redemption!(customer, points_to_redeem, "must have at least #{minimum_redeemable_points} available points to redeem")
    end

    if points_to_redeem <= 0
      invalid_redemption!(customer, points_to_redeem, "must be greater than 0")
    end

    if (points_to_redeem % redemption_increment) != 0
      invalid_redemption!(customer, points_to_redeem, "must be in multiples of #{redemption_increment}")
    end

    if points_to_redeem < minimum_redeemable_points
      invalid_redemption!(customer, points_to_redeem, "must be at least #{minimum_redeemable_points} points")
    end

    if points_to_redeem > max_redeemable_points
      invalid_redemption!(customer, points_to_redeem, "cannot exceed #{max_redeemable_points} redeemable points")
    end

    ledger_entry = customer.points_ledgers.create!(
      points: -points_to_redeem,
      entry_type: :redeem
    )

    Result.new(
      customer: customer,
      points_redeemed: points_to_redeem,
      cash_reward_amount: ledger_entry.recorded_cash_reward_amount
    )
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
