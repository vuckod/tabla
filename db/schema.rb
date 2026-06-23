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

ActiveRecord::Schema[8.1].define(version: 2026_06_19_100016) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "unaccent"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
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
    t.datetime "created_at", precision: nil, null: false
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

  create_table "ahoy_events", force: :cascade do |t|
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.bigint "user_id"
    t.bigint "visit_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "app_version"
    t.string "browser"
    t.string "city"
    t.string "country"
    t.string "device_type"
    t.string "ip"
    t.text "landing_page"
    t.float "latitude"
    t.float "longitude"
    t.string "os"
    t.string "os_version"
    t.string "platform"
    t.text "referrer"
    t.string "referring_domain"
    t.string "region"
    t.datetime "started_at"
    t.text "user_agent"
    t.bigint "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "announcements", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.datetime "expires_at"
    t.boolean "pinned", default: false, null: false
    t.datetime "published_at", null: false
    t.string "title", null: false
    t.integer "unit", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "updated_by_id"
    t.index ["expires_at"], name: "index_announcements_on_expires_at"
    t.index ["published_at"], name: "index_announcements_on_published_at"
    t.index ["unit"], name: "index_announcements_on_unit"
  end

  create_table "audits", force: :cascade do |t|
    t.string "action"
    t.bigint "associated_id"
    t.string "associated_type"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.text "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.bigint "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "document_categories", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position", default: 0
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_document_categories_on_name", unique: true
    t.index ["slug"], name: "index_document_categories_on_slug", unique: true
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.text "description"
    t.bigint "document_category_id", null: false
    t.boolean "internal_only", default: false, null: false
    t.boolean "notify_staff", default: false, null: false
    t.text "ocr_text"
    t.datetime "published_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "updated_by_id"
    t.index ["document_category_id"], name: "index_documents_on_document_category_id"
    t.index ["internal_only"], name: "index_documents_on_internal_only"
    t.index ["ocr_text"], name: "index_documents_on_ocr_text_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["published_at"], name: "index_documents_on_published_at"
    t.index ["title"], name: "index_documents_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "link_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name", null: false
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_link_categories_on_name", unique: true
  end

  create_table "links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "internal_app", default: false, null: false
    t.bigint "link_category_id", null: false
    t.boolean "new_tab", default: true, null: false
    t.integer "position", default: 0
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["link_category_id"], name: "index_links_on_link_category_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.string "name", null: false
    t.string "phone"
    t.integer "position", default: 0
    t.text "schedule_info"
    t.string "short_code"
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_locations_on_kind"
    t.index ["name"], name: "index_locations_on_name", unique: true
  end

  create_table "ocr_logs", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.float "duration"
    t.text "error_message"
    t.string "filename"
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "started_at", null: false
    t.string "status", default: "processing", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_ocr_logs_on_record"
  end

  create_table "persons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.string "email"
    t.string "first_name"
    t.string "last_name", null: false
    t.bigint "location_id"
    t.string "position_title"
    t.datetime "updated_at", null: false
    t.integer "updated_by_id"
    t.index ["last_name", "first_name"], name: "index_persons_on_last_name_and_first_name"
    t.index ["location_id"], name: "index_persons_on_location_id"
  end

  create_table "phone_numbers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.string "label"
    t.bigint "location_id"
    t.string "number", null: false
    t.bigint "person_id"
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_phone_numbers_on_kind"
    t.index ["location_id"], name: "index_phone_numbers_on_location_id"
    t.index ["person_id"], name: "index_phone_numbers_on_person_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "roles_users", id: false, force: :cascade do |t|
    t.bigint "role_id", null: false
    t.bigint "user_id", null: false
    t.index ["role_id", "user_id"], name: "index_roles_users_on_role_id_and_user_id"
    t.index ["user_id", "role_id"], name: "index_roles_users_on_user_id_and_role_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "ime"
    t.datetime "last_request_at"
    t.datetime "last_synced_at"
    t.boolean "onemogocen", default: false, null: false
    t.string "priimek"
    t.integer "remote_id", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["remote_id"], name: "index_users_on_remote_id", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "documents", "document_categories"
  add_foreign_key "links", "link_categories"
  add_foreign_key "persons", "locations"
  add_foreign_key "phone_numbers", "locations"
  add_foreign_key "phone_numbers", "persons"
end
