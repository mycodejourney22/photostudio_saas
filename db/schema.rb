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

ActiveRecord::Schema[7.1].define(version: 2025_06_12_150157) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointments", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "user_id", null: false
    t.bigint "studio_id"
    t.datetime "scheduled_at", null: false
    t.integer "duration_minutes", default: 60, null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "session_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.text "notes"
    t.text "special_requirements"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "status"], name: "index_appointments_on_customer_id_and_status"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["studio_id"], name: "index_appointments_on_studio_id"
    t.index ["tenant_id", "scheduled_at"], name: "index_appointments_on_tenant_id_and_scheduled_at"
    t.index ["tenant_id"], name: "index_appointments_on_tenant_id"
    t.index ["user_id", "scheduled_at"], name: "index_appointments_on_user_id_and_scheduled_at"
    t.index ["user_id"], name: "index_appointments_on_user_id"
  end

  create_table "brandings", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "primary_color", default: "#667eea"
    t.string "secondary_color"
    t.string "font_family", default: "Inter"
    t.string "custom_domain"
    t.text "welcome_message"
    t.json "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_domain"], name: "index_brandings_on_custom_domain", unique: true
    t.index ["tenant_id"], name: "index_brandings_on_tenant_id", unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "zip_code"
    t.string "country"
    t.date "date_of_birth"
    t.text "notes"
    t.text "preferences"
    t.boolean "active"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_customers_on_tenant_id"
  end

  create_table "studios", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.string "location"
    t.text "description"
    t.integer "capacity", default: 1
    t.text "equipment"
    t.boolean "active", default: true, null: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "active"], name: "index_studios_on_tenant_id_and_active"
    t.index ["tenant_id"], name: "index_studios_on_tenant_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "subscriber_type", null: false
    t.bigint "subscriber_id", null: false
    t.string "stripe_subscription_id", null: false
    t.integer "plan_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.decimal "amount", precision: 10, scale: 2
    t.string "currency", default: "usd"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "current_period_end"], name: "index_subscriptions_on_status_and_current_period_end"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
    t.index ["subscriber_type", "subscriber_id"], name: "index_subscriptions_on_subscriber"
    t.index ["subscriber_type", "subscriber_id"], name: "index_subscriptions_on_subscriber_type_and_subscriber_id"
  end

  create_table "tenant_users", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "user_id", null: false
    t.integer "role"
    t.boolean "active"
    t.string "invitation_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_tenant_users_on_tenant_id"
    t.index ["user_id"], name: "index_tenant_users_on_user_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "email", null: false
    t.integer "plan_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "verification_token"
    t.datetime "verified_at"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_tenants_on_email", unique: true
    t.index ["subdomain"], name: "index_tenants_on_subdomain", unique: true
    t.index ["verification_token"], name: "index_tenants_on_verification_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.text "bio"
    t.boolean "active", default: true, null: false
    t.boolean "super_admin", default: false, null: false
    t.json "preferences", default: {}
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "tenants"
  add_foreign_key "appointments", "users"
  add_foreign_key "brandings", "tenants"
  add_foreign_key "customers", "tenants"
  add_foreign_key "studios", "tenants"
  add_foreign_key "tenant_users", "tenants"
  add_foreign_key "tenant_users", "users"
end
