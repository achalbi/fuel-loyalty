class AddLitresToTransactions < ActiveRecord::Migration[8.1]
  # Litres become the source of truth; ₹ (fuel_amount) becomes a stored-derived
  # net value = gross (litres × price snapshot) − discount (LOCKED Q1).
  def up
    add_column :transactions, :litres, :decimal, precision: 9, scale: 3
    add_column :transactions, :selling_price_snapshot, :decimal, precision: 8, scale: 2
    add_column :transactions, :discount_amount, :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :transactions, :gross_amount, :decimal, precision: 10, scale: 2
    # amount_source enum: derived(0)=litres×price, legacy_amount(1)=migrated ₹-only, manual_amount(2)=admin ₹ override
    add_column :transactions, :amount_source, :integer, null: false, default: 0
    add_reference :transactions, :product, foreign_key: true, null: true

    add_column :reward_settings, :reward_basis, :integer, null: false, default: 0
    add_column :reward_settings, :litres_per_reward_unit, :decimal, precision: 6, scale: 2, null: false, default: 10

    # Existing ₹-only rows are legacy: net == gross, no litres captured.
    execute "UPDATE transactions SET amount_source = 1, gross_amount = fuel_amount WHERE gross_amount IS NULL"
  end

  def down
    remove_column :reward_settings, :litres_per_reward_unit
    remove_column :reward_settings, :reward_basis
    remove_reference :transactions, :product
    remove_column :transactions, :amount_source
    remove_column :transactions, :gross_amount
    remove_column :transactions, :discount_amount
    remove_column :transactions, :selling_price_snapshot
    remove_column :transactions, :litres
  end
end
