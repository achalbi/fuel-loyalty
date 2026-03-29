class CreateFuelTypesAndMoveActiveFromRewardRates < ActiveRecord::Migration[8.1]
  DEFAULT_FUEL_TYPES = {
    "petrol" => "Petrol",
    "diesel" => "Diesel",
    "cng_lpg" => "CNG / LPG"
  }.freeze

  def up
    create_table :fuel_types do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :fuel_types, :code, unique: true
    add_index :fuel_types, :active

    say_with_time "Backfilling fuel types from existing reward rates" do
      reward_rows = if table_exists?(:fuel_reward_rates)
        execute("SELECT DISTINCT fuel_type, active FROM fuel_reward_rates")
      else
        []
      end

      reward_state_by_code = reward_rows.each_with_object({}) do |row, result|
        result[row["fuel_type"].to_s] = ActiveModel::Type::Boolean.new.cast(row["active"])
      end

      codes = (DEFAULT_FUEL_TYPES.keys + reward_state_by_code.keys).uniq

      codes.each do |code|
        next if code.blank?

        execute <<~SQL.squish
          INSERT INTO fuel_types (code, name, active, created_at, updated_at)
          VALUES (
            #{connection.quote(code)},
            #{connection.quote(DEFAULT_FUEL_TYPES[code] || code.humanize)},
            #{reward_state_by_code.fetch(code, true)},
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
          )
        SQL
      end
    end

    remove_column :fuel_reward_rates, :active, :boolean if column_exists?(:fuel_reward_rates, :active)
  end

  def down
    add_column :fuel_reward_rates, :active, :boolean, null: false, default: true unless column_exists?(:fuel_reward_rates, :active)

    if table_exists?(:fuel_types) && table_exists?(:fuel_reward_rates)
      execute <<~SQL.squish
        UPDATE fuel_reward_rates
        SET active = fuel_types.active
        FROM fuel_types
        WHERE fuel_reward_rates.fuel_type = fuel_types.code
      SQL
    end

    remove_index :fuel_types, :active if index_exists?(:fuel_types, :active)
    drop_table :fuel_types, if_exists: true
  end
end
