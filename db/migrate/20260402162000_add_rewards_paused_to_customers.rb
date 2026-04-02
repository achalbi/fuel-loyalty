class AddRewardsPausedToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :rewards_paused, :boolean, null: false, default: false
  end
end
