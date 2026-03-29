class BackfillRemovedVehicleTypeIcons < ActiveRecord::Migration[8.1]
  REMOVED_TWO_WHEELER_ICONS = %w[ti-motorbike ti-scooter ti-scooter-electric ti-moped].freeze
  REMOVED_CAR_ICONS = %w[ti-car-suv ti-car-4wd].freeze
  REMOVED_BUS_ICONS = %w[ti-caravan].freeze
  REMOVED_TRUCK_ICONS = %w[ti-rv-truck ti-ambulance ti-firetruck ti-forklift].freeze
  LEGACY_PICKUP_TRUCK_ICONS = %w[ti-truck-delivery].freeze
  LEGACY_BIG_TRUCK_ICONS = %w[ti-truck-loading].freeze
  AUTO_RICKSHAW_ICON = "custom-tuk-tuk"
  PICKUP_TRUCK_ICON = "custom-pickup-truck"
  BIG_TRUCK_ICON = "custom-big-truck"
  BIKE_ICON = "ti-bike"
  CAR_ICON = "ti-car"
  BUS_ICON = "ti-bus"
  TRUCK_ICON = "ti-truck"

  def up
    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = '#{AUTO_RICKSHAW_ICON}', updated_at = CURRENT_TIMESTAMP
      WHERE (
        code = 'three_wheeler'
        OR LOWER(name) LIKE '%auto%'
        OR LOWER(name) LIKE '%rickshaw%'
        OR LOWER(name) LIKE '%three wheeler%'
        OR LOWER(name) LIKE '%three-wheeler%'
      )
      AND icon_name IN ('#{REMOVED_TWO_WHEELER_ICONS.join("','")}');
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = '#{BIKE_ICON}', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name IN ('#{REMOVED_TWO_WHEELER_ICONS.join("','")}');
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = '#{CAR_ICON}', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name IN ('#{REMOVED_CAR_ICONS.join("','")}');
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = '#{BUS_ICON}', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name IN ('#{REMOVED_BUS_ICONS.join("','")}');
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = '#{PICKUP_TRUCK_ICON}', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name IN ('#{LEGACY_PICKUP_TRUCK_ICONS.join("','")}');
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = '#{BIG_TRUCK_ICON}', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name IN ('#{LEGACY_BIG_TRUCK_ICONS.join("','")}');
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = '#{TRUCK_ICON}', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name IN ('#{REMOVED_TRUCK_ICONS.join("','")}');
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-moped', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{AUTO_RICKSHAW_ICON}'
      AND (
        code = 'three_wheeler'
        OR LOWER(name) LIKE '%auto%'
        OR LOWER(name) LIKE '%rickshaw%'
        OR LOWER(name) LIKE '%three wheeler%'
        OR LOWER(name) LIKE '%three-wheeler%'
      );
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-motorbike', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{BIKE_ICON}'
      AND (
        LOWER(name) LIKE '%motorbike%'
        OR LOWER(name) LIKE '%motorcycle%'
        OR LOWER(name) LIKE '%scooter%'
        OR LOWER(name) LIKE '%moped%'
        OR LOWER(code) LIKE '%motorbike%'
        OR LOWER(code) LIKE '%motorcycle%'
        OR LOWER(code) LIKE '%scooter%'
        OR LOWER(code) LIKE '%moped%'
      );
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-car-suv', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{CAR_ICON}'
      AND (
        LOWER(name) LIKE '%suv%'
        OR LOWER(name) LIKE '%jeep%'
        OR LOWER(name) LIKE '%4wd%'
        OR LOWER(code) LIKE '%suv%'
        OR LOWER(code) LIKE '%jeep%'
        OR LOWER(code) LIKE '%4wd%'
        OR LOWER(code) LIKE '%four_wheel_drive%'
      );
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-caravan', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{BUS_ICON}'
      AND (
        LOWER(name) LIKE '%caravan%'
        OR LOWER(name) LIKE '%camper%'
        OR LOWER(name) LIKE '%motorhome%'
        OR LOWER(name) LIKE '%rv%'
        OR LOWER(code) LIKE '%caravan%'
        OR LOWER(code) LIKE '%camper%'
        OR LOWER(code) LIKE '%motorhome%'
        OR LOWER(code) LIKE '%rv%'
      );
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-truck-delivery', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{PICKUP_TRUCK_ICON}';
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-truck-loading', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{BIG_TRUCK_ICON}';
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-ambulance', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{TRUCK_ICON}'
      AND (
        LOWER(name) LIKE '%ambulance%'
        OR LOWER(code) LIKE '%ambulance%'
      );
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-firetruck', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{TRUCK_ICON}'
      AND (
        LOWER(name) LIKE '%firetruck%'
        OR LOWER(name) LIKE '%fire truck%'
        OR LOWER(name) LIKE '%fire engine%'
        OR LOWER(code) LIKE '%firetruck%'
        OR LOWER(code) LIKE '%fire_truck%'
        OR LOWER(code) LIKE '%fire_engine%'
      );
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-forklift', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{TRUCK_ICON}'
      AND (
        LOWER(name) LIKE '%forklift%'
        OR LOWER(code) LIKE '%forklift%'
      );
    SQL

    execute <<~SQL.squish
      UPDATE vehicle_types
      SET icon_name = 'ti-rv-truck', updated_at = CURRENT_TIMESTAMP
      WHERE icon_name = '#{TRUCK_ICON}'
      AND (
        (LOWER(name) LIKE '%rv%' AND LOWER(name) LIKE '%truck%')
        OR (LOWER(code) LIKE '%rv%' AND LOWER(code) LIKE '%truck%')
      );
    SQL
  end
end
