class Transaction < ApplicationRecord
  belongs_to :customer
  belongs_to :user
  belongs_to :vehicle

  has_one :points_ledger, foreign_key: :transaction_id, dependent: :restrict_with_exception

  validates :vehicle, presence: true
  validates :fuel_amount, numericality: { greater_than: 0 }
end
