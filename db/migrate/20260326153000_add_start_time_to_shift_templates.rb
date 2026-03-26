class AddStartTimeToShiftTemplates < ActiveRecord::Migration[8.1]
  def up
    add_column :shift_templates, :start_time, :time

    execute <<~SQL
      UPDATE shift_templates
      SET start_time = '00:00:00'
      WHERE start_time IS NULL
    SQL

    change_column_null :shift_templates, :start_time, false
  end

  def down
    remove_column :shift_templates, :start_time
  end
end
