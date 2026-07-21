class CreateDailySettlements < ActiveRecord::Migration[8.1]
  # Phase 2 — Daily Settlement (D1–D10). The shift-end reconciliation ledger for
  # a pump: nozzle meter readings (litres are canonical, ₹ derived from the A5
  # catalog price), lube lines, pulled customer discounts, digital-tender lines,
  # fleet/OTP + tank-truck credit, cash denomination + shortage, stock received,
  # decantation, and a competitor rate comparison. One parent row per pump per
  # business date per shift, with typed child tables and an admin audit trail.
  # See docs/acefuels/12-spec-daily-settlement.md.
  def change
    create_table :daily_settlements do |t|
      t.references :fuel_pump, null: false, foreign_key: { on_delete: :restrict }
      t.references :shift_template, foreign_key: { on_delete: :nullify }
      t.references :recorded_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }

      t.date :business_date, null: false
      t.string :fsm_name_snapshot
      t.integer :status, null: false, default: 0 # draft / submitted / reconciled

      # Digital tenders (D4) and the derived aggregates (D6) are stored for
      # reporting even though the Calculator recomputes them on every save.
      t.decimal :phonepe_pos_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :phonepe_scanner_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_fuel_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_lube_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_discount_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_credit_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :final_amount_to_settle, precision: 12, scale: 2, null: false, default: 0
      t.decimal :counted_cash_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :shortage_amount, precision: 12, scale: 2, null: false, default: 0

      t.text :notes
      t.datetime :submitted_at
      t.boolean :locked, null: false, default: false

      t.timestamps
    end

    # One settlement per pump/date/shift. NULLS NOT DISTINCT so a single-shift
    # outlet (shift_template_id null) still cannot double-file (mirrors
    # AttendanceRun#shift_window_must_be_unique, plus a model-level guard).
    add_index :daily_settlements, %i[fuel_pump_id business_date shift_template_id],
      unique: true, nulls_not_distinct: true, name: "index_daily_settlements_on_pump_date_shift"
    add_index :daily_settlements, :business_date
    add_index :daily_settlements, :status

    # D1 — one row per active nozzle. Readings/litres decimal(12,3); ₹ decimal(12,2).
    create_table :settlement_nozzle_readings do |t|
      t.references :daily_settlement, null: false, foreign_key: { on_delete: :cascade }
      t.references :fuel_pump_nozzle, null: false, foreign_key: { on_delete: :restrict }
      t.string :fuel_type_code_snapshot
      t.string :opening_source, null: false, default: "manual" # prior_settlement / manual
      t.decimal :opening_reading, precision: 12, scale: 3
      t.decimal :closing_reading, precision: 12, scale: 3
      t.decimal :testing_litres, precision: 12, scale: 3, null: false, default: 0
      t.boolean :rollover, null: false, default: false
      t.decimal :net_litres_sold, precision: 12, scale: 3
      t.decimal :unit_price, precision: 12, scale: 2
      t.decimal :amount, precision: 12, scale: 2
      t.timestamps
    end

    # D2 — lube/oil/AdBlue lines with opening/closing stock.
    create_table :settlement_lube_lines do |t|
      t.references :daily_settlement, null: false, foreign_key: { on_delete: :cascade }
      t.references :product, null: false, foreign_key: { on_delete: :restrict }
      t.string :product_name_snapshot
      t.integer :quantity, null: false, default: 0
      t.decimal :unit_price, precision: 12, scale: 2
      t.decimal :amount, precision: 12, scale: 2
      t.integer :opening_stock
      t.integer :closing_stock
      t.timestamps
    end

    # D3 — same-day customer discount lines, snapshotted from B2 visit entries.
    create_table :settlement_discount_lines do |t|
      t.references :daily_settlement, null: false, foreign_key: { on_delete: :cascade }
      t.references :visit_entry, foreign_key: { on_delete: :nullify }
      t.string :transport_name
      t.decimal :litres, precision: 12, scale: 3, null: false, default: 0
      t.decimal :discount_amount, precision: 12, scale: 2, null: false, default: 0
      t.string :driver_name
      t.string :driver_phone_number
      t.string :manager_name
      t.string :manager_phone_number
      t.string :owner_name
      t.string :owner_phone_number
      t.timestamps
    end

    # D5 — Fleet/OTP and tank-truck credit lines.
    create_table :settlement_credit_lines do |t|
      t.references :daily_settlement, null: false, foreign_key: { on_delete: :cascade }
      t.integer :credit_type, null: false, default: 0 # fleet_otp / tank_truck
      t.decimal :litres, precision: 12, scale: 3, null: false, default: 0
      t.decimal :discount_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :amount, precision: 12, scale: 2, null: false, default: 0
      t.string :reference
      t.string :note
      t.timestamps
    end

    # D7 — cash by denomination; amount derived = denomination * quantity.
    create_table :settlement_cash_denominations do |t|
      t.references :daily_settlement, null: false, foreign_key: { on_delete: :cascade }
      t.integer :denomination, null: false
      t.integer :quantity, null: false, default: 0
      t.decimal :amount, precision: 12, scale: 2
      t.timestamps
    end

    # D8 — fuel stock received during the shift.
    create_table :settlement_stock_receipts do |t|
      t.references :daily_settlement, null: false, foreign_key: { on_delete: :cascade }
      t.string :fuel_type_code
      t.decimal :litres_received, precision: 12, scale: 3, null: false, default: 0
      t.timestamps
    end

    # D8 — tank KL decantation readings after a tanker drop.
    create_table :settlement_decantations do |t|
      t.references :daily_settlement, null: false, foreign_key: { on_delete: :cascade }
      t.string :fuel_type_code
      t.string :tank_label
      t.decimal :opening_kl, precision: 12, scale: 3
      t.decimal :closing_kl, precision: 12, scale: 3
      t.timestamps
    end

    # D10 — competitor (JIO-BP) vs own selling price.
    create_table :settlement_rate_comparisons do |t|
      t.references :daily_settlement, null: false, foreign_key: { on_delete: :cascade }
      t.string :fuel_type_code
      t.string :competitor_name, null: false, default: "JIO-BP"
      t.decimal :competitor_price, precision: 12, scale: 2
      t.decimal :own_price, precision: 12, scale: 2
      t.timestamps
    end

    # D9 — audit trail, mirrors attendance_entry_changes. Append-only.
    create_table :settlement_changes do |t|
      t.references :daily_settlement, null: false, foreign_key: { on_delete: :cascade }
      t.references :changed_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :change_reason, null: false
      t.jsonb :field_diffs, null: false, default: {}
      t.boolean :recomputed_points, null: false, default: false
      t.datetime :created_at, null: false
    end
  end
end
