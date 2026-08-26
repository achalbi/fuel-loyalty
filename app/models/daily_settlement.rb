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
  # Who actually keyed the settlement in. Equal to recorded_by for a normal FSM
  # entry; an admin entering for someone else is the case worth spotting.
  belongs_to :entered_by, class_name: "User", optional: true

  has_many :nozzle_readings, class_name: "SettlementNozzleReading", dependent: :destroy, inverse_of: :daily_settlement
  has_many :lube_lines, class_name: "SettlementLubeLine", dependent: :destroy, inverse_of: :daily_settlement
  has_many :discount_lines, class_name: "SettlementDiscountLine", dependent: :destroy, inverse_of: :daily_settlement
  has_many :credit_lines, class_name: "SettlementCreditLine", dependent: :destroy, inverse_of: :daily_settlement
  has_many :cash_denominations, class_name: "SettlementCashDenomination", dependent: :destroy, inverse_of: :daily_settlement
  has_many :digital_receipts, class_name: "SettlementDigitalReceipt", dependent: :destroy, inverse_of: :daily_settlement
  has_many :expense_lines, class_name: "SettlementExpenseLine", dependent: :destroy, inverse_of: :daily_settlement
  has_many :stock_receipts, class_name: "SettlementStockReceipt", dependent: :destroy, inverse_of: :daily_settlement
  has_many :decantations, class_name: "SettlementDecantation", dependent: :destroy, inverse_of: :daily_settlement
  has_many :rate_comparisons, class_name: "SettlementRateComparison", dependent: :destroy, inverse_of: :daily_settlement
  has_many :audit_changes, class_name: "SettlementChange", dependent: :destroy, inverse_of: :daily_settlement

  CHILD_ASSOCIATIONS = %i[
    nozzle_readings lube_lines discount_lines credit_lines
    cash_denominations digital_receipts expense_lines
    stock_receipts decantations rate_comparisons
  ].freeze

  accepts_nested_attributes_for :nozzle_readings, allow_destroy: true
  accepts_nested_attributes_for :lube_lines, allow_destroy: true, reject_if: :reject_lube_line?
  accepts_nested_attributes_for :discount_lines, allow_destroy: true, reject_if: :reject_discount_line?
  accepts_nested_attributes_for :credit_lines, allow_destroy: true, reject_if: :reject_credit_line?
  accepts_nested_attributes_for :cash_denominations, allow_destroy: true, reject_if: :reject_denomination?
  accepts_nested_attributes_for :digital_receipts, allow_destroy: true, reject_if: :reject_digital_receipt?
  accepts_nested_attributes_for :expense_lines, allow_destroy: true, reject_if: :reject_expense_line?
  accepts_nested_attributes_for :stock_receipts, allow_destroy: true, reject_if: :reject_stock_receipt?
  accepts_nested_attributes_for :decantations, allow_destroy: true, reject_if: :reject_decantation?
  accepts_nested_attributes_for :rate_comparisons, allow_destroy: true, reject_if: :reject_rate_comparison?

  before_validation :capture_fsm_snapshot, on: :create
  before_validation :recompute_totals
  before_save :recompute_totals

  validates :business_date, presence: true
  validate :shift_window_must_be_unique
  validate :readings_complete_when_submitted
  validate :keyed_child_rows_are_distinct

  scope :for_date, ->(date) { where(business_date: date) }
  scope :financial, -> { where(status: %i[submitted reconciled]) }
  scope :recent_first, -> { order(business_date: :desc, created_at: :desc) }

  # A pump has no name of its own — `display_name` is "Pump <sequence_number>" —
  # so a text search can only reach one through its number. Match that number
  # only when the WHOLE query is it ("3", "pump 3"): reading the first digit run
  # out of any free-text query turns a reference like "NL-01/AE-2471" into "give
  # me everything Pump 1 ever filed", which is not what was typed.
  PUMP_NUMBER_QUERY = /\A(?:pump\s*)?(\d{1,4})\z/i

  # Admin-console free-text lookup (business rule 17), over the things an admin
  # actually remembers about a past sheet: who filed it, which pump, and anything
  # typed into the notes. Lives here so the web console and the API cannot drift
  # apart — merge it into a filtered scope and it narrows, never widens.
  def self.matching_text(query)
    query = query.to_s.strip
    return all if query.blank?

    pattern = "%#{sanitize_sql_like(query)}%"
    matched = where("daily_settlements.fsm_name_snapshot ILIKE :pattern", pattern: pattern)
      .or(where("daily_settlements.notes ILIKE :pattern", pattern: pattern))
      .or(where(recorded_by_id: users_matching_text(pattern)))
    sequence_number = query[PUMP_NUMBER_QUERY, 1]
    return matched if sequence_number.nil?

    matched.or(where(fuel_pump_id: FuelPump.where(sequence_number: sequence_number).select(:id)))
  end

  def self.users_matching_text(pattern)
    User.where(
      "users.name ILIKE :pattern OR users.username ILIKE :pattern OR users.phone_number ILIKE :pattern",
      pattern: pattern
    ).select(:id)
  end
  private_class_method :users_matching_text

  # What the last settled sheet left a nozzle's meter at, and the date it was
  # settled. The reading auto-populates the next settlement's opening (business
  # rule 1); the date is what tells the FSM whether that figure is yesterday's
  # or a week old, which is the difference between accepting it and correcting
  # it. Rows with no closing figure are skipped rather than read as "no prior" —
  # an incomplete sheet should not blank out a meter history that exists.
  PriorClosing = Struct.new(:reading, :business_date, keyword_init: true)

  def self.prior_closing(fuel_pump_nozzle_id, business_date)
    return nil if fuel_pump_nozzle_id.blank? || business_date.blank?

    reading, settled_on = SettlementNozzleReading
      .joins(:daily_settlement)
      .merge(DailySettlement.financial)
      .where(fuel_pump_nozzle_id: fuel_pump_nozzle_id)
      .where.not(closing_reading: nil)
      .where("daily_settlements.business_date < ?", business_date)
      .order("daily_settlements.business_date DESC, daily_settlements.id DESC")
      .limit(1)
      .pick(:closing_reading, "daily_settlements.business_date")
    return nil if reading.nil?

    PriorClosing.new(reading: reading, business_date: settled_on)
  end

  def self.prior_closing_reading(fuel_pump_nozzle_id, business_date)
    prior_closing(fuel_pump_nozzle_id, business_date)&.reading
  end

  def editable_by_fsm?
    draft? && !locked?
  end

  def display_title
    "Settlement · #{fuel_pump&.display_name} · #{business_date}"
  end

  def entered_on_behalf?
    entered_by_id.present? && entered_by_id != recorded_by_id
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

  # Pulled lines always carry a visit entry; a row added during settlement
  # (item 11) is only real once it has a discount on it.
  def reject_discount_line?(attrs)
    attrs["id"].blank? && attrs["visit_entry_id"].blank? && attrs["discount_amount"].to_d.zero?
  end

  def reject_denomination?(attrs)
    attrs["id"].blank? && attrs["quantity"].to_i.zero?
  end

  # A seeded receipt row the FSM never filled in isn't a payment; drop it rather
  # than persist a ₹0 line for every means on every settlement.
  def reject_digital_receipt?(attrs)
    attrs["id"].blank? && (attrs["label"].blank? || attrs["amount"].to_d.zero?)
  end

  def reject_expense_line?(attrs)
    attrs["id"].blank? && (attrs["description"].blank? || attrs["amount"].to_d.zero?)
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

  # One row per nozzle, per lube, per denomination, per fuel type, per
  # competitor. A client that re-posts already-saved children without their ids
  # (the "settlement multiplying on a second submit" bug) would otherwise append
  # a second set and double every total. The matching unique indexes catch a
  # race; this catches the ordinary case — including two duplicates arriving
  # unsaved in the same payload — with a message the FSM can act on.
  # A free-form label is matched case-insensitively — "PAYTM" and "paytm" are
  # the same means.
  CASE_INSENSITIVE = ->(value) { value.is_a?(String) ? value.strip.downcase : value }

  KEYED_CHILDREN = {
    nozzle_readings: { keys: %i[fuel_pump_nozzle_id], label: "nozzle" },
    lube_lines: { keys: %i[product_id], label: "lubricant" },
    cash_denominations: { keys: %i[denomination], label: "denomination" },
    digital_receipts: { keys: %i[label], label: "digital means", normalize: CASE_INSENSITIVE },
    stock_receipts: { keys: %i[fuel_type_code], label: "stock receipt" },
    rate_comparisons: { keys: %i[fuel_type_code competitor_name], label: "rate comparison" }
  }.freeze

  def keyed_child_rows_are_distinct
    KEYED_CHILDREN.each do |association, config|
      normalize = config[:normalize] || :itself.to_proc
      live = public_send(association).reject(&:marked_for_destruction?)
      keys = live.map { |record| config[:keys].map { |key| normalize.call(record.public_send(key)) } }
      next if keys.size == keys.uniq.size

      errors.add(:base, "The same #{config[:label]} was submitted more than once.")
    end
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
