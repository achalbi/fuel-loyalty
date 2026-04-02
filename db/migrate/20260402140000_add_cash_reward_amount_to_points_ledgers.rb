class AddCashRewardAmountToPointsLedgers < ActiveRecord::Migration[8.0]
  def change
    add_column :points_ledgers, :cash_reward_amount, :decimal, precision: 12, scale: 2
  end
end
