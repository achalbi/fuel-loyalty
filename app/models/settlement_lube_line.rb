class SettlementLubeLine < ApplicationRecord
  # D2 — a lube/oil/AdBlue line sold in the shift. Amount = quantity × unit_price
  # (both snapshotted at capture). Opening/closing stock are optional movement.
  belongs_to :daily_settlement
  belongs_to :product

  before_validation :recompute

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :opening_stock, :closing_stock,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  private

  def recompute
    self.quantity = 0 if quantity.blank?
    self.product_name_snapshot = product.display_name if product && product_name_snapshot.blank?
    self.unit_price = product.selling_price if unit_price.blank? && product
    self.amount = (quantity.to_i * unit_price.to_d).round(2) if unit_price
  end
end
