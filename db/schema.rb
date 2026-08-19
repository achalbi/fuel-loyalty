# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_19_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "analytics_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "page_path", null: false
    t.jsonb "properties", default: {}, null: false
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.bigint "user_id"
    t.index ["created_at"], name: "index_analytics_events_on_created_at"
    t.index ["name"], name: "index_analytics_events_on_name"
    t.index ["user_id"], name: "index_analytics_events_on_user_id"
  end

  create_table "attendance_entries", force: :cascade do |t|
    t.bigint "actual_user_id"
    t.bigint "attendance_run_id", null: false
    t.datetime "check_in_at"
    t.datetime "check_out_at"
    t.datetime "created_at", null: false
    t.string "external_replacement_name"
    t.datetime "last_overridden_at"
    t.bigint "last_overridden_by_id"
    t.text "notes"
    t.boolean "overridden", default: false, null: false
    t.bigint "replacement_user_id"
    t.bigint "scheduled_user_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["actual_user_id"], name: "index_attendance_entries_on_actual_user_id"
    t.index ["attendance_run_id", "scheduled_user_id"], name: "index_attendance_entries_on_run_and_scheduled_user", unique: true
    t.index ["attendance_run_id"], name: "index_attendance_entries_on_attendance_run_id"
    t.index ["last_overridden_by_id"], name: "index_attendance_entries_on_last_overridden_by_id"
    t.index ["replacement_user_id"], name: "index_attendance_entries_on_replacement_user_id"
    t.index ["scheduled_user_id"], name: "index_attendance_entries_on_scheduled_user_id"
    t.index ["status"], name: "index_attendance_entries_on_status"
  end

  create_table "attendance_entry_changes", force: :cascade do |t|
    t.jsonb "after_payload", default: {}, null: false
    t.bigint "attendance_entry_id", null: false
    t.jsonb "before_payload", default: {}, null: false
    t.string "change_reason", null: false
    t.bigint "changed_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attendance_entry_id"], name: "index_attendance_entry_changes_on_attendance_entry_id"
    t.index ["changed_by_id"], name: "index_attendance_entry_changes_on_changed_by_id"
  end

  create_table "attendance_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_snapshot_minutes", null: false
    t.datetime "ends_at", null: false
    t.text "notes"
    t.bigint "recorded_by_id", null: false
    t.string "shift_name_snapshot", null: false
    t.bigint "shift_template_id", null: false
    t.boolean "stale", default: false, null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recorded_by_id"], name: "index_attendance_runs_on_recorded_by_id"
    t.index ["shift_template_id", "starts_at"], name: "index_attendance_runs_on_shift_and_starts_at"
    t.index ["shift_template_id"], name: "index_attendance_runs_on_shift_template_id"
    t.index ["stale"], name: "index_attendance_runs_on_stale"
  end

  create_table "campaign_qualifications", force: :cascade do |t|
    t.decimal "aggregated_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "aggregated_litres", precision: 12, scale: 3
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.datetime "notified_at"
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.datetime "qualified_at"
    t.datetime "reward_granted_at"
    t.bigint "reward_points_ledger_id"
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "customer_id", "period_start"], name: "index_campaign_qualifications_unique", unique: true
    t.index ["campaign_id"], name: "index_campaign_qualifications_on_campaign_id"
    t.index ["customer_id"], name: "index_campaign_qualifications_on_customer_id"
    t.index ["reward_points_ledger_id"], name: "index_campaign_qualifications_on_reward_points_ledger_id"
  end

  create_table "campaign_targets", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "customer_id"], name: "index_campaign_targets_on_campaign_id_and_customer_id", unique: true
    t.index ["campaign_id"], name: "index_campaign_targets_on_campaign_id"
    t.index ["customer_id"], name: "index_campaign_targets_on_customer_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.integer "bonus_points"
    t.string "channels", default: "push", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "description"
    t.decimal "discount_amount", precision: 10, scale: 2
    t.decimal "discount_percent", precision: 5, scale: 2
    t.datetime "ends_at"
    t.string "gift_description"
    t.decimal "min_purchase_amount", precision: 10, scale: 2
    t.decimal "min_purchase_litres", precision: 10, scale: 3
    t.string "name", null: false
    t.integer "period", default: 0, null: false
    t.integer "period_days"
    t.integer "reward_kind", default: 0, null: false
    t.datetime "starts_at"
    t.integer "status", default: 0, null: false
    t.string "target_customer_type"
    t.integer "target_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.date "window_end"
    t.date "window_start"
    t.index ["created_by_id"], name: "index_campaigns_on_created_by_id"
    t.index ["status"], name: "index_campaigns_on_status"
  end

  create_table "contact_logs", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "contacted_at", null: false
    t.string "contacted_role"
    t.datetime "created_at", null: false
    t.bigint "customer_contact_id"
    t.bigint "customer_id", null: false
    t.text "notes"
    t.string "outcome", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["customer_contact_id"], name: "index_contact_logs_on_customer_contact_id"
    t.index ["customer_id", "contacted_at"], name: "index_contact_logs_on_customer_id_and_contacted_at"
    t.index ["customer_id"], name: "index_contact_logs_on_customer_id"
    t.index ["user_id"], name: "index_contact_logs_on_user_id"
  end

  create_table "customer_contacts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "contacted", default: false, null: false
    t.datetime "contacted_at"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "name"
    t.text "notes"
    t.string "phone_number"
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "phone_number"], name: "index_customer_contacts_on_customer_and_phone", unique: true, where: "(phone_number IS NOT NULL)"
    t.index ["customer_id", "role"], name: "index_customer_contacts_on_customer_id_and_role"
    t.index ["customer_id"], name: "index_customer_contacts_on_customer_id"
  end

  create_table "customer_feedbacks", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.integer "rating", null: false
    t.bigint "recorded_by_user_id"
    t.string "source", default: "staff", null: false
    t.bigint "transaction_id"
    t.datetime "updated_at", null: false
    t.bigint "visit_entry_id"
    t.index ["customer_id"], name: "index_customer_feedbacks_on_customer_id"
    t.index ["recorded_by_user_id"], name: "index_customer_feedbacks_on_recorded_by_user_id"
    t.index ["transaction_id"], name: "index_customer_feedbacks_on_transaction_id_unique", unique: true, where: "(transaction_id IS NOT NULL)"
    t.index ["visit_entry_id"], name: "index_customer_feedbacks_on_visit_entry_id_unique", unique: true, where: "(visit_entry_id IS NOT NULL)"
  end

  create_table "customer_notes", force: :cascade do |t|
    t.bigint "author_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_customer_notes_on_author_id"
    t.index ["customer_id", "created_at"], name: "index_customer_notes_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_customer_notes_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "approx_vehicle_count"
    t.datetime "created_at", null: false
    t.string "customer_type", default: "drive_in", null: false
    t.integer "last_milestone_points", default: 0, null: false
    t.string "name"
    t.string "phone_number", null: false
    t.bigint "primary_contact_id"
    t.boolean "rewards_paused", default: false, null: false
    t.boolean "sms_opt_in", default: false, null: false
    t.string "transport_name"
    t.datetime "updated_at", null: false
    t.string "vehicle_number"
    t.boolean "whatsapp_opt_in", default: false, null: false
    t.index ["customer_type"], name: "index_customers_on_customer_type"
    t.index ["phone_number"], name: "index_customers_on_phone_number", unique: true
    t.index ["primary_contact_id"], name: "index_customers_on_primary_contact_id"
  end

  create_table "daily_settlements", force: :cascade do |t|
    t.date "business_date", null: false
    t.decimal "counted_cash_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "entered_by_id"
    t.decimal "final_amount_to_settle", precision: 12, scale: 2, default: "0.0", null: false
    t.string "fsm_name_snapshot"
    t.bigint "fuel_pump_id", null: false
    t.boolean "locked", default: false, null: false
    t.text "notes"
    t.bigint "recorded_by_id", null: false
    t.bigint "shift_template_id"
    t.decimal "shortage_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at"
    t.decimal "total_credit_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_digital_receipt_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_discount_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_expense_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_fuel_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_lube_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["business_date"], name: "index_daily_settlements_on_business_date"
    t.index ["entered_by_id"], name: "index_daily_settlements_on_entered_by_id"
    t.index ["fuel_pump_id", "business_date", "shift_template_id"], name: "index_daily_settlements_on_pump_date_shift", unique: true, nulls_not_distinct: true
    t.index ["fuel_pump_id"], name: "index_daily_settlements_on_fuel_pump_id"
    t.index ["recorded_by_id"], name: "index_daily_settlements_on_recorded_by_id"
    t.index ["shift_template_id"], name: "index_daily_settlements_on_shift_template_id"
    t.index ["status"], name: "index_daily_settlements_on_status"
  end

  create_table "fuel_pump_nozzles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "fuel_pump_id", null: false
    t.string "fuel_type_code", null: false
    t.integer "sequence_number", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_fuel_pump_nozzles_on_active"
    t.index ["fuel_pump_id", "sequence_number"], name: "index_fuel_pump_nozzles_on_fuel_pump_id_and_sequence_number", unique: true
    t.index ["fuel_pump_id"], name: "index_fuel_pump_nozzles_on_fuel_pump_id"
    t.index ["fuel_type_code"], name: "index_fuel_pump_nozzles_on_fuel_type_code"
  end

  create_table "fuel_pumps", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "sequence_number", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_fuel_pumps_on_active"
    t.index ["sequence_number"], name: "index_fuel_pumps_on_sequence_number", unique: true
  end

  create_table "fuel_reward_rates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fuel_type", null: false
    t.integer "points_per_100", null: false
    t.datetime "updated_at", null: false
    t.index ["fuel_type"], name: "index_fuel_reward_rates_on_fuel_type", unique: true
  end

  create_table "fuel_types", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_fuel_types_on_active"
    t.index ["code"], name: "index_fuel_types_on_code", unique: true
  end

  create_table "notification_messages", force: :cascade do |t|
    t.text "body"
    t.bigint "campaign_id"
    t.integer "category", default: 0, null: false
    t.string "channels", default: "push", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "notification_schedule_id"
    t.jsonb "offer_payload", default: {}, null: false
    t.string "target_customer_type"
    t.integer "target_type", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_notification_messages_on_campaign_id"
    t.index ["category"], name: "index_notification_messages_on_category"
    t.index ["created_by_id"], name: "index_notification_messages_on_created_by_id"
    t.index ["notification_schedule_id"], name: "index_notification_messages_on_notification_schedule_id"
  end

  create_table "notification_recipients", force: :cascade do |t|
    t.integer "channel", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.string "error"
    t.bigint "notification_message_id", null: false
    t.string "provider_message_id"
    t.bigint "push_subscription_id"
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.string "to_address"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "created_at"], name: "index_notification_recipients_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_notification_recipients_on_customer_id"
    t.index ["notification_message_id"], name: "index_notification_recipients_on_notification_message_id"
    t.index ["push_subscription_id"], name: "index_notification_recipients_on_push_subscription_id"
    t.index ["status"], name: "index_notification_recipients_on_status"
  end

  create_table "notification_schedules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "campaign_id"
    t.string "channels", default: "push", null: false
    t.datetime "created_at", null: false
    t.integer "day_of_month"
    t.integer "day_of_week"
    t.string "frequency", null: false
    t.datetime "last_sent_at"
    t.text "message", null: false
    t.date "scheduled_date"
    t.string "scheduled_time", null: false
    t.string "target_customer_type"
    t.string "target_type", default: "all", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_notification_schedules_on_active"
    t.index ["campaign_id"], name: "index_notification_schedules_on_campaign_id"
    t.index ["frequency"], name: "index_notification_schedules_on_frequency"
  end

  create_table "pii_access_logs", force: :cascade do |t|
    t.bigint "actor_user_id", null: false
    t.datetime "created_at", null: false
    t.string "field", null: false
    t.string "ip"
    t.bigint "target_user_id", null: false
    t.index ["actor_user_id"], name: "index_pii_access_logs_on_actor_user_id"
    t.index ["target_user_id"], name: "index_pii_access_logs_on_target_user_id"
  end

  create_table "points_ledgers", force: :cascade do |t|
    t.decimal "cash_reward_amount", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.integer "entry_type", null: false
    t.integer "points", null: false
    t.bigint "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "created_at"], name: "index_points_ledgers_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_points_ledgers_on_customer_id"
    t.index ["transaction_id"], name: "index_points_ledgers_on_transaction_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "batch"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "fuel_type_code"
    t.string "hsn_code"
    t.decimal "mrp", precision: 10, scale: 2, default: "0.0", null: false
    t.string "name", null: false
    t.decimal "pack_size", precision: 10, scale: 3
    t.string "pack_unit"
    t.decimal "selling_price", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "sl_num"
    t.boolean "track_stock", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_products_on_active"
    t.index ["category"], name: "index_products_on_category"
    t.index ["fuel_type_code"], name: "index_products_on_active_fuel_type", unique: true, where: "(((category)::text = 'fuel'::text) AND active)"
    t.index ["fuel_type_code"], name: "index_products_on_fuel_type_code"
    t.index ["sl_num"], name: "index_products_on_sl_num"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "consent_at"
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.datetime "last_used_at", null: false
    t.string "platform", null: false
    t.text "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["active"], name: "index_push_subscriptions_on_active"
    t.index ["customer_id"], name: "index_push_subscriptions_on_customer_id"
    t.index ["last_used_at"], name: "index_push_subscriptions_on_last_used_at"
    t.index ["platform"], name: "index_push_subscriptions_on_platform"
    t.index ["token"], name: "index_push_subscriptions_on_token", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "reward_settings", force: :cascade do |t|
    t.decimal "cash_value_per_point", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.decimal "litres_per_reward_unit", precision: 6, scale: 2, default: "10.0", null: false
    t.integer "milestone_step", default: 500, null: false
    t.integer "minimum_redeemable_points"
    t.boolean "nozzle_feature_enabled", default: true, null: false
    t.integer "reward_basis", default: 0, null: false
    t.boolean "rewards_paused", default: false, null: false
    t.integer "rupees_per_reward_unit", default: 100, null: false
    t.datetime "updated_at", null: false
  end

  create_table "scheduler_leases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.string "key", null: false
    t.datetime "last_heartbeat_at"
    t.string "lease_token"
    t.boolean "running", default: false, null: false
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_scheduler_leases_on_key", unique: true
    t.index ["running"], name: "index_scheduler_leases_on_running"
  end

  create_table "settlement_cash_denominations", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.integer "denomination", null: false
    t.integer "quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["daily_settlement_id", "denomination"], name: "index_cash_denominations_on_settlement_key", unique: true, nulls_not_distinct: true
    t.index ["daily_settlement_id"], name: "index_settlement_cash_denominations_on_daily_settlement_id"
  end

  create_table "settlement_changes", force: :cascade do |t|
    t.string "change_reason", null: false
    t.bigint "changed_by_id", null: false
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.jsonb "field_diffs", default: {}, null: false
    t.bigint "on_behalf_of_id"
    t.boolean "recomputed_points", default: false, null: false
    t.index ["changed_by_id"], name: "index_settlement_changes_on_changed_by_id"
    t.index ["daily_settlement_id"], name: "index_settlement_changes_on_daily_settlement_id"
    t.index ["on_behalf_of_id"], name: "index_settlement_changes_on_on_behalf_of_id"
  end

  create_table "settlement_credit_lines", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "credit_type", default: 0, null: false
    t.bigint "daily_settlement_id", null: false
    t.decimal "discount_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "litres", precision: 12, scale: 3, default: "0.0", null: false
    t.string "note"
    t.string "reference"
    t.datetime "updated_at", null: false
    t.index ["daily_settlement_id"], name: "index_settlement_credit_lines_on_daily_settlement_id"
  end

  create_table "settlement_decantations", force: :cascade do |t|
    t.decimal "closing_kl", precision: 12, scale: 3
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.string "fuel_type_code"
    t.decimal "opening_kl", precision: 12, scale: 3
    t.string "tank_label"
    t.datetime "updated_at", null: false
    t.index ["daily_settlement_id"], name: "index_settlement_decantations_on_daily_settlement_id"
  end

  create_table "settlement_digital_receipts", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.string "label", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_settlement_id", "label"], name: "index_digital_receipts_on_settlement_key", unique: true
    t.index ["daily_settlement_id"], name: "index_settlement_digital_receipts_on_daily_settlement_id"
  end

  create_table "settlement_discount_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.decimal "discount_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.string "driver_name"
    t.string "driver_phone_number"
    t.decimal "litres", precision: 12, scale: 3, default: "0.0", null: false
    t.string "manager_name"
    t.string "manager_phone_number"
    t.string "owner_name"
    t.string "owner_phone_number"
    t.string "transport_name"
    t.datetime "updated_at", null: false
    t.bigint "visit_entry_id"
    t.index ["daily_settlement_id"], name: "index_settlement_discount_lines_on_daily_settlement_id"
    t.index ["visit_entry_id"], name: "index_settlement_discount_lines_on_visit_entry_id"
  end

  create_table "settlement_expense_lines", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.string "description", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_settlement_id"], name: "index_settlement_expense_lines_on_daily_settlement_id"
  end

  create_table "settlement_lube_lines", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.integer "closing_stock"
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.integer "opening_stock"
    t.bigint "product_id", null: false
    t.string "product_name_snapshot"
    t.integer "quantity", default: 0, null: false
    t.decimal "unit_price", precision: 12, scale: 2
    t.datetime "updated_at", null: false
    t.index ["daily_settlement_id", "product_id"], name: "index_lube_lines_on_settlement_key", unique: true, nulls_not_distinct: true
    t.index ["daily_settlement_id"], name: "index_settlement_lube_lines_on_daily_settlement_id"
    t.index ["product_id"], name: "index_settlement_lube_lines_on_product_id"
  end

  create_table "settlement_nozzle_readings", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.decimal "closing_reading", precision: 12, scale: 3
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.bigint "fuel_pump_nozzle_id", null: false
    t.string "fuel_type_code_snapshot"
    t.decimal "net_litres_sold", precision: 12, scale: 3
    t.decimal "opening_reading", precision: 12, scale: 3
    t.string "opening_source", default: "manual", null: false
    t.boolean "rollover", default: false, null: false
    t.decimal "testing_litres", precision: 12, scale: 3, default: "0.0", null: false
    t.decimal "unit_price", precision: 12, scale: 2
    t.datetime "updated_at", null: false
    t.index ["daily_settlement_id", "fuel_pump_nozzle_id"], name: "index_nozzle_readings_on_settlement_key", unique: true, nulls_not_distinct: true
    t.index ["daily_settlement_id"], name: "index_settlement_nozzle_readings_on_daily_settlement_id"
    t.index ["fuel_pump_nozzle_id"], name: "index_settlement_nozzle_readings_on_fuel_pump_nozzle_id"
  end

  create_table "settlement_rate_comparisons", force: :cascade do |t|
    t.string "competitor_name", default: "JIO-BP", null: false
    t.decimal "competitor_price", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.string "fuel_type_code"
    t.decimal "own_price", precision: 12, scale: 2
    t.datetime "updated_at", null: false
    t.index ["daily_settlement_id", "fuel_type_code", "competitor_name"], name: "index_rate_comparisons_on_settlement_key", unique: true, nulls_not_distinct: true
    t.index ["daily_settlement_id"], name: "index_settlement_rate_comparisons_on_daily_settlement_id"
  end

  create_table "settlement_stock_receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "daily_settlement_id", null: false
    t.string "fuel_type_code"
    t.decimal "litres_received", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_settlement_id", "fuel_type_code"], name: "index_stock_receipts_on_settlement_key", unique: true, nulls_not_distinct: true
    t.index ["daily_settlement_id"], name: "index_settlement_stock_receipts_on_daily_settlement_id"
  end

  create_table "shift_assignments", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "effective_from", null: false
    t.datetime "effective_to"
    t.text "notes"
    t.bigint "shift_cycle_id"
    t.bigint "shift_template_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["active"], name: "index_shift_assignments_on_active"
    t.index ["shift_cycle_id"], name: "index_shift_assignments_on_shift_cycle_id"
    t.index ["shift_template_id", "effective_from"], name: "index_shift_assignments_on_shift_and_effective_from"
    t.index ["shift_template_id"], name: "index_shift_assignments_on_shift_template_id"
    t.index ["user_id", "effective_from"], name: "index_shift_assignments_on_user_and_effective_from"
    t.index ["user_id"], name: "index_shift_assignments_on_user_id"
  end

  create_table "shift_cycle_steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.bigint "shift_cycle_id", null: false
    t.bigint "shift_template_id", null: false
    t.datetime "updated_at", null: false
    t.index ["shift_cycle_id", "position"], name: "index_shift_cycle_steps_on_shift_cycle_id_and_position", unique: true
    t.index ["shift_cycle_id", "shift_template_id"], name: "index_shift_cycle_steps_on_cycle_and_shift"
    t.index ["shift_cycle_id"], name: "index_shift_cycle_steps_on_shift_cycle_id"
    t.index ["shift_template_id"], name: "index_shift_cycle_steps_on_shift_template_id"
  end

  create_table "shift_cycles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "period_days", default: 1, null: false
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_shift_cycles_on_active"
    t.index ["name"], name: "index_shift_cycles_on_name", unique: true
  end

  create_table "shift_swaps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.bigint "from_shift_template_id", null: false
    t.bigint "from_user_id", null: false
    t.text "reason", null: false
    t.bigint "recorded_by_id", null: false
    t.datetime "starts_at", null: false
    t.integer "swap_kind", default: 0, null: false
    t.bigint "to_shift_template_id"
    t.bigint "to_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["from_shift_template_id"], name: "index_shift_swaps_on_from_shift_template_id"
    t.index ["from_user_id", "starts_at"], name: "index_shift_swaps_on_from_user_and_starts_at"
    t.index ["from_user_id"], name: "index_shift_swaps_on_from_user_id"
    t.index ["recorded_by_id"], name: "index_shift_swaps_on_recorded_by_id"
    t.index ["to_shift_template_id"], name: "index_shift_swaps_on_to_shift_template_id"
    t.index ["to_user_id", "starts_at"], name: "index_shift_swaps_on_to_user_and_starts_at"
    t.index ["to_user_id"], name: "index_shift_swaps_on_to_user_id"
  end

  create_table "shift_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "duration_minutes", null: false
    t.string "name", null: false
    t.string "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_shift_templates_on_active"
    t.index ["name"], name: "index_shift_templates_on_name", unique: true
  end

  create_table "theme_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "primary_color", default: "#1D63B0", null: false
    t.datetime "updated_at", null: false
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "amount_source", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "fuel_amount", precision: 10, scale: 2, null: false
    t.bigint "fuel_pump_id"
    t.bigint "fuel_pump_nozzle_id"
    t.decimal "gross_amount", precision: 10, scale: 2
    t.decimal "litres", precision: 9, scale: 3
    t.string "payment_mode", default: "cash", null: false
    t.bigint "product_id"
    t.decimal "selling_price_snapshot", precision: 8, scale: 2
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "vehicle_id"
    t.index ["customer_id", "created_at"], name: "index_transactions_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_transactions_on_customer_id"
    t.index ["fuel_pump_id"], name: "index_transactions_on_fuel_pump_id"
    t.index ["fuel_pump_nozzle_id"], name: "index_transactions_on_fuel_pump_nozzle_id"
    t.index ["product_id"], name: "index_transactions_on_product_id"
    t.index ["user_id"], name: "index_transactions_on_user_id"
    t.index ["vehicle_id"], name: "index_transactions_on_vehicle_id"
  end

  create_table "user_pump_assignments", force: :cascade do |t|
    t.bigint "assigned_by_id"
    t.jsonb "assigned_fuel_pump_nozzle_ids", default: [], null: false
    t.date "assigned_on", null: false
    t.datetime "created_at", null: false
    t.bigint "fuel_pump_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["assigned_by_id"], name: "index_user_pump_assignments_on_assigned_by_id"
    t.index ["assigned_on"], name: "index_user_pump_assignments_on_assigned_on"
    t.index ["fuel_pump_id"], name: "index_user_pump_assignments_on_fuel_pump_id"
    t.index ["user_id", "assigned_on"], name: "index_user_pump_assignments_on_user_and_date", unique: true
    t.index ["user_id"], name: "index_user_pump_assignments_on_user_id"
  end

  create_table "user_pump_nozzle_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "fuel_pump_nozzle_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["fuel_pump_nozzle_id"], name: "index_user_pump_nozzle_assignments_on_fuel_pump_nozzle_id"
    t.index ["user_id", "fuel_pump_nozzle_id"], name: "index_user_pump_nozzle_assignments_on_user_and_nozzle", unique: true
    t.index ["user_id"], name: "index_user_pump_nozzle_assignments_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "aadhaar_last4", limit: 4
    t.text "aadhaar_number"
    t.boolean "active", default: true, null: false
    t.text "address"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", default: "", null: false
    t.string "employee_code"
    t.string "encrypted_password", default: "", null: false
    t.bigint "fuel_pump_id"
    t.string "name", null: false
    t.string "phone_number"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 1, null: false
    t.string "subtitle"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["employee_code"], name: "index_users_on_employee_code", unique: true
    t.index ["fuel_pump_id"], name: "index_users_on_fuel_pump_id"
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "vehicle_type_reward_offers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.string "name", null: false
    t.decimal "points_per_rupee", precision: 8, scale: 2, null: false
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
    t.string "vehicle_type_code", null: false
    t.index ["active"], name: "index_vehicle_type_reward_offers_on_active"
    t.index ["vehicle_type_code", "active"], name: "index_vehicle_type_reward_offers_on_type_and_active"
    t.index ["vehicle_type_code"], name: "index_vehicle_type_reward_offers_on_vehicle_type_code"
  end

  create_table "vehicle_types", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "app_label_source", default: "short_name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "icon_name", null: false
    t.integer "minimum_redeemable_points", default: 100, null: false
    t.string "name", null: false
    t.integer "reward_points_per_100"
    t.decimal "reward_points_per_rupee", precision: 8, scale: 2
    t.string "short_name", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_vehicle_types_on_active"
    t.index ["code"], name: "index_vehicle_types_on_code", unique: true
  end

  create_table "vehicles", force: :cascade do |t|
    t.text "commercial_address"
    t.string "commercial_company_name"
    t.string "commercial_contact_name"
    t.string "commercial_contact_phone_number"
    t.text "commercial_notes"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "fuel_type", null: false
    t.datetime "updated_at", null: false
    t.string "vehicle_kind", null: false
    t.string "vehicle_number", null: false
    t.index ["customer_id", "vehicle_number"], name: "index_vehicles_on_customer_id_and_vehicle_number", unique: true
    t.index ["customer_id"], name: "index_vehicles_on_customer_id"
  end

  create_table "visit_entries", force: :cascade do |t|
    t.integer "approx_vehicle_count"
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "driver_name"
    t.string "driver_phone_number"
    t.date "entry_date", null: false
    t.boolean "fleet_otp", default: false, null: false
    t.bigint "fuel_pump_id", null: false
    t.string "fuel_type_code"
    t.decimal "litres", precision: 10, scale: 3, null: false
    t.string "manager_name"
    t.string "manager_phone_number"
    t.string "owner_name"
    t.string "owner_phone_number"
    t.bigint "transaction_id"
    t.string "transport_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "vehicle_id"
    t.string "vehicle_number", null: false
    t.index ["customer_id", "entry_date"], name: "index_visit_entries_on_customer_id_and_entry_date"
    t.index ["customer_id"], name: "index_visit_entries_on_customer_id"
    t.index ["entry_date"], name: "index_visit_entries_on_entry_date"
    t.index ["fuel_pump_id", "entry_date"], name: "index_visit_entries_on_fuel_pump_id_and_entry_date"
    t.index ["fuel_pump_id"], name: "index_visit_entries_on_fuel_pump_id"
    t.index ["transaction_id"], name: "index_visit_entries_on_transaction_id"
    t.index ["user_id"], name: "index_visit_entries_on_user_id"
    t.index ["vehicle_id"], name: "index_visit_entries_on_vehicle_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "analytics_events", "users"
  add_foreign_key "attendance_entries", "attendance_runs"
  add_foreign_key "attendance_entries", "users", column: "actual_user_id"
  add_foreign_key "attendance_entries", "users", column: "last_overridden_by_id"
  add_foreign_key "attendance_entries", "users", column: "replacement_user_id"
  add_foreign_key "attendance_entries", "users", column: "scheduled_user_id"
  add_foreign_key "attendance_entry_changes", "attendance_entries"
  add_foreign_key "attendance_entry_changes", "users", column: "changed_by_id"
  add_foreign_key "attendance_runs", "shift_templates"
  add_foreign_key "attendance_runs", "users", column: "recorded_by_id"
  add_foreign_key "campaign_qualifications", "campaigns", on_delete: :cascade
  add_foreign_key "campaign_qualifications", "customers", on_delete: :cascade
  add_foreign_key "campaign_qualifications", "points_ledgers", column: "reward_points_ledger_id", on_delete: :nullify
  add_foreign_key "campaign_targets", "campaigns", on_delete: :cascade
  add_foreign_key "campaign_targets", "customers", on_delete: :cascade
  add_foreign_key "campaigns", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "contact_logs", "customer_contacts", on_delete: :nullify
  add_foreign_key "contact_logs", "customers"
  add_foreign_key "contact_logs", "users"
  add_foreign_key "customer_contacts", "customers", on_delete: :cascade
  add_foreign_key "customer_feedbacks", "customers"
  add_foreign_key "customer_feedbacks", "transactions", on_delete: :nullify
  add_foreign_key "customer_feedbacks", "users", column: "recorded_by_user_id", on_delete: :nullify
  add_foreign_key "customer_feedbacks", "visit_entries", on_delete: :nullify
  add_foreign_key "customer_notes", "customers"
  add_foreign_key "customer_notes", "users", column: "author_id"
  add_foreign_key "customers", "customer_contacts", column: "primary_contact_id", on_delete: :nullify
  add_foreign_key "daily_settlements", "fuel_pumps", on_delete: :restrict
  add_foreign_key "daily_settlements", "shift_templates", on_delete: :nullify
  add_foreign_key "daily_settlements", "users", column: "entered_by_id", on_delete: :nullify
  add_foreign_key "daily_settlements", "users", column: "recorded_by_id", on_delete: :restrict
  add_foreign_key "fuel_pump_nozzles", "fuel_pumps"
  add_foreign_key "fuel_pump_nozzles", "fuel_types", column: "fuel_type_code", primary_key: "code"
  add_foreign_key "notification_messages", "campaigns", on_delete: :nullify
  add_foreign_key "notification_messages", "notification_schedules", on_delete: :nullify
  add_foreign_key "notification_messages", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "notification_recipients", "customers", on_delete: :nullify
  add_foreign_key "notification_recipients", "notification_messages", on_delete: :cascade
  add_foreign_key "notification_recipients", "push_subscriptions", on_delete: :nullify
  add_foreign_key "notification_schedules", "campaigns", on_delete: :nullify
  add_foreign_key "pii_access_logs", "users", column: "actor_user_id", on_delete: :cascade
  add_foreign_key "pii_access_logs", "users", column: "target_user_id", on_delete: :cascade
  add_foreign_key "points_ledgers", "customers"
  add_foreign_key "points_ledgers", "transactions"
  add_foreign_key "products", "fuel_types", column: "fuel_type_code", primary_key: "code"
  add_foreign_key "push_subscriptions", "customers", on_delete: :nullify
  add_foreign_key "push_subscriptions", "users", on_delete: :nullify
  add_foreign_key "settlement_cash_denominations", "daily_settlements", on_delete: :cascade
  add_foreign_key "settlement_changes", "daily_settlements", on_delete: :cascade
  add_foreign_key "settlement_changes", "users", column: "changed_by_id", on_delete: :restrict
  add_foreign_key "settlement_changes", "users", column: "on_behalf_of_id", on_delete: :nullify
  add_foreign_key "settlement_credit_lines", "daily_settlements", on_delete: :cascade
  add_foreign_key "settlement_decantations", "daily_settlements", on_delete: :cascade
  add_foreign_key "settlement_digital_receipts", "daily_settlements"
  add_foreign_key "settlement_discount_lines", "daily_settlements", on_delete: :cascade
  add_foreign_key "settlement_discount_lines", "visit_entries", on_delete: :nullify
  add_foreign_key "settlement_expense_lines", "daily_settlements"
  add_foreign_key "settlement_lube_lines", "daily_settlements", on_delete: :cascade
  add_foreign_key "settlement_lube_lines", "products", on_delete: :restrict
  add_foreign_key "settlement_nozzle_readings", "daily_settlements", on_delete: :cascade
  add_foreign_key "settlement_nozzle_readings", "fuel_pump_nozzles", on_delete: :restrict
  add_foreign_key "settlement_rate_comparisons", "daily_settlements", on_delete: :cascade
  add_foreign_key "settlement_stock_receipts", "daily_settlements", on_delete: :cascade
  add_foreign_key "shift_assignments", "shift_cycles"
  add_foreign_key "shift_assignments", "shift_templates"
  add_foreign_key "shift_assignments", "users"
  add_foreign_key "shift_cycle_steps", "shift_cycles"
  add_foreign_key "shift_cycle_steps", "shift_templates"
  add_foreign_key "shift_swaps", "shift_templates", column: "from_shift_template_id"
  add_foreign_key "shift_swaps", "shift_templates", column: "to_shift_template_id"
  add_foreign_key "shift_swaps", "users", column: "from_user_id"
  add_foreign_key "shift_swaps", "users", column: "recorded_by_id"
  add_foreign_key "shift_swaps", "users", column: "to_user_id"
  add_foreign_key "transactions", "customers"
  add_foreign_key "transactions", "fuel_pump_nozzles"
  add_foreign_key "transactions", "fuel_pumps"
  add_foreign_key "transactions", "products"
  add_foreign_key "transactions", "users"
  add_foreign_key "transactions", "vehicles"
  add_foreign_key "user_pump_assignments", "fuel_pumps"
  add_foreign_key "user_pump_assignments", "users"
  add_foreign_key "user_pump_assignments", "users", column: "assigned_by_id"
  add_foreign_key "user_pump_nozzle_assignments", "fuel_pump_nozzles"
  add_foreign_key "user_pump_nozzle_assignments", "users"
  add_foreign_key "users", "fuel_pumps"
  add_foreign_key "vehicles", "customers"
  add_foreign_key "visit_entries", "customers", on_delete: :nullify
  add_foreign_key "visit_entries", "fuel_pumps", on_delete: :restrict
  add_foreign_key "visit_entries", "transactions", on_delete: :nullify
  add_foreign_key "visit_entries", "users", on_delete: :restrict
  add_foreign_key "visit_entries", "vehicles", on_delete: :nullify
end
