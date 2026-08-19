module Settlement
  # Atomic upsert of a settlement plus all its children (nested attributes with
  # allow_destroy). Prices are snapshotted server-side from the A5 catalog — the
  # client never supplies unit_price. The admin audit trail (settlement_changes)
  # and loyalty points recompute (C5 ⇄ D9) extend this in the admin edit path.
  class Persister
    Result = Struct.new(:settlement, :change, :points_recomputed, keyword_init: true)

    def self.call(...) = new(...).call

    # `actor` is whoever is saving. `recorded_for` is set only by the admin
    # "record on behalf of" flow (staff feedback item 3) and names the FSM the
    # sheet belongs to; passing it switches attribution and turns on auditing
    # for what is otherwise an unaudited create.
    def initialize(settlement:, attributes:, actor:, admin_edit: false, change_reason: nil, recorded_for: nil)
      @settlement = settlement
      @attributes = attributes || {}
      @actor = actor
      @admin_edit = admin_edit
      @change_reason = change_reason
      @recorded_for = recorded_for
    end

    def call
      # On-behalf is a CREATE-only mode. Were it ever passed a persisted sheet,
      # `apply_attribution` would silently move authorship off the original FSM
      # and the audit row would be diffed against a blank baseline — claiming
      # every column changed from nil and destroying the one record that proves
      # what actually happened. Fail loudly instead.
      if on_behalf? && !@settlement.new_record?
        raise ArgumentError, "recorded_for: is only for a fresh sheet — correct an existing one with admin_edit:"
      end

      ActiveRecord::Base.transaction do
        before = audited? ? snapshot_before : nil

        @settlement.assign_attributes(@attributes)
        apply_attribution
        snapshot_prices!
        stamp_submission
        @settlement.save!

        change = audited? ? record_change!(before) : nil
        Result.new(settlement: @settlement, change: change, points_recomputed: change&.recomputed_points || false)
      end
    end

    private

    # An admin correcting an existing sheet, or an admin capturing a fresh one on
    # a named FSM's behalf. Both are an admin writing into someone else's
    # record, so both leave a settlement_changes row with a mandatory reason. An
    # FSM saving their own sheet writes none.
    def audited?
      @admin_edit || on_behalf?
    end

    def on_behalf?
      @recorded_for.present?
    end

    # Keyed on new_record?, not on on_behalf?: a create has no "before" to diff
    # against, so the blank baseline is what makes the audit row list what was
    # entered rather than every zero default.
    def snapshot_before
      @settlement.new_record? ? Differ.blank_snapshot : Differ.snapshot(@settlement)
    end

    # The sheet is the FSM's: `recorded_by` and the name snapshot are theirs, and
    # only `entered_by` records the admin who typed it. Everything else keeps the
    # long-standing rule that the saver owns an unattributed sheet.
    def apply_attribution
      if on_behalf?
        @settlement.recorded_by = @recorded_for
        @settlement.fsm_name_snapshot = @recorded_for.display_name
        @settlement.entered_by = @actor
      else
        @settlement.recorded_by ||= @actor
      end
    end

    # LOCKED Q1: ₹ is derived from catalog price, snapshotted at capture. Only new
    # lines (no snapshot yet) are priced; existing snapshots are preserved so a
    # later catalog change never rewrites a submitted settlement.
    def snapshot_prices!
      snapshot_nozzle_prices!
      snapshot_rate_comparison_prices!
    end

    def snapshot_nozzle_prices!
      readings = @settlement.nozzle_readings.reject(&:marked_for_destruction?)
      nozzle_ids = readings.map(&:fuel_pump_nozzle_id).compact.uniq
      fuel_by_nozzle = FuelPumpNozzle.where(id: nozzle_ids).pluck(:id, :fuel_type_code).to_h

      readings.each do |reading|
        fuel_code = fuel_by_nozzle[reading.fuel_pump_nozzle_id]
        reading.fuel_type_code_snapshot = fuel_code if reading.fuel_type_code_snapshot.blank?
        reading.unit_price = FuelPricing.current_price(fuel_code) if reading.unit_price.blank?
      end
    end

    def snapshot_rate_comparison_prices!
      @settlement.rate_comparisons.reject(&:marked_for_destruction?).each do |row|
        row.own_price = FuelPricing.current_price(row.fuel_type_code) if row.own_price.blank?
      end
    end

    def stamp_submission
      return unless @settlement.status_changed?

      @settlement.submitted_at ||= Time.current if @settlement.submitted? || @settlement.reconciled?
      @settlement.locked = true if @settlement.reconciled?
    end

    # D9 — record an audit row for every admin edit and every on-behalf create;
    # propagate a customer-linked discount change back to loyalty points (C5)
    # inside this same transaction. `change_reason` is mandatory (SettlementChange
    # validates it), so a caller that forgets one rolls the whole save back
    # rather than leaving an unexplained admin write on the books.
    def record_change!(before)
      diffs = Differ.diff(before, Differ.snapshot(@settlement))
      recomputed = PointsRecomputeService.call(@settlement, diffs)
      @settlement.audit_changes.create!(
        changed_by: @actor,
        change_reason: @change_reason,
        field_diffs: diffs,
        recomputed_points: recomputed
      )
    end
  end
end
