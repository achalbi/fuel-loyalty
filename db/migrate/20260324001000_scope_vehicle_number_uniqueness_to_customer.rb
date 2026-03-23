class ScopeVehicleNumberUniquenessToCustomer < ActiveRecord::Migration[8.1]
  def change
    remove_index :vehicles, name: "index_vehicles_on_vehicle_number"
    add_index :vehicles, [:customer_id, :vehicle_number], unique: true, name: "index_vehicles_on_customer_id_and_vehicle_number"
  end
end
