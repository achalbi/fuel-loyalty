class AddUsernameToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :username, :string

    execute <<~SQL.squish
      UPDATE users
      SET username = CASE
        WHEN email = 'admin@fuelloyalty.test' THEN 'admin'
        WHEN email = 'staff@fuelloyalty.test' THEN 'staff'
        ELSE 'user' || id
      END
      WHERE username IS NULL
    SQL

    change_column_null :users, :username, false
    add_index :users, :username, unique: true
  end

  def down
    remove_index :users, :username
    remove_column :users, :username
  end
end
