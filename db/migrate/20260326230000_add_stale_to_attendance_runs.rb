class AddStaleToAttendanceRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :attendance_runs, :stale, :boolean, default: false, null: false
    add_index :attendance_runs, :stale
  end
end
