class SettlementStockReceipt < ApplicationRecord
  # D8 — fuel (MS/HSD) received during the shift.
  belongs_to :daily_settlement

  before_validation :normalize

  validates :fuel_type_code, presence: true
  validates :litres_received, numericality: { greater_than_or_equal_to: 0 }

  private

  def normalize
    self.fuel_type_code = fuel_type_code.to_s.strip.downcase.presence
    self.litres_received = 0 if litres_received.blank?
  end
end
