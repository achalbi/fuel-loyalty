class SeedProductCatalog < ActiveRecord::Migration[8.1]
  # Idempotent seed of the outlet's catalog (the requirement's PumpsNozzlesProductsSetup
  # sheet). Keyed by name + pack size so re-runs update rather than duplicate.
  def up
    # Fuel products reference fuel_types by code (FK); make sure they exist.
    FuelType.find_or_create_by!(code: "petrol") { |ft| ft.name = "MS (Petrol)" }
    FuelType.find_or_create_by!(code: "diesel") { |ft| ft.name = "HSD (Diesel)" }

    rows = [
      { sl_num: 1, name: "HSD", category: "fuel", fuel_type_code: "diesel", pack_unit: "litre", mrp: 98.95, selling_price: 98.95 },
      { sl_num: 2, name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 111.36, selling_price: 111.36 },
      { sl_num: 3, name: "2T", category: "lubricant", pack_size: 20, pack_unit: "ml", mrp: 12, selling_price: 12 },
      { sl_num: 4, name: "2T", category: "lubricant", pack_size: 40, pack_unit: "ml", mrp: 0, selling_price: 0 },
      { sl_num: 5, name: "2T", category: "lubricant", pack_size: 60, pack_unit: "ml", mrp: 0, selling_price: 0 },
      { sl_num: 6, name: "10W30", category: "oil", pack_size: 800, pack_unit: "ml", mrp: 350, selling_price: 350 },
      { sl_num: 7, name: "2T", category: "lubricant", pack_size: 500, pack_unit: "ml", mrp: 0, selling_price: 0 },
      { sl_num: 8, name: "Milex Petrol", category: "additive", pack_size: 5, pack_unit: "ml", mrp: 12, selling_price: 12 },
      { sl_num: 9, name: "Milex Petrol", category: "additive", pack_size: 40, pack_unit: "ml", mrp: 150, selling_price: 150 },
      { sl_num: 10, name: "Milex Diesel", category: "additive", pack_size: 10, pack_unit: "ml", mrp: 25, selling_price: 25 },
      { sl_num: 11, name: "Milex Diesel", category: "additive", pack_size: 50, pack_unit: "ml", mrp: 150, selling_price: 150 },
      { sl_num: 12, name: "AdBlue", category: "additive", pack_size: 5, pack_unit: "L", mrp: 680, selling_price: 680 },
      { sl_num: 13, name: "AdBlue", category: "additive", pack_size: 10, pack_unit: "L", mrp: 1080, selling_price: 1080 },
      { sl_num: 14, name: "AdBlue", category: "additive", pack_size: 20, pack_unit: "L", mrp: 1730, selling_price: 1730 }
    ]

    rows.each do |attrs|
      product = Product.find_or_initialize_by(name: attrs[:name], pack_size: attrs[:pack_size], pack_unit: attrs[:pack_unit])
      product.assign_attributes(attrs.merge(track_stock: true, active: true))
      product.save!
    end
  end

  def down
    Product.where(sl_num: 1..14).delete_all
  end
end
