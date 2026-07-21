class CreateVisitEntries < ActiveRecord::Migration[8.1]
  # B2 — the FSM per-visit CustomerDetailsEntry. Distinct from `transactions`:
  # a field observation (litres, who drove, discount promised) captured many
  # times per shift, and the source the daily-settlement Discounts section pulls
  # from. Litres are the source of truth (LOCKED Q1); ₹ is derived later.
  def change
    create_table :visit_entries do |t|
      t.references :customer, foreign_key: { on_delete: :nullify }
      t.references :vehicle, foreign_key: { on_delete: :nullify }
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.references :fuel_pump, null: false, foreign_key: { on_delete: :restrict }
      t.references :transaction, foreign_key: { to_table: :transactions, on_delete: :nullify }

      t.date :entry_date, null: false
      t.string :vehicle_number, null: false
      t.string :driver_name
      t.string :driver_phone_number
      t.decimal :litres, precision: 10, scale: 3, null: false
      t.string :fuel_type_code
      t.decimal :discount_amount, precision: 10, scale: 2, null: false, default: 0
      t.boolean :fleet_otp, null: false, default: false
      t.string :transport_name
      t.string :manager_name
      t.string :manager_phone_number
      t.string :owner_name
      t.string :owner_phone_number
      t.integer :approx_vehicle_count

      t.timestamps
    end

    # Settlement pulls a pump's captures for a day; the others back the review
    # list and the customer "Visits" tab.
    add_index :visit_entries, [:fuel_pump_id, :entry_date]
    add_index :visit_entries, :entry_date
  end
end
