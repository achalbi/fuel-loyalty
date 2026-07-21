class Transaction < ApplicationRecord
  belongs_to :customer
  belongs_to :user
  belongs_to :vehicle
  belongs_to :fuel_pump, optional: true
  belongs_to :fuel_pump_nozzle, optional: true
  belongs_to :product, optional: true

  has_one :points_ledger, foreign_key: :transaction_id, dependent: :restrict_with_exception

  enum :payment_mode, { cash: "cash", credit: "credit" }, default: :cash
  # How fuel_amount (net ₹) was arrived at, so reports/UI can trust litres.
  enum :amount_source, { derived: 0, legacy_amount: 1, manual_amount: 2 }, default: :derived, prefix: :source

  validates :vehicle, presence: true
  validates :fuel_amount, numericality: { greater_than: 0 }
  validates :litres, numericality: { greater_than: 0 }, allow_nil: true
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_mode, presence: true
end
