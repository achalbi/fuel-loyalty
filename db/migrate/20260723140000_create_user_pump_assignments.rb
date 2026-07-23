class CreateUserPumpAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :user_pump_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :fuel_pump, null: false, foreign_key: true
      t.references :assigned_by, foreign_key: { to_table: :users }
      t.date :assigned_on, null: false
      t.jsonb :assigned_fuel_pump_nozzle_ids, null: false, default: []

      t.timestamps
    end

    add_index :user_pump_assignments, %i[user_id assigned_on], unique: true,
      name: "index_user_pump_assignments_on_user_and_date"
    add_index :user_pump_assignments, :assigned_on
  end
end
