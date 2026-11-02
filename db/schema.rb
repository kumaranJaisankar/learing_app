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

ActiveRecord::Schema[8.1].define(version: 2026_10_05_183000) do
  create_table "agent_identities", force: :cascade do |t|
    t.string "domain", null: false
    t.string "selector", default: "unikey", null: false
    t.text "public_key", null: false
    t.decimal "authorized_budget", precision: 10, scale: 2, default: "500.0", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "simulated_private_key"
    t.index ["domain"], name: "index_agent_identities_on_domain", unique: true
  end

  create_table "orders", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "agent_identity_id"
    t.integer "trust_packet_ledger_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "total_amount", precision: 10, scale: 2, null: false
    t.string "status", default: "fulfilled", null: false
    t.text "response_packet"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_identity_id"], name: "index_orders_on_agent_identity_id"
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["trust_packet_ledger_id"], name: "index_orders_on_trust_packet_ledger_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.string "sku", null: false
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "stock", default: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "trust_packet_ledgers", force: :cascade do |t|
    t.string "packet_id", null: false
    t.string "signer_domain", null: false
    t.string "subject", null: false
    t.string "action", null: false
    t.string "status", null: false
    t.string "failure_reason"
    t.string "payload_digest"
    t.text "raw_packet", null: false
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["packet_id"], name: "index_trust_packet_ledgers_on_packet_id", unique: true
  end

  add_foreign_key "orders", "agent_identities"
  add_foreign_key "orders", "products"
  add_foreign_key "orders", "trust_packet_ledgers"
end
