class PointsLedger < ApplicationRecord
  belongs_to :customer
  belongs_to :fuel_transaction, class_name: "Transaction", foreign_key: :transaction_id, optional: true

  enum :entry_type, { earn: 0, redeem: 1, expire: 2, adjust: 3 }, validate: true

  before_validation :snapshot_cash_reward_amount, on: :create

  validates :cash_reward_amount,
    numericality: {
      greater_than_or_equal_to: 0
    },
    allow_nil: true,
    if: :supports_cash_reward_amount?
  validates :points, numericality: { only_integer: true }
  validates :entry_type, presence: true

  def recorded_cash_reward?
    recorded_cash_reward_amount.present?
  end

  def recorded_cash_reward_amount
    return nil unless supports_cash_reward_amount?

    self[:cash_reward_amount]
  end

  private

  def snapshot_cash_reward_amount
    return unless supports_cash_reward_amount?
    return if self[:cash_reward_amount].present?

    self[:cash_reward_amount] = RewardSetting.current.cash_value_for_points(points.to_i.abs)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    self[:cash_reward_amount] = nil if supports_cash_reward_amount?
  end

  def supports_cash_reward_amount?
    self.class.attribute_names.include?("cash_reward_amount")
  end
end
