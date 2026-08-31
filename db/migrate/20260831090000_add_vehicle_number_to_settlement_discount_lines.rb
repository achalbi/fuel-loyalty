class AddVehicleNumberToSettlementDiscountLines < ActiveRecord::Migration[8.1]
  # Business rule 17 lets an admin find a past sheet by free text, and the two
  # things they actually have to hand when asking about a discount are the
  # transporter and the vehicle. The line already snapshots the transporter,
  # the driver and their numbers from the B2 visit entry — the plate was the one
  # identifying column left behind, so a vehicle could be searched in Reports
  # but never traced to the settlement it was discounted on.
  #
  # Stored normalized (A-Z0-9 only, as `visit_entries` stores it), so a plate
  # typed "KA-01 AA 0001" matches what was captured.
  def up
    add_column :settlement_discount_lines, :vehicle_number, :string

    # Every pulled line points at the visit entry it was snapshotted from, and
    # that entry's plate is what was captured at the pump — so the history is
    # recoverable in full rather than starting empty from today. Lines the FSM
    # added at settlement have no visit entry and no plate to recover.
    execute <<~SQL.squish
      UPDATE settlement_discount_lines
         SET vehicle_number = visit_entries.vehicle_number
        FROM visit_entries
       WHERE settlement_discount_lines.visit_entry_id = visit_entries.id
    SQL
  end

  def down
    remove_column :settlement_discount_lines, :vehicle_number
  end
end
