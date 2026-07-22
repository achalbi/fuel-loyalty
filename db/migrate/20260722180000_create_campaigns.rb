class CreateCampaigns < ActiveRecord::Migration[8.1]
  # Phase 3 (F1) — the campaign engine: reward customers who cross a
  # minimum-purchase threshold within a period window, targeted at all / a
  # customer type / individuals / a hand-picked set, delivered as an offer via
  # the notification engine. See docs/acefuels/16-spec-campaigns-notifications.md.
  def change
    create_table :campaigns do |t|
      t.string :name, null: false
      t.text :description
      t.integer :reward_kind, null: false, default: 0 # discount / gift / bonus_points
      t.decimal :discount_amount, precision: 10, scale: 2
      t.decimal :discount_percent, precision: 5, scale: 2
      t.string :gift_description
      t.integer :bonus_points
      t.decimal :min_purchase_amount, precision: 10, scale: 2
      t.decimal :min_purchase_litres, precision: 10, scale: 3
      t.integer :period, null: false, default: 0 # rolling_days / weekly / monthly / fixed_window
      t.integer :period_days
      t.date :window_start
      t.date :window_end
      t.integer :target_type, null: false, default: 0 # all / customer_type / individual / selected
      t.string :target_customer_type
      t.string :channels, null: false, default: "push"
      t.integer :status, null: false, default: 0 # draft / scheduled / active / paused / completed
      t.datetime :starts_at
      t.datetime :ends_at
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :campaigns, :status

    create_table :campaign_targets do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.references :customer, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :campaign_targets, %i[campaign_id customer_id], unique: true

    create_table :campaign_qualifications do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.references :customer, null: false, foreign_key: { on_delete: :cascade }
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.decimal :aggregated_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :aggregated_litres, precision: 12, scale: 3
      t.datetime :qualified_at
      t.datetime :reward_granted_at
      t.references :reward_points_ledger, foreign_key: { to_table: :points_ledgers, on_delete: :nullify }
      t.datetime :notified_at
      t.timestamps
    end
    add_index :campaign_qualifications, %i[campaign_id customer_id period_start], unique: true,
      name: "index_campaign_qualifications_unique"

    # F3 wiring — an offer notification remembers its campaign source.
    add_reference :notification_messages, :campaign, foreign_key: { on_delete: :nullify }
  end
end
