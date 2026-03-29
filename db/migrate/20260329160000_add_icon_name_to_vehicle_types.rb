class AddIconNameToVehicleTypes < ActiveRecord::Migration[8.1]
  def up
    add_column :vehicle_types, :icon_name, :string

    say_with_time "Backfilling vehicle type icons" do
      execute("SELECT id, code, name FROM vehicle_types").each do |row|
        execute <<~SQL.squish
          UPDATE vehicle_types
          SET icon_name = #{connection.quote(suggested_icon_name_for(row["code"], row["name"]))}
          WHERE id = #{connection.quote(row["id"])}
        SQL
      end
    end

    change_column_null :vehicle_types, :icon_name, false
  end

  def down
    remove_column :vehicle_types, :icon_name
  end

  private

  def suggested_icon_name_for(code, name)
    normalized_text = [code, name].filter_map { |value| normalize_text(value) }.join("_")
    return "ti-car" if normalized_text.blank?

    case normalized_text
    when /ambulance/
      "ti-ambulance"
    when /firetruck|fire_truck|fire_engine/
      "ti-firetruck"
    when /tractor/
      "ti-tractor"
    when /bus|coach/
      "ti-bus"
    when /caravan|camper|motorhome|rv/
      "ti-caravan"
    when /forklift/
      "ti-forklift"
    when /pickup|delivery|cargo|goods|lorry|truck|hcv|mcv|lcv/
      "ti-truck"
    when /suv|jeep|4wd|four_wheel_drive/
      "ti-car-suv"
    when /three_wheeler|three_wheel|rickshaw|auto|trike/
      "ti-scooter"
    when /motorbike|motor_cycle|motorcycle/
      "ti-motorbike"
    when /moped/
      "ti-moped"
    when /scooter|electric|ev/
      "ti-scooter-electric"
    when /bike|bicycle|cycle|two_wheeler|two_wheel/
      "ti-bike"
    else
      "ti-car"
    end
  end

  def normalize_text(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "").presence
  end
end
