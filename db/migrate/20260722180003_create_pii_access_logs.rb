class CreatePiiAccessLogs < ActiveRecord::Migration[8.1]
  # A7 — audit every full-Aadhaar / ID-card reveal: who looked at whose PII,
  # which field, and from where. Append-only.
  def change
    create_table :pii_access_logs do |t|
      t.references :actor_user, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :target_user, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :field, null: false
      t.string :ip
      t.datetime :created_at, null: false
    end
  end
end
