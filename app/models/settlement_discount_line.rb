class SettlementDiscountLine < ApplicationRecord
  # D3 — a same-day customer discount, snapshotted from a B2 visit entry (or a
  # manual line added by the FSM). The snapshot makes a later B2 edit auditable;
  # `discount_amount` reduces the final amount to settle.
  belongs_to :daily_settlement
  belongs_to :visit_entry, optional: true

  before_validation :normalize

  validates :litres, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }

  # Build a snapshot line from a B2 visit entry.
  def self.from_visit_entry(entry)
    new(
      visit_entry: entry,
      transport_name: entry.transport_name,
      litres: entry.litres,
      discount_amount: entry.discount_amount,
      driver_name: entry.driver_name,
      driver_phone_number: entry.driver_phone_number,
      manager_name: entry.manager_name,
      manager_phone_number: entry.manager_phone_number,
      owner_name: entry.owner_name,
      owner_phone_number: entry.owner_phone_number
    )
  end

  private

  def normalize
    self.litres = 0 if litres.blank?
    self.discount_amount = 0 if discount_amount.blank?
  end
end
