class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :fuel_amount, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
