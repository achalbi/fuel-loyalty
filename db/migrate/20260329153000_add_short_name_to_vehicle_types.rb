class AddShortNameToVehicleTypes < ActiveRecord::Migration[8.1]
  DEFAULT_SHORT_NAMES = {
    "two_wheeler" => "Two-Wheeler",
    "three_wheeler" => "Three-Wheeler",
    "lmv" => "LMV",
    "lcv" => "LCV",
    "mcv" => "MCV",
    "hcv" => "HCV"
  }.freeze

  def up
    add_column :vehicle_types, :short_name, :string

    say_with_time "Backfilling vehicle type short names" do
      execute <<~SQL.squish
        UPDATE vehicle_types
        SET short_name = CASE
          WHEN code = 'two_wheeler' THEN 'Two-Wheeler'
          WHEN code = 'three_wheeler' THEN 'Three-Wheeler'
          WHEN code = 'lmv' THEN 'LMV'
          WHEN code = 'lcv' THEN 'LCV'
          WHEN code = 'mcv' THEN 'MCV'
          WHEN code = 'hcv' THEN 'HCV'
          ELSE name
        END
        WHERE short_name IS NULL OR TRIM(short_name) = ''
      SQL
    end

    change_column_null :vehicle_types, :short_name, false
  end

  def down
    remove_column :vehicle_types, :short_name
  end
end
