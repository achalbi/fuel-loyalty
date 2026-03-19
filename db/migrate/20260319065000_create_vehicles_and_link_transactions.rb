class CreateVehiclesAndLinkTransactions < ActiveRecord::Migration[8.1]
  class MigrationCustomer < ApplicationRecord
    self.table_name = "customers"
  end

  class MigrationTransaction < ApplicationRecord
    self.table_name = "transactions"
  end

  class MigrationVehicle < ApplicationRecord
    self.table_name = "vehicles"
  end

  def up
    create_table :vehicles do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :vehicle_number, null: false

      t.timestamps
    end

    add_index :vehicles, :vehicle_number, unique: true

    add_reference :transactions, :vehicle, foreign_key: true

    say_with_time "Backfilling vehicles from existing customer records" do
      MigrationCustomer.reset_column_information
      MigrationTransaction.reset_column_information
      MigrationVehicle.reset_column_information

      MigrationCustomer.find_each do |customer|
        next if customer.vehicle_number.blank?

        vehicle = MigrationVehicle.find_or_create_by!(vehicle_number: normalize_vehicle_number(customer.vehicle_number)) do |record|
          record.customer_id = customer.id
        end

        MigrationTransaction.where(customer_id: customer.id, vehicle_id: nil).update_all(vehicle_id: vehicle.id)
      end
    end
  end

  def down
    remove_reference :transactions, :vehicle, foreign_key: true
    drop_table :vehicles
  end

  private

  def normalize_vehicle_number(value)
    value.to_s.gsub(/\s+/, "").upcase
  end
end
