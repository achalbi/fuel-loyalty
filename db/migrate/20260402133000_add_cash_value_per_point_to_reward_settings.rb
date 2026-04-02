class AddCashValuePerPointToRewardSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :reward_settings, :cash_value_per_point, :decimal, precision: 10, scale: 2
  end
end
