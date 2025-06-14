# db/migrate/xxx_create_sale_items.rb
class CreateSaleItems < ActiveRecord::Migration[7.1]
  def change
    # Check if table already exists
    unless table_exists?(:sale_items)
      create_table :sale_items do |t|
        t.references :sale, null: false, foreign_key: true
        t.references :tenant, null: false, foreign_key: true

        # Item details
        t.string :item_type, null: false # service, product, addon, discount
        t.string :name, null: false # "Portrait Session", "Passport Photos", "Extra Prints"
        t.text :description
        t.string :sku # For products

        # Pricing
        t.integer :quantity, default: 1, null: false
        t.decimal :unit_price, precision: 10, scale: 2, null: false
        t.decimal :total_price, precision: 10, scale: 2, null: false
        t.decimal :discount_amount, precision: 10, scale: 2, default: 0

        # Service-specific fields
        t.integer :duration_minutes # For services
        t.references :service_tier, null: true, foreign_key: true # If linked to a service package

        # Product-specific fields
        t.string :product_category # prints, frames, albums, digital, etc.
        t.json :product_specifications, default: {} # size, material, etc.

        # Additional metadata
        t.json :metadata, default: {}

        t.timestamps
      end
    end

    # Indexes (check if they exist first)
    unless index_exists?(:sale_items, [:sale_id, :item_type])
      add_index :sale_items, [:sale_id, :item_type]
    end

    unless index_exists?(:sale_items, [:tenant_id, :product_category])
      add_index :sale_items, [:tenant_id, :product_category]
    end

    unless index_exists?(:sale_items, :service_tier_id)
      add_index :sale_items, [:service_tier_id], where: "service_tier_id IS NOT NULL"
    end
  end
end
