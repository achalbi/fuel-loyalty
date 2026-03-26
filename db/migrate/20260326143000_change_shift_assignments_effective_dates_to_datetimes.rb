class ChangeShiftAssignmentsEffectiveDatesToDatetimes < ActiveRecord::Migration[8.1]
  def up
    change_column :shift_assignments, :effective_from, :datetime, using: "effective_from::timestamp"
    change_column :shift_assignments, :effective_to, :datetime, using: "CASE WHEN effective_to IS NULL THEN NULL ELSE effective_to::timestamp + interval '23 hours 59 minutes 59 seconds' END"
  end

  def down
    change_column :shift_assignments, :effective_from, :date, using: "effective_from::date"
    change_column :shift_assignments, :effective_to, :date, using: "effective_to::date"
  end
end
