class UpdateThemeDefaultToNayara < ActiveRecord::Migration[8.0]
  OLD_DEFAULT = "#43B05C".freeze
  NEW_DEFAULT = "#1D63B0".freeze # Nayara action primary (navy-700)

  def up
    change_column_default :theme_settings, :primary_color, from: OLD_DEFAULT, to: NEW_DEFAULT
    # Migrate rows still on the old default so existing installs pick up the brand.
    execute <<~SQL.squish
      UPDATE theme_settings SET primary_color = '#{NEW_DEFAULT}' WHERE UPPER(primary_color) = '#{OLD_DEFAULT}'
    SQL
  end

  def down
    change_column_default :theme_settings, :primary_color, from: NEW_DEFAULT, to: OLD_DEFAULT
    execute <<~SQL.squish
      UPDATE theme_settings SET primary_color = '#{OLD_DEFAULT}' WHERE UPPER(primary_color) = '#{NEW_DEFAULT}'
    SQL
  end
end
