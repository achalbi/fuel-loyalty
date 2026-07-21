class SettlementRateComparison < ApplicationRecord
  # D10 — competitor (default JIO-BP) vs own selling price for a fuel. own_price
  # is snapshotted from the catalog when the draft is built.
  belongs_to :daily_settlement

  before_validation :normalize

  validates :fuel_type_code, presence: true
  validates :competitor_price, :own_price,
    numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Signed ₹ gap (own − competitor); positive = we are dearer.
  def price_delta
    return if competitor_price.blank? || own_price.blank?

    (own_price.to_d - competitor_price.to_d).round(2)
  end

  private

  def normalize
    self.fuel_type_code = fuel_type_code.to_s.strip.downcase.presence
    self.competitor_name = competitor_name.to_s.strip.presence || "JIO-BP"
  end
end
