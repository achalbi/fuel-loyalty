class CreateNotificationSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_schedules do |t|
      t.string :title, null: false
      t.text :message, null: false
      t.string :frequency, null: false
      t.string :scheduled_time, null: false
      t.date :scheduled_date
      t.integer :day_of_week
      t.integer :day_of_month
      t.datetime :last_sent_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :notification_schedules, :active
    add_index :notification_schedules, :frequency
  end
end
