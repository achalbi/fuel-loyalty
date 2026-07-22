class CustomerFeedback < ApplicationRecord
  # E7 — a 1..5 rating (+ optional comment) for a customer, optionally tied to the
  # visit or loyalty transaction it rates. Immutable audit data.
  SOURCES = %w[staff admin sms_reply].freeze
  RATING_RANGE = 1..5

  belongs_to :customer
  # class Transaction; named :fuel_transaction to avoid shadowing ActiveRecord's
  # #transaction (mirrors PointsLedger).
  belongs_to :fuel_transaction, class_name: "Transaction", foreign_key: :transaction_id, optional: true
  belongs_to :visit_entry, optional: true
  belongs_to :recorded_by, class_name: "User", foreign_key: :recorded_by_user_id, optional: true

  before_validation :normalize_source

  validates :rating, presence: true, inclusion: { in: RATING_RANGE, message: "must be between 1 and 5" }
  validates :source, presence: true, inclusion: { in: SOURCES }
  # One feedback per rated artifact (mirrors the partial unique indexes).
  validates :transaction_id, uniqueness: true, allow_nil: true
  validates :visit_entry_id, uniqueness: true, allow_nil: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def source_label
    source.to_s.humanize
  end

  private

  def normalize_source
    self.source = source.to_s.strip.downcase.presence || "staff"
  end
end
