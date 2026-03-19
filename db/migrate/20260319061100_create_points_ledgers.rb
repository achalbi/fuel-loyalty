class CreatePointsLedgers < ActiveRecord::Migration[8.1]
  def change
    create_table :points_ledgers do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :transaction, null: true, foreign_key: true
      t.integer :points, null: false
      t.integer :entry_type, null: false

      t.timestamps
    end
  end
end
