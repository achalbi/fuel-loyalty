class AddMinimumRedeemablePointsToRewardSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :reward_settings, :minimum_redeemable_points, :integer
  end
end
