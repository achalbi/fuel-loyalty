class BackfillAutoRickshawVehicleTypeTukTukIcons < ActiveRecord::Migration[8.1]
  TARGET_ICON = "custom-tuk-tuk"
  LEGACY_ICONS = %w[ti-scooter ti-moped].freeze

  def up
    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = '#{TARGET_ICON}', updated_at = CURRENT_TIMESTAMP
      WHERE (
        code = 'three_wheeler'
        OR LOWER(name) LIKE '%auto%'
        OR LOWER(name) LIKE '%rickshaw%'
        OR LOWER(name) LIKE '%three wheeler%'
        OR LOWER(name) LIKE '%three-wheeler%'
      )
      AND (icon_name IS NULL OR icon_name = '' OR icon_name IN ('#{LEGACY_ICONS.join("','")}'));
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-moped', updated_at = CURRENT_TIMESTAMP
      WHERE (
        code = 'three_wheeler'
        OR LOWER(name) LIKE '%auto%'
        OR LOWER(name) LIKE '%rickshaw%'
        OR LOWER(name) LIKE '%three wheeler%'
        OR LOWER(name) LIKE '%three-wheeler%'
      )
      AND icon_name = '#{TARGET_ICON}';
    SQL
  end
end
