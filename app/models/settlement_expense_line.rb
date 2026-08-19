class SettlementExpenseLine < ApplicationRecord
  # D6 — cash taken out of the day's takings before the FSM hands it over: a
  # salary advance, or anything else worth writing down. Free-form description
  # by design (staff feedback item 12); it reduces the Final Amount to Settle so
  # the counted cash still reconciles.
  belongs_to :daily_settlement

  before_validation :normalize

  validates :description, presence: true, length: { maximum: 120 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  private

  def normalize
    self.description = description.to_s.strip.squeeze(" ").presence
    self.amount = 0 if amount.blank?
  end
end
