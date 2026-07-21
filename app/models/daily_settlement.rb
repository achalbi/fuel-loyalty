class DailySettlement < ApplicationRecord
  # Phase 2 — the shift-end reconciliation ledger for one pump on one business
  # date/shift (D1–D10). Litres are canonical (LOCKED Q1); ₹ is derived from the
  # A5 catalog price and snapshotted onto each line at capture time. Line-level
  # math lives in the child models' before_validation; the parent aggregates
  # (D6 final amount, D7 shortage) are recomputed by Settlement::Calculator on
  # every save. See docs/acefuels/12-spec-daily-settlement.md.
  enum :status, { draft: 0, submitted: 1, reconciled: 2 }, default: :draft, validate: true

  belongs_to :fuel_pump
  belongs_to :shift_template, optional: true
  belongs_to :recorded_by, class_name: "User"

  has_many :nozzle_readings, class_name: "SettlementNozzleReading", dependent: :destroy, inverse_of: :daily_settlement
  has_many :lube_lines, class_name: "SettlementLubeLine", dependent: :destroy, inverse_of: :daily_settlement
  has_many :discount_lines, class_name: "SettlementDiscountLine", dependent: :destroy, inverse_of: :daily_settlement
  has_many :credit_lines, class_name: "SettlementCreditLine", dependent: :destroy, inverse_of: :daily_settlement
  has_many :cash_denominations, class_name: "SettlementCashDenomination", dependent: :destroy, inverse_of: :daily_settlement
  has_many :stock_receipts, class_name: "SettlementStockReceipt", dependent: :destroy, inverse_of: :daily_settlement
  has_many :decantations, class_name: "SettlementDecantation", dependent: :destroy, inverse_of: :daily_settlement
  has_many :rate_comparisons, class_name: "SettlementRateComparison", dependent: :destroy, inverse_of: :daily_settlement
  has_many :audit_changes, class_name: "SettlementChange", dependent: :destroy, inverse_of: :daily_settlement

  CHILD_ASSOCIATIONS = %i[
    nozzle_readings lube_lines discount_lines credit_lines
    cash_denominations stock_receipts decantations rate_comparisons
  ].freeze

  accepts_nested_attributes_for :nozzle_readings, allow_destroy: true
  accepts_nested_attributes_for :lube_lines, allow_destroy: true, reject_if: :reject_lube_line?
  accepts_nested_attributes_for :discount_lines, allow_destroy: true
  accepts_nested_attributes_for :credit_lines, allow_destroy: true, reject_if: :reject_credit_line?
  accepts_nested_attributes_for :cash_denominations, allow_destroy: true, reject_if: :reject_denomination?
  accepts_nested_attributes_for :stock_receipts, allow_destroy: true, reject_if: :reject_stock_receipt?
  accepts_nested_attributes_for :decantations, allow_destroy: true, reject_if: :reject_decantation?
  accepts_nested_attributes_for :rate_comparisons, allow_destroy: true, reject_if: :reject_rate_comparison?

  before_validation :capture_fsm_snapshot, on: :create
  before_validation :recompute_totals
  before_save :recompute_totals

  validates :business_date, presence: true
  validates :phonepe_pos_amount, :phonepe_scanner_amount, numericality: { greater_than_or_equal_to: 0 }
  validate :shift_window_must_be_unique
  validate :readings_complete_when_submitted

  scope :for_date, ->(date) { where(business_date: date) }
  scope :financial, -> { where(status: %i[submitted reconciled]) }
  scope :recent_first, -> { order(business_date: :desc, created_at: :desc) }

  # Most recent prior closing reading for a nozzle, used to auto-populate the
  # next settlement's opening reading (business rule 1).
  def self.prior_closing_reading(fuel_pump_nozzle_id, business_date)
    SettlementNozzleReading
      .joins(:daily_settlement)
      .merge(DailySettlement.financial)
      .where(fuel_pump_nozzle_id: fuel_pump_nozzle_id)
      .where("daily_settlements.business_date < ?", business_date)
      .order("daily_settlements.business_date DESC, daily_settlements.id DESC")
      .limit(1)
      .pick(:closing_reading)
  end

  def editable_by_fsm?
    draft? && !locked?
  end

  def display_title
    "Settlement · #{fuel_pump&.display_name} · #{business_date}"
  end

  private

  def recompute_totals
    Settlement::Calculator.recompute!(self)
  end

  def capture_fsm_snapshot
    self.fsm_name_snapshot = recorded_by&.display_name if fsm_name_snapshot.blank?
  end

  def reject_lube_line?(attrs)
    attrs["id"].blank? && (attrs["product_id"].blank? || attrs["quantity"].to_i.zero?)
  end

  def reject_credit_line?(attrs)
    attrs["id"].blank? && attrs["litres"].to_d.zero? && attrs["amount"].to_d.zero?
  end

  def reject_denomination?(attrs)
    attrs["id"].blank? && attrs["quantity"].to_i.zero?
  end

  def reject_stock_receipt?(attrs)
    attrs["id"].blank? && (attrs["fuel_type_code"].blank? || attrs["litres_received"].to_d.zero?)
  end

  def reject_decantation?(attrs)
    attrs["id"].blank? && attrs["fuel_type_code"].blank?
  end

  def reject_rate_comparison?(attrs)
    attrs["id"].blank? && (attrs["fuel_type_code"].blank? || attrs["competitor_price"].blank?)
  end

  def shift_window_must_be_unique
    return if fuel_pump_id.blank? || business_date.blank?

    duplicate = self.class.where(fuel_pump_id: fuel_pump_id, business_date: business_date, shift_template_id: shift_template_id)
    duplicate = duplicate.where.not(id: id) if persisted?
    return unless duplicate.exists?

    errors.add(:base, "A settlement has already been recorded for this pump, date and shift.")
  end

  # On submit/reconcile every active nozzle row must have a closing reading and a
  # resolved price; drafts may be partial. (A5 price gap is a hard block.)
  def readings_complete_when_submitted
    return if draft?

    live = nozzle_readings.reject(&:marked_for_destruction?)
    live.each do |reading|
      errors.add(:base, "Enter today's reading for #{reading.nozzle_label}.") if reading.closing_reading.blank?
      if reading.unit_price.blank? || reading.unit_price.to_d.zero?
        errors.add(:base, "No active catalog price for #{reading.fuel_type_code_snapshot.to_s.upcase} — set it in the product catalog first.")
      end
    end
  end
end
