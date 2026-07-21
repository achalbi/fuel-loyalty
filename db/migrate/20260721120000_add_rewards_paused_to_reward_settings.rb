class AddRewardsPausedToRewardSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :reward_settings, :rewards_paused, :boolean, default: false, null: false
  end
end
