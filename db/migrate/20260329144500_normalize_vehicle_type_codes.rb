class NormalizeVehicleTypeCodes < ActiveRecord::Migration[8.1]
  def up
    say_with_time "Normalizing vehicle type codes and vehicle kind values" do
      normalize_vehicle_kinds
      normalize_vehicle_type_codes
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Normalized vehicle type codes cannot be restored automatically"
  end

  private

  def normalize_vehicle_kinds
    return unless table_exists?(:vehicles)

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

  def normalize_vehicle_type_codes
    return unless table_exists?(:vehicle_types)

    execute("SELECT id, code, active FROM vehicle_types ORDER BY id").each do |row|
      row_id = row["id"]
      raw_code = row["code"].to_s
      normalized_code = normalize_code(raw_code)
      next if raw_code.blank? || normalized_code.blank? || raw_code == normalized_code

      existing_row = execute(<<~SQL.squish).first
        SELECT id, active
        FROM vehicle_types
        WHERE code = #{connection.quote(normalized_code)}
        LIMIT 1
      SQL

      if existing_row
        if truthy_value?(row["active"]) && !truthy_value?(existing_row["active"])
          execute <<~SQL.squish
            UPDATE vehicle_types
            SET active = TRUE, updated_at = CURRENT_TIMESTAMP
            WHERE id = #{connection.quote(existing_row["id"])}
          SQL
        end

        execute <<~SQL.squish
          DELETE FROM vehicle_types
          WHERE id = #{connection.quote(row_id)}
        SQL
      else
        execute <<~SQL.squish
          UPDATE vehicle_types
          SET code = #{connection.quote(normalized_code)}, updated_at = CURRENT_TIMESTAMP
          WHERE id = #{connection.quote(row_id)}
        SQL
      end
    end
  end

  def normalize_code(value)
    value.to_s.tr("-", "_").parameterize(separator: "_").tr("-", "_").presence
  end

  def truthy_value?(value)
    value == true || value.to_s == "t" || value.to_s == "true" || value.to_s == "1"
  end
end
