class RewardSetting < ApplicationRecord
  DEFAULT_MINIMUM_REDEEMABLE_POINTS = 100
  DEFAULT_RUPEES_PER_REWARD_UNIT = 100

  before_validation :normalize_cash_value_per_point
  before_validation :normalize_minimum_redeemable_points
  before_validation :normalize_rupees_per_reward_unit
  before_validation :assign_default_cash_value_per_point
  before_validation :assign_default_rupees_per_reward_unit

  validates :cash_value_per_point,
    numericality: {
      greater_than_or_equal_to: 0
    },
    allow_nil: true
  validates :minimum_redeemable_points,
    numericality: {
      only_integer: true,
      greater_than: 0
    },
    allow_nil: true
  validates :rupees_per_reward_unit,
    numericality: {
      only_integer: true,
      greater_than: 0
    }

  def self.current
    first_or_initialize.tap do |reward_setting|
      reward_setting.cash_value_per_point = nil if reward_setting.cash_value_per_point.blank?
      reward_setting.minimum_redeemable_points = nil if reward_setting.minimum_redeemable_points.blank?
      reward_setting.rupees_per_reward_unit ||= DEFAULT_RUPEES_PER_REWARD_UNIT
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    new(cash_value_per_point: nil, minimum_redeemable_points: nil, rupees_per_reward_unit: DEFAULT_RUPEES_PER_REWARD_UNIT)
  end

  def cash_reward_configured?
    cash_value_per_point.present? && cash_value_per_point.positive?
  end

  def minimum_redeemable_points_configured?
    minimum_redeemable_points.present? && minimum_redeemable_points.positive?
  end

  def cash_value_for_points(points)
    return nil unless cash_reward_configured?

    BigDecimal(points.to_s) * BigDecimal(cash_value_per_point.to_s)
  end

  def effective_minimum_redeemable_points(fallback: DEFAULT_MINIMUM_REDEEMABLE_POINTS)
    minimum_redeemable_points_configured? ? minimum_redeemable_points.to_i : fallback.to_i
  end

  def redemption_increment
    effective_minimum_redeemable_points
  end

  private

  def normalize_cash_value_per_point
    return self.cash_value_per_point = nil if cash_value_per_point.nil?

    normalized_value = cash_value_per_point.to_s.delete(",").squish
    return self.cash_value_per_point = nil if normalized_value.blank?

    self.cash_value_per_point = BigDecimal(normalized_value)
  rescue ArgumentError
    self.cash_value_per_point = cash_value_per_point
  end

  def normalize_minimum_redeemable_points
    normalized_value = minimum_redeemable_points.to_s.delete(",").squish
    self.minimum_redeemable_points = normalized_value.presence&.to_i
  end

  def normalize_rupees_per_reward_unit
    normalized_value = rupees_per_reward_unit.to_s.delete(",").squish
    self.rupees_per_reward_unit = normalized_value.presence&.to_i
  end

  def assign_default_cash_value_per_point
    self.cash_value_per_point = nil if cash_value_per_point.blank?
  end

  def assign_default_rupees_per_reward_unit
    self.rupees_per_reward_unit ||= DEFAULT_RUPEES_PER_REWARD_UNIT
  end
end
