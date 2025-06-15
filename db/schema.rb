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

ActiveRecord::Schema[7.1].define(version: 2025_06_15_201122) do
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
    t.bigint "service_tier_id", null: false
    t.bigint "service_package_id", null: false
    t.bigint "studio_location_id", null: false
    t.integer "payment_status", default: 0, null: false
    t.integer "booking_source", default: 0, null: false
    t.decimal "paid_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "deposit_amount", precision: 10, scale: 2
    t.string "payment_reference"
    t.string "payment_method"
    t.datetime "payment_received_at"
    t.bigint "assigned_photographer_id"
    t.bigint "assigned_editor_id"
    t.datetime "shoot_completed_at"
    t.datetime "editing_completed_at"
    t.date "delivery_date"
    t.text "equipment_used"
    t.text "production_notes"
    t.index ["assigned_editor_id"], name: "index_appointments_on_assigned_editor_id"
    t.index ["assigned_photographer_id"], name: "index_appointments_on_assigned_photographer_id"
    t.index ["customer_id", "status"], name: "index_appointments_on_customer_id_and_status"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["editing_completed_at"], name: "index_appointments_on_editing_completed_at"
    t.index ["payment_reference"], name: "idx_appointments_payment_reference", unique: true, where: "(payment_reference IS NOT NULL)"
    t.index ["payment_status", "scheduled_at"], name: "idx_appointments_payment_scheduled"
    t.index ["service_package_id"], name: "index_appointments_on_service_package_id"
    t.index ["service_tier_id"], name: "index_appointments_on_service_tier_id"
    t.index ["shoot_completed_at"], name: "index_appointments_on_shoot_completed_at"
    t.index ["studio_id"], name: "index_appointments_on_studio_id"
    t.index ["studio_location_id"], name: "index_appointments_on_studio_location_id"
    t.index ["tenant_id", "booking_source"], name: "idx_appointments_tenant_booking_source"
    t.index ["tenant_id", "payment_status"], name: "idx_appointments_tenant_payment_status"
    t.index ["tenant_id", "scheduled_at"], name: "index_appointments_on_tenant_id_and_scheduled_at"
    t.index ["tenant_id", "status", "payment_status"], name: "idx_appointments_tenant_status_payment"
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

  create_table "sale_items", force: :cascade do |t|
    t.bigint "sale_id", null: false
    t.bigint "tenant_id", null: false
    t.string "item_type", null: false
    t.string "name", null: false
    t.text "description"
    t.string "sku"
    t.integer "quantity", default: 1, null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "total_price", precision: 10, scale: 2, null: false
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0"
    t.integer "duration_minutes"
    t.bigint "service_tier_id"
    t.string "product_category"
    t.json "product_specifications", default: {}
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sale_id", "item_type"], name: "index_sale_items_on_sale_id_and_item_type"
    t.index ["sale_id"], name: "index_sale_items_on_sale_id"
    t.index ["service_tier_id"], name: "index_sale_items_on_service_tier_id"
    t.index ["tenant_id", "product_category"], name: "index_sale_items_on_tenant_id_and_product_category"
    t.index ["tenant_id"], name: "index_sale_items_on_tenant_id"
  end

  create_table "sales", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "appointment_id"
    t.bigint "customer_id", null: false
    t.bigint "staff_member_id", null: false
    t.string "sale_number", null: false
    t.decimal "total_amount", precision: 10, scale: 2, null: false
    t.decimal "tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "paid_amount", precision: 10, scale: 2, default: "0.0"
    t.string "customer_name", null: false
    t.string "customer_email"
    t.string "customer_phone"
    t.integer "sale_type", default: 0, null: false
    t.integer "payment_status", default: 0, null: false
    t.integer "sale_status", default: 0, null: false
    t.string "payment_method"
    t.string "payment_reference"
    t.datetime "sale_date", null: false
    t.datetime "payment_received_at"
    t.text "notes"
    t.text "special_instructions"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id", "sale_type", "created_at"], name: "index_sales_on_appointment_id_and_sale_type_and_created_at"
    t.index ["appointment_id", "sale_type"], name: "index_sales_on_appointment_id_and_sale_type"
    t.index ["appointment_id"], name: "index_sales_on_appointment_id"
    t.index ["customer_email", "customer_phone"], name: "index_sales_on_customer_email_and_customer_phone"
    t.index ["customer_id"], name: "index_sales_on_customer_id"
    t.index ["sale_number"], name: "index_sales_on_sale_number", unique: true
    t.index ["staff_member_id"], name: "index_sales_on_staff_member_id"
    t.index ["tenant_id", "customer_id"], name: "index_sales_on_tenant_id_and_customer_id"
    t.index ["tenant_id", "payment_status"], name: "index_sales_on_tenant_id_and_payment_status"
    t.index ["tenant_id", "sale_date"], name: "index_sales_on_tenant_id_and_sale_date"
    t.index ["tenant_id", "sale_status"], name: "index_sales_on_tenant_id_and_sale_status"
    t.index ["tenant_id", "staff_member_id"], name: "index_sales_on_tenant_id_and_staff_member_id"
    t.index ["tenant_id"], name: "index_sales_on_tenant_id"
  end

  create_table "service_package_studio_locations", force: :cascade do |t|
    t.bigint "service_package_id", null: false
    t.bigint "studio_location_id", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_package_id", "studio_location_id"], name: "index_package_locations_on_package_and_location", unique: true
    t.index ["service_package_id"], name: "index_service_package_studio_locations_on_service_package_id"
    t.index ["studio_location_id"], name: "index_service_package_studio_locations_on_studio_location_id"
  end

  create_table "service_packages", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "category"
    t.boolean "active", default: true
    t.integer "sort_order", default: 0
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "active", "sort_order"], name: "index_service_packages_on_tenant_id_and_active_and_sort_order"
    t.index ["tenant_id", "category"], name: "index_service_packages_on_tenant_id_and_category"
    t.index ["tenant_id", "slug"], name: "index_service_packages_on_tenant_id_and_slug", unique: true
    t.index ["tenant_id"], name: "index_service_packages_on_tenant_id"
  end

  create_table "service_tiers", force: :cascade do |t|
    t.bigint "service_package_id", null: false
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "duration_minutes", null: false
    t.boolean "active", default: true
    t.integer "sort_order", default: 0
    t.json "features", default: []
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_package_id", "active", "sort_order"], name: "idx_on_service_package_id_active_sort_order_7cf2a40263"
    t.index ["service_package_id"], name: "index_service_tiers_on_service_package_id"
  end

  create_table "staff_members", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "user_id"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email"
    t.string "phone"
    t.string "role", null: false
    t.boolean "active", default: true
    t.boolean "has_login", default: false
    t.decimal "hourly_rate", precision: 8, scale: 2
    t.date "hire_date"
    t.text "notes"
    t.json "skills", default: []
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "role", "active"], name: "index_staff_members_on_tenant_id_and_role_and_active"
    t.index ["tenant_id", "user_id"], name: "index_staff_members_on_tenant_id_and_user_id", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["tenant_id"], name: "index_staff_members_on_tenant_id"
    t.index ["user_id"], name: "index_staff_members_on_user_id"
  end

  create_table "studio_locations", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.text "description"
    t.boolean "active", default: true
    t.integer "sort_order", default: 0
    t.integer "default_slot_duration", default: 60
    t.json "operating_hours", default: {}
    t.json "booking_settings", default: {}
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
    t.index ["tenant_id", "active", "sort_order"], name: "index_studio_locations_on_tenant_id_and_active_and_sort_order"
    t.index ["tenant_id"], name: "index_studio_locations_on_tenant_id"
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
  add_foreign_key "appointments", "service_packages"
  add_foreign_key "appointments", "service_tiers"
  add_foreign_key "appointments", "staff_members", column: "assigned_editor_id"
  add_foreign_key "appointments", "staff_members", column: "assigned_photographer_id"
  add_foreign_key "appointments", "studio_locations"
  add_foreign_key "appointments", "tenants"
  add_foreign_key "appointments", "users"
  add_foreign_key "brandings", "tenants"
  add_foreign_key "customers", "tenants"
  add_foreign_key "sale_items", "sales"
  add_foreign_key "sale_items", "service_tiers"
  add_foreign_key "sale_items", "tenants"
  add_foreign_key "sales", "appointments"
  add_foreign_key "sales", "customers"
  add_foreign_key "sales", "staff_members"
  add_foreign_key "sales", "tenants"
  add_foreign_key "service_package_studio_locations", "service_packages"
  add_foreign_key "service_package_studio_locations", "studio_locations"
  add_foreign_key "service_packages", "tenants"
  add_foreign_key "service_tiers", "service_packages"
  add_foreign_key "staff_members", "tenants"
  add_foreign_key "staff_members", "users"
  add_foreign_key "studio_locations", "tenants"
  add_foreign_key "studios", "tenants"
  add_foreign_key "tenant_users", "tenants"
  add_foreign_key "tenant_users", "users"
end
