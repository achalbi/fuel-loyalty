class AddChannelsAndTargetToNotificationSchedules < ActiveRecord::Migration[8.1]
  # F2 — scheduled sends gain the same channel + audience targeting the ad-hoc
  # send already has, plus an optional campaign link (mirrors notification_messages).
  def change
    add_column :notification_schedules, :channels, :string, null: false, default: "push"
    add_column :notification_schedules, :target_type, :string, null: false, default: "all"
    add_column :notification_schedules, :target_customer_type, :string
    add_reference :notification_schedules, :campaign, null: true,
                  foreign_key: { on_delete: :nullify }
  end
end
