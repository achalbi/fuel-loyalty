class ChangeShiftTemplateStartTimeToString < ActiveRecord::Migration[8.1]
  def up
    change_column :shift_templates, :start_time, :string, using: "to_char(start_time, 'HH24:MI')"
  end

  def down
    change_column :shift_templates, :start_time, :time, using: "start_time::time"
  end
end
