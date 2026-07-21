class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.integer :sl_num
      t.string :name, null: false
      t.string :category, null: false
      t.string :fuel_type_code
      t.decimal :pack_size, precision: 10, scale: 3
      t.string :pack_unit
      t.string :batch
      t.decimal :mrp, precision: 10, scale: 2, null: false, default: 0
      t.decimal :selling_price, precision: 10, scale: 2, null: false, default: 0
      t.string :hsn_code
      t.boolean :track_stock, null: false, default: true
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :products, :category
    add_index :products, :fuel_type_code
    add_index :products, :active
    add_index :products, :sl_num
    # At most one active fuel product per fuel type (unambiguous nozzle pricing).
    add_index :products, :fuel_type_code, unique: true,
      where: "category = 'fuel' AND active", name: "index_products_on_active_fuel_type"

    add_foreign_key :products, :fuel_types, column: :fuel_type_code, primary_key: :code
  end
end
