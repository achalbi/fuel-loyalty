class SettlementDigitalReceipt < ApplicationRecord
  # D6 — one digital-payment means collected during the shift (PhonePe POS,
  # PhonePe Scanner, PAYTM, …) and its ₹ total. Free-form so staff can add a
  # means without waiting on a release; the two PhonePe rows are seeded on every
  # draft because they are entered every day.
  DEFAULT_LABELS = [ "PhonePe POS", "PhonePe Scanner" ].freeze

  belongs_to :daily_settlement

  before_validation :normalize

  validates :label, presence: true, length: { maximum: 60 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :label, uniqueness: { scope: :daily_settlement_id, case_sensitive: false,
                                  message: "already has a line on this settlement" }

  private

  def normalize
    self.label = label.to_s.strip.squeeze(" ").presence
    self.amount = 0 if amount.blank?
  end
end
