class AddVehicleMetadataToVehicles < ActiveRecord::Migration[8.1]
  class MigrationVehicle < ApplicationRecord
    self.table_name = "vehicles"
  end

  def up
    add_column :vehicles, :fuel_type, :string
    add_column :vehicles, :vehicle_kind, :string

    say_with_time "Backfilling vehicle fuel type and category for existing records" do
      MigrationVehicle.update_all(fuel_type: "petrol", vehicle_kind: "lmv")
    end

    change_column_null :vehicles, :fuel_type, false
    change_column_null :vehicles, :vehicle_kind, false
  end

  def down
    remove_column :vehicles, :vehicle_kind
    remove_column :vehicles, :fuel_type
  end
end
