class AddShiftCycles < ActiveRecord::Migration[8.1]
  def change
    create_table :shift_cycles do |t|
      t.string :name, null: false
      t.date :starts_on, null: false
      t.integer :period_days, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :shift_cycles, :name, unique: true
    add_index :shift_cycles, :active

    create_table :shift_cycle_steps do |t|
      t.references :shift_cycle, null: false, foreign_key: true
      t.references :shift_template, null: false, foreign_key: true
      t.integer :position, null: false
      t.timestamps
    end

    add_index :shift_cycle_steps, [:shift_cycle_id, :position], unique: true
    add_index :shift_cycle_steps, [:shift_cycle_id, :shift_template_id], name: "index_shift_cycle_steps_on_cycle_and_shift"

    add_reference :shift_assignments, :shift_cycle, foreign_key: true
  end
end
