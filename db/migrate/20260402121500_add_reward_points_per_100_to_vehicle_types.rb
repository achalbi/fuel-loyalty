class AddRewardPointsPer100ToVehicleTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :vehicle_types, :reward_points_per_100, :integer
  end
end
