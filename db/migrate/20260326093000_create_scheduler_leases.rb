class CreateSchedulerLeases < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduler_leases do |t|
      t.string :key, null: false
      t.boolean :running, null: false, default: false
      t.string :lease_token
      t.datetime :started_at
      t.datetime :last_heartbeat_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :scheduler_leases, :key, unique: true
    add_index :scheduler_leases, :running
  end
end
