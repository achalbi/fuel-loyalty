class CreateVehicleTypes < ActiveRecord::Migration[8.1]
  DEFAULT_VEHICLE_TYPES = {
    "two_wheeler" => "Two-Wheeler",
    "three_wheeler" => "Three-Wheeler",
    "lmv" => "LMV",
    "lcv" => "LCV",
    "mcv" => "MCV",
    "hcv" => "HCV"
  }.freeze

  def up
    create_table :vehicle_types do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :vehicle_types, :code, unique: true
    add_index :vehicle_types, :active

    say_with_time "Backfilling vehicle types from defaults and existing vehicles" do
      normalize_vehicle_kinds if table_exists?(:vehicles)

      vehicle_kind_rows = table_exists?(:vehicles) ? execute("SELECT DISTINCT vehicle_kind FROM vehicles") : []

      existing_codes = vehicle_kind_rows.map { |row| normalize_code(row["vehicle_kind"]) }.reject(&:blank?)
      codes = (DEFAULT_VEHICLE_TYPES.keys + existing_codes).uniq

      codes.each do |code|
        execute <<~SQL.squish
          INSERT INTO vehicle_types (code, name, active, created_at, updated_at)
          VALUES (
            #{connection.quote(code)},
            #{connection.quote(DEFAULT_VEHICLE_TYPES[code] || code.humanize)},
            TRUE,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
          )
        SQL
      end
    end
  end

  def down
    remove_index :vehicle_types, :active if index_exists?(:vehicle_types, :active)
    drop_table :vehicle_types, if_exists: true
  end

  private

  def normalize_vehicle_kinds
    execute("SELECT DISTINCT vehicle_kind FROM vehicles").each do |row|
      raw_code = row["vehicle_kind"].to_s
      normalized_code = normalize_code(raw_code)
      next if raw_code.blank? || normalized_code.blank? || raw_code == normalized_code

      execute <<~SQL.squish
        UPDATE vehicles
        SET vehicle_kind = #{connection.quote(normalized_code)}
        WHERE vehicle_kind = #{connection.quote(raw_code)}
      SQL
    end
  end

  def normalize_code(value)
    value.to_s.tr("-", "_").parameterize(separator: "_").tr("-", "_").presence
  end
end
