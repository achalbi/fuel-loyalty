class AddNotificationEngine < ActiveRecord::Migration[8.1]
  # Phase 3 (F2/F3/F4 foundation) — turn the single anonymous push broadcast
  # into a targeted, multi-channel, logged notification system. Adds the
  # per-recipient delivery log (notification_messages + notification_recipients),
  # the customer channel opt-ins + milestone marker, and a push-subscription
  # consent timestamp. See docs/acefuels/16-spec-campaigns-notifications.md.
  def change
    change_table :customers, bulk: true do |t|
      t.boolean :whatsapp_opt_in, null: false, default: false
      t.boolean :sms_opt_in, null: false, default: false
      t.integer :last_milestone_points, null: false, default: 0
    end

    add_column :push_subscriptions, :consent_at, :datetime

    create_table :notification_messages do |t|
      t.references :notification_schedule, foreign_key: { on_delete: :nullify }
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :title, null: false
      t.text :body
      t.integer :category, null: false, default: 0 # broadcast / offer / loyalty_milestone / scheduled
      t.jsonb :offer_payload, null: false, default: {}
      t.integer :target_type, null: false, default: 0 # all / customer_type / individual / selected
      t.string :target_customer_type
      t.string :channels, null: false, default: "push"
      t.timestamps
    end
    add_index :notification_messages, :category

    create_table :notification_recipients do |t|
      t.references :notification_message, null: false, foreign_key: { on_delete: :cascade }
      t.references :customer, foreign_key: { on_delete: :nullify }
      t.references :push_subscription, foreign_key: { on_delete: :nullify }
      t.integer :channel, null: false, default: 0 # push / whatsapp / sms
      t.string :to_address
      t.integer :status, null: false, default: 0 # pending / sent / failed / invalidated / skipped
      t.string :provider_message_id
      t.string :error
      t.datetime :sent_at
      t.timestamps
    end
    add_index :notification_recipients, %i[customer_id created_at]
    add_index :notification_recipients, :status
  end
end
