class AddActiveToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :active, :boolean, null: false, default: true
  end
end
