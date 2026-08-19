class SettlementCreditLine < ApplicationRecord
  # D5 — a credit line (e.g. "OTP 136 Lts NL-01/AE-2471"). `amount` is the ₹
  # value that reduces the cash to settle; captured directly since a credit may
  # be priced off-catalog.
  #
  # The type mirrors the three Customer account types (Customer::CUSTOMER_TYPES)
  # so a credit line reads the same way as the customer it belongs to. The wire
  # value stays `fleet_otp` rather than Customer's `otp` because installed app
  # builds already post it. The retired `tank_truck` (1) rows were migrated to
  # `credit`.
  CREDIT_TYPES = { fleet_otp: 0, drive_in: 2, credit: 3 }.freeze
  # Display order and wording as requested by FSM staff.
  CREDIT_TYPE_LABELS = { "drive_in" => "Drive-In", "credit" => "Credit", "fleet_otp" => "Fleet/OTP" }.freeze

  enum :credit_type, CREDIT_TYPES, default: :fleet_otp, validate: true

  def self.credit_type_options
    CREDIT_TYPE_LABELS.map { |code, label| [label, code] }
  end

  def credit_type_label
    CREDIT_TYPE_LABELS.fetch(credit_type.to_s) { credit_type.to_s.humanize }
  end

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
