class SettlementCreditLine < ApplicationRecord
  # D5 — a Fleet/OTP or tank-truck credit line (e.g. "OTP 136 Lts NL-01/AE-2471").
  # `amount` is the ₹ value that reduces the cash to settle; captured directly
  # since a credit may be priced off-catalog.
  enum :credit_type, { fleet_otp: 0, tank_truck: 1 }, default: :fleet_otp, validate: true

  belongs_to :daily_settlement

  before_validation :normalize

  validates :litres, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  private

  def normalize
    self.litres = 0 if litres.blank?
    self.discount_amount = 0 if discount_amount.blank?
    self.amount = 0 if amount.blank?
  end
end
