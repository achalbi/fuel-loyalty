class AddSubtitleToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :subtitle, :string
  end
end
