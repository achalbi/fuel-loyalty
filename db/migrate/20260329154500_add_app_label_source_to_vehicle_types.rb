class AddAppLabelSourceToVehicleTypes < ActiveRecord::Migration[8.1]
  def up
    add_column :vehicle_types, :app_label_source, :string, default: "short_name"

    say_with_time "Backfilling vehicle type app label sources" do
      execute <<~SQL.squish
        UPDATE vehicle_types
        SET app_label_source = 'short_name'
        WHERE app_label_source IS NULL OR TRIM(app_label_source) = ''
      SQL
    end

    change_column_null :vehicle_types, :app_label_source, false
  end

  def down
    remove_column :vehicle_types, :app_label_source
  end
end
