class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events do |t|
      t.string :name, null: false
      t.string :page_path, null: false
      t.jsonb :properties, null: false, default: {}
      t.text :user_agent
      t.references :user, foreign_key: true
      t.timestamps
    end

    add_index :analytics_events, :name
    add_index :analytics_events, :created_at
  end
end
