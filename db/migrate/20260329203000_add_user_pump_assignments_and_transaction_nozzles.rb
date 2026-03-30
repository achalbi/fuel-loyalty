class AddUserPumpAssignmentsAndTransactionNozzles < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :fuel_pump, foreign_key: true

    create_table :user_pump_nozzle_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :fuel_pump_nozzle, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_pump_nozzle_assignments, [:user_id, :fuel_pump_nozzle_id], unique: true, name: "index_user_pump_nozzle_assignments_on_user_and_nozzle"

    add_reference :transactions, :fuel_pump, foreign_key: true
    add_reference :transactions, :fuel_pump_nozzle, foreign_key: true
  end
end
