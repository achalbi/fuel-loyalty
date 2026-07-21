class SettlementCashDenomination < ApplicationRecord
  # D7 — one row per denomination present in the counted cash. amount = denom ×
  # qty (derived). counted_cash = Σ amount; shortage = final − counted (parent).
  DENOMINATIONS = [500, 200, 100, 50, 20, 10, 5].freeze

  belongs_to :daily_settlement

  before_validation :recompute

  validates :denomination, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def recompute
    self.quantity = 0 if quantity.blank?
    self.amount = (denomination.to_i * quantity.to_i) if denomination.present?
  end
end
