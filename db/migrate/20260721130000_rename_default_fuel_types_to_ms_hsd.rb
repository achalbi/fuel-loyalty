class RenameDefaultFuelTypesToMsHsd < ActiveRecord::Migration[8.1]
  # Rename the seeded fuel types to the outlet's terminology (MS / HSD), keeping
  # the codes stable so vehicles, nozzles and reward rates are unaffected. Only
  # touch records that still carry the old default name so admin renames aren't
  # clobbered.
  def up
    execute <<~SQL.squish
      UPDATE fuel_types SET name = 'MS (Petrol)', updated_at = NOW()
      WHERE code = 'petrol' AND name = 'Petrol';
    SQL
    execute <<~SQL.squish
      UPDATE fuel_types SET name = 'HSD (Diesel)', updated_at = NOW()
      WHERE code = 'diesel' AND name = 'Diesel';
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE fuel_types SET name = 'Petrol', updated_at = NOW()
      WHERE code = 'petrol' AND name = 'MS (Petrol)';
    SQL
    execute <<~SQL.squish
      UPDATE fuel_types SET name = 'Diesel', updated_at = NOW()
      WHERE code = 'diesel' AND name = 'HSD (Diesel)';
    SQL
  end
end
