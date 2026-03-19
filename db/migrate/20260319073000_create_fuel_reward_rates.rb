class CreateFuelRewardRates < ActiveRecord::Migration[8.1]
  def up
    create_table :fuel_reward_rates do |t|
      t.string :fuel_type, null: false
      t.integer :points_per_100, null: false

      t.timestamps
    end

    add_index :fuel_reward_rates, :fuel_type, unique: true

    execute <<~SQL.squish
      INSERT INTO fuel_reward_rates (fuel_type, points_per_100, created_at, updated_at)
      VALUES
        ('petrol', 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('diesel', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('cng_lpg', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def down
    drop_table :fuel_reward_rates
  end
end
