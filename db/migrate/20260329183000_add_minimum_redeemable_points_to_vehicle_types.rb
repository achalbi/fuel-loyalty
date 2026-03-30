class AddMinimumRedeemablePointsToVehicleTypes < ActiveRecord::Migration[8.1]
  DEFAULT_MINIMUM_REDEEMABLE_POINTS = 100

  def up
    add_column :vehicle_types, :minimum_redeemable_points, :integer, default: DEFAULT_MINIMUM_REDEEMABLE_POINTS

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET minimum_redeemable_points = #{DEFAULT_MINIMUM_REDEEMABLE_POINTS}
      WHERE minimum_redeemable_points IS NULL
    SQL

    change_column_null :vehicle_types, :minimum_redeemable_points, false
  end

  def down
    remove_column :vehicle_types, :minimum_redeemable_points
  end
end
