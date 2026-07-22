class AddMilestoneStepToRewardSettings < ActiveRecord::Migration[8.1]
  # F3 — the loyalty-points ladder step. Crossing a new multiple of this on a
  # transaction fires one auto "you've earned N points" notification.
  def change
    add_column :reward_settings, :milestone_step, :integer, null: false, default: 500
  end
end
