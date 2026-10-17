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

ActiveRecord::Schema[7.1].define(version: 2026_10_17_192337) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "alerts", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "product_id", null: false
    t.bigint "store_id", null: false
    t.bigint "first_event_id", null: false
    t.bigint "second_event_id", null: false
    t.datetime "triggered_at", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_alerts_on_brand_id"
    t.index ["product_id"], name: "index_alerts_on_product_id"
    t.index ["second_event_id"], name: "index_alerts_on_second_event_id", unique: true
    t.index ["store_id"], name: "index_alerts_on_store_id"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "csv_imports", force: :cascade do |t|
    t.string "checksum", null: false
    t.integer "row_count", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checksum"], name: "index_csv_imports_on_checksum", unique: true
  end

  create_table "price_checks", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "store_id", null: false
    t.datetime "event_time", null: false
    t.integer "price_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "event_time"], name: "index_price_checks_on_product_id_and_event_time"
    t.index ["store_id", "event_time"], name: "index_price_checks_on_store_id_and_event_time"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["name"], name: "index_products_on_name", unique: true
  end

  create_table "stores", force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_stores_on_address", unique: true
  end

  create_table "tracking_events", force: :cascade do |t|
    t.boolean "inventory_present", null: false
    t.bigint "product_id", null: false
    t.bigint "store_id", null: false
    t.datetime "event_time", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "event_time"], name: "index_tracking_events_on_product_id_and_event_time"
    t.index ["product_id", "store_id", "event_time", "id"], name: "index_tracking_events_on_product_store_event_id"
    t.index ["store_id", "event_time"], name: "index_tracking_events_on_store_id_and_event_time"
  end

  add_foreign_key "alerts", "brands"
  add_foreign_key "alerts", "products"
  add_foreign_key "alerts", "stores"
  add_foreign_key "alerts", "tracking_events", column: "first_event_id"
  add_foreign_key "alerts", "tracking_events", column: "second_event_id"
  add_foreign_key "price_checks", "products"
  add_foreign_key "price_checks", "stores"
  add_foreign_key "products", "brands"
  add_foreign_key "tracking_events", "products"
  add_foreign_key "tracking_events", "stores"
end
