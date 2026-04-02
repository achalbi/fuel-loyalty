class CreateRewardSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :reward_settings do |t|
      t.integer :rupees_per_reward_unit, null: false, default: 100

      t.timestamps
    end
  end
end
