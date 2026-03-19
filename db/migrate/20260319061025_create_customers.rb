class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :name
      t.string :phone_number, null: false
      t.string :vehicle_number

      t.timestamps
    end

    add_index :customers, :phone_number, unique: true
  end
end
