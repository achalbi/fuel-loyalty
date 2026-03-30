class CreateFuelPumpsAndNozzles < ActiveRecord::Migration[8.1]
  def change
    create_table :fuel_pumps do |t|
      t.integer :sequence_number, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :fuel_pumps, :active
    add_index :fuel_pumps, :sequence_number, unique: true

    create_table :fuel_pump_nozzles do |t|
      t.references :fuel_pump, null: false, foreign_key: true
      t.integer :sequence_number, null: false
      t.string :fuel_type_code, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :fuel_pump_nozzles, :active
    add_index :fuel_pump_nozzles, :fuel_type_code
    add_index :fuel_pump_nozzles, [:fuel_pump_id, :sequence_number], unique: true
    add_foreign_key :fuel_pump_nozzles, :fuel_types, column: :fuel_type_code, primary_key: :code
  end
end
