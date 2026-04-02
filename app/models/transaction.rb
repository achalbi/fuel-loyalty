class Transaction < ApplicationRecord
  belongs_to :customer
  belongs_to :user
  belongs_to :vehicle
  belongs_to :fuel_pump, optional: true
  belongs_to :fuel_pump_nozzle, optional: true

  has_one :points_ledger, foreign_key: :transaction_id, dependent: :restrict_with_exception

  enum :payment_mode, { cash: "cash", credit: "credit" }, default: :cash

  validates :vehicle, presence: true
  validates :fuel_amount, numericality: { greater_than: 0 }
  validates :payment_mode, presence: true
end
