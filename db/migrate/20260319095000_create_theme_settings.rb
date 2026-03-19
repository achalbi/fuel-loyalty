class CreateThemeSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :theme_settings do |t|
      t.string :primary_color, null: false, default: "#43B05C"

      t.timestamps
    end
  end
end
