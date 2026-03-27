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

ActiveRecord::Schema[8.1].define(version: 2026_03_27_103000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.string "phone_number", null: false
    t.datetime "updated_at", null: false
    t.string "vehicle_number"
    t.index ["phone_number"], name: "index_customers_on_phone_number", unique: true
  end

  create_table "fuel_reward_rates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fuel_type", null: false
    t.integer "points_per_100", null: false
    t.datetime "updated_at", null: false
    t.index ["fuel_type"], name: "index_fuel_reward_rates_on_fuel_type", unique: true
  end

  create_table "notification_schedules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "day_of_month"
    t.integer "day_of_week"
    t.string "frequency", null: false
    t.datetime "last_sent_at"
    t.text "message", null: false
    t.date "scheduled_date"
    t.string "scheduled_time", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_notification_schedules_on_active"
    t.index ["frequency"], name: "index_notification_schedules_on_frequency"
  end

  create_table "points_ledgers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.integer "entry_type", null: false
    t.integer "points", null: false
    t.bigint "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_points_ledgers_on_customer_id"
    t.index ["transaction_id"], name: "index_points_ledgers_on_transaction_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "last_used_at", null: false
    t.string "platform", null: false
    t.text "token", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_push_subscriptions_on_active"
    t.index ["last_used_at"], name: "index_push_subscriptions_on_last_used_at"
    t.index ["platform"], name: "index_push_subscriptions_on_platform"
    t.index ["token"], name: "index_push_subscriptions_on_token", unique: true
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
    t.string "primary_color", default: "#43B05C", null: false
    t.datetime "updated_at", null: false
  end

  create_table "transactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.decimal "fuel_amount", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "vehicle_id"
    t.index ["customer_id"], name: "index_transactions_on_customer_id"
    t.index ["user_id"], name: "index_transactions_on_user_id"
    t.index ["vehicle_id"], name: "index_transactions_on_vehicle_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", default: "", null: false
    t.string "employee_code"
    t.string "encrypted_password", default: "", null: false
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
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "vehicles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "fuel_type", null: false
    t.datetime "updated_at", null: false
    t.string "vehicle_kind", null: false
    t.string "vehicle_number", null: false
    t.index ["customer_id", "vehicle_number"], name: "index_vehicles_on_customer_id_and_vehicle_number", unique: true
    t.index ["customer_id"], name: "index_vehicles_on_customer_id"
  end

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
  add_foreign_key "points_ledgers", "customers"
  add_foreign_key "points_ledgers", "transactions"
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
  add_foreign_key "transactions", "users"
  add_foreign_key "transactions", "vehicles"
  add_foreign_key "vehicles", "customers"
end
