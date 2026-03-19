class PointsLedger < ApplicationRecord
  belongs_to :customer
  belongs_to :fuel_transaction, class_name: "Transaction", foreign_key: :transaction_id, optional: true

  enum :entry_type, { earn: 0, redeem: 1, expire: 2, adjust: 3 }, validate: true

  validates :points, numericality: { only_integer: true }
  validates :entry_type, presence: true
end
