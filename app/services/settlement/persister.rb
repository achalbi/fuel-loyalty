module Settlement
  # Atomic upsert of a settlement plus all its children (nested attributes with
  # allow_destroy). Prices are snapshotted server-side from the A5 catalog — the
  # client never supplies unit_price. The admin audit trail (settlement_changes)
  # and loyalty points recompute (C5 ⇄ D9) extend this in the admin edit path.
  class Persister
    Result = Struct.new(:settlement, :change, :points_recomputed, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(settlement:, attributes:, actor:, admin_edit: false, change_reason: nil, on_behalf_of: nil)
      @settlement = settlement
      @attributes = attributes || {}
      @actor = actor
      @admin_edit = admin_edit
      @change_reason = change_reason
      @on_behalf_of = on_behalf_of
    end

    def call
      ActiveRecord::Base.transaction do
        before = @admin_edit ? Differ.snapshot(@settlement) : nil

        @settlement.assign_attributes(@attributes)
        @settlement.recorded_by ||= @actor
        # Stamped only when the row is created: who keyed this settlement in. A
        # later edit must never back-stamp it — that would claim the editing admin
        # keyed in every settlement that predates this column. Edit history lives
        # in settlement_changes instead.
        @settlement.entered_by ||= @actor if @settlement.new_record?
        snapshot_prices!
        stamp_opening_readings!
        stamp_discount_vehicles!
        stamp_submission
        @settlement.save!

        change = @admin_edit ? record_change!(before) : nil
        Result.new(settlement: @settlement, change: change, points_recomputed: change&.recomputed_points || false)
      end
    end

    private

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

    # Rule 1 — what the last settled sheet closed at is the *offer* for today's
    # opening, and whether the FSM took that offer or overrode it is decided
    # here, from the database. `opening_source` is the audit answer to "was this
    # meter reading typed or inherited?", so it is never read off the request:
    # a client that names its own source can call any correction an inheritance.
    # The offered figure is snapshotted once, when the row is created, like
    # unit_price: a sheet filed later for an earlier date must not rewrite what
    # an existing row was shown at the time, and a legacy row that predates the
    # snapshot is left alone rather than relabelled from today's history.
    def stamp_opening_readings!
      @settlement.nozzle_readings.reject(&:marked_for_destruction?).each do |reading|
        if reading.new_record?
          prior = DailySettlement.prior_closing(reading.fuel_pump_nozzle_id, @settlement.business_date)
          reading.prior_closing_reading = prior&.reading
          reading.prior_closing_date = prior&.business_date
        end
        reading.derive_opening_source!
      end
    end

    # A discount line pulled from a B2 visit carries that visit's plate, which is
    # how an admin traces a vehicle to the sheet it was discounted on (rule 17).
    # Taken from the visit entry rather than the request: no client sends it, the
    # native app's discount payload carries only the transporter and the money,
    # and a plate the client could set would be a plate that disagrees with the
    # capture it claims to be a snapshot of.
    #
    # Stamped once, when the row is created — like unit_price and the offered
    # opening. A later B2 correction must not silently rewrite what a submitted
    # sheet was built from; that is what the audit trail is for. A line the FSM
    # added at settlement has no visit entry and keeps no plate.
    def stamp_discount_vehicles!
      new_lines = @settlement.discount_lines.reject(&:marked_for_destruction?).select(&:new_record?)
      linked = new_lines.select { |line| line.visit_entry_id.present? && line.vehicle_number.blank? }
      return if linked.empty?

      plates = VisitEntry.where(id: linked.map(&:visit_entry_id)).pluck(:id, :vehicle_number).to_h
      linked.each { |line| line.vehicle_number = plates[line.visit_entry_id] }
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

    # D9 — record an audit row for every admin edit; propagate a customer-linked
    # discount change back to loyalty points (C5) inside this same transaction.
    # `on_behalf_of` is the FSM the admin entered the edit for (Admin-12).
    def record_change!(before)
      diffs = Differ.diff(before, Differ.snapshot(@settlement))
      recomputed = PointsRecomputeService.call(@settlement, diffs)
      @settlement.audit_changes.create!(
        changed_by: @actor,
        on_behalf_of: @on_behalf_of,
        change_reason: @change_reason,
        field_diffs: diffs,
        recomputed_points: recomputed
      )
    end
  end
end
