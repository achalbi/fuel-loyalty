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
  # Staff feedback item 3 — the admin who typed a sheet an FSM could not record
  # themselves. Authorship never moves: `recorded_by` stays the named FSM and
  # `fsm_name_snapshot` keeps their name, and this is the second half of
  # "recorded for ‹FSM›, entered by ‹admin›". NULL on a sheet the FSM recorded
  # themselves, which is the ordinary case.
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
  # Admin-12 — "the settlement reports of the users for a particular day".
  # recorded_by_id is NOT NULL and indexed, so filter on it rather than on the
  # fsm_name_snapshot text (which is a display copy and can repeat across users).
  scope :recorded_by_user, ->(user_id) { where(recorded_by_id: user_id) }

  # The ₹ columns Admin-13 rolls up. The aggregates below are shared by the web
  # and JSON admin index actions so the two surfaces cannot drift.
  FINANCIAL_TOTAL_FIELDS = %i[
    total_fuel_amount total_lube_amount total_discount_amount total_credit_amount
    final_amount_to_settle counted_cash_amount shortage_amount
  ].freeze

  # Admin-13 — sum an already-loaded list. Drafts are excluded: an unsubmitted
  # sheet is not money yet.
  def self.totals_for(rows)
    financial = rows.select { |row| row.submitted? || row.reconciled? }
    FINANCIAL_TOTAL_FIELDS.index_with { |field| financial.sum { |row| row.public_send(field).to_d } }
  end

  # Admin-12 — the same rollup split by the FSM who recorded each sheet, so an
  # admin can read the day's settlement per user without opening each one.
  # Pass rows loaded with :recorded_by; a recorder with only drafts is omitted,
  # matching the drafts-aren't-money rule above.
  def self.per_recorder_totals(rows)
    rows
      .select { |row| row.submitted? || row.reconciled? }
      .group_by(&:recorded_by_id)
      .map do |recorded_by_id, group|
        {
          recorded_by_id: recorded_by_id,
          fsm_name: group.first.fsm_name_snapshot.presence || group.first.recorded_by&.display_name,
          settlement_count: group.size,
          totals: totals_for(group)
        }
      end
      .sort_by { |row| row[:fsm_name].to_s.downcase }
  end

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

  # --- who typed it (staff feedback item 3) ---------------------------------
  # An admin captured this sheet rather than the FSM. True for both flavours
  # below; false (and `entered_by` NULL) on an ordinary FSM-recorded sheet.
  def admin_entered?
    entered_by_id.present?
  end

  # The on-behalf case proper: an admin typed it and attributed it to SOMEONE
  # ELSE — the FSM who was absent/sick/without a device.
  def entered_on_behalf?
    admin_entered? && entered_by_id != recorded_by_id
  end

  # An admin typed a sheet and attributed it to themselves. Allowed (a
  # single-admin site would otherwise deadlock, since reconcile is admin-only),
  # but it is the case where entry and approval sit with one person, so surface
  # it wherever the FSM name is shown rather than letting it read as an ordinary
  # FSM-recorded sheet.
  def self_entered_by_admin?
    admin_entered? && entered_by_id == recorded_by_id
  end

  # "Suresh" / "Suresh (entered by Admin)" — the one-line attribution both
  # surfaces render.
  def attribution_label
    name = fsm_name_snapshot.presence || recorded_by&.display_name
    return name unless admin_entered?

    "#{name} (entered by #{entered_by&.display_name})"
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
