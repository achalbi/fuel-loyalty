class AddActiveToFuelRewardRates < ActiveRecord::Migration[8.1]
  def change
    add_column :fuel_reward_rates, :active, :boolean, null: false, default: true
  end
end
