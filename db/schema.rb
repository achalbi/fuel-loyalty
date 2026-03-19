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

ActiveRecord::Schema[8.1].define(version: 2026_03_19_095000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 1, null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
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
    t.index ["customer_id"], name: "index_vehicles_on_customer_id"
    t.index ["vehicle_number"], name: "index_vehicles_on_vehicle_number", unique: true
  end

  add_foreign_key "points_ledgers", "customers"
  add_foreign_key "points_ledgers", "transactions"
  add_foreign_key "transactions", "customers"
  add_foreign_key "transactions", "users"
  add_foreign_key "transactions", "vehicles"
  add_foreign_key "vehicles", "customers"
end
