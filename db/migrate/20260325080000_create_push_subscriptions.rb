class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.text :token, null: false
      t.string :platform, null: false
      t.datetime :last_used_at, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :push_subscriptions, :token, unique: true
    add_index :push_subscriptions, :active
    add_index :push_subscriptions, :platform
    add_index :push_subscriptions, :last_used_at
  end
end
