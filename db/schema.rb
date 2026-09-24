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

ActiveRecord::Schema[8.1].define(version: 2026_09_24_044306) do
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

  create_table "categories", force: :cascade do |t|
    t.string "category_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_name"], name: "index_categories_on_category_name", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "event_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["category_id"], name: "index_entries_on_category_id"
    t.index ["event_id"], name: "index_entries_on_event_id"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "talk_votes", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.integer "talk_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["talk_id"], name: "index_talk_votes_on_talk_id"
    t.index ["user_id", "talk_id"], name: "index_talk_votes_on_user_id_and_talk_id", unique: true
    t.index ["user_id"], name: "index_talk_votes_on_user_id"
  end

  create_table "talks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "user_name", null: false
    t.index ["event_id", "status"], name: "index_talks_on_event_id_and_status"
    t.index ["event_id"], name: "index_talks_on_event_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "session_digest"
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.integer "entry_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["entry_id"], name: "index_votes_on_entry_id"
    t.index ["user_id", "entry_id"], name: "index_votes_on_user_id_and_entry_id", unique: true
    t.index ["user_id"], name: "index_votes_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "entries", "categories"
  add_foreign_key "entries", "events"
  add_foreign_key "entries", "users"
  add_foreign_key "talk_votes", "talks"
  add_foreign_key "talk_votes", "users"
  add_foreign_key "talks", "events"
  add_foreign_key "votes", "entries"
  add_foreign_key "votes", "users"
end
