class AddNozzleFeatureEnabledToRewardSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :reward_settings, :nozzle_feature_enabled, :boolean, default: true, null: false
  end
end
