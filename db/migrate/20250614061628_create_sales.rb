# db/migrate/xxx_create_sales.rb
class CreateSales < ActiveRecord::Migration[7.1]
  def change
    # Check if table already exists
    unless table_exists?(:sales)
      create_table :sales do |t|
        t.references :tenant, null: false, foreign_key: true
        t.references :appointment, null: true, foreign_key: true # Optional - for appointment-based sales
        t.references :customer, null: false, foreign_key: true
        t.references :staff_member, null: false, foreign_key: true # Customer service staff

        # Sale details
        t.string :sale_number, null: false # Auto-generated unique identifier
        t.decimal :total_amount, precision: 10, scale: 2, null: false
        t.decimal :tax_amount, precision: 10, scale: 2, default: 0
        t.decimal :discount_amount, precision: 10, scale: 2, default: 0
        t.decimal :paid_amount, precision: 10, scale: 2, default: 0

        # Customer details (for walk-in customers or updates)
        t.string :customer_name, null: false
        t.string :customer_email
        t.string :customer_phone

        # Sale metadata
        t.integer :sale_type, default: 0, null: false # appointment, walk_in, online, phone
        t.integer :payment_status, default: 0, null: false # unpaid, partial, paid, refunded
        t.integer :sale_status, default: 0, null: false # pending, confirmed, completed, cancelled
        t.string :payment_method # cash, card, bank_transfer, etc.
        t.string :payment_reference
        t.datetime :sale_date, null: false
        t.datetime :payment_received_at

        # Additional info
        t.text :notes
        t.text :special_instructions
        t.json :metadata, default: {}

        t.timestamps
      end
    end

    # Indexes for performance and business logic (check if they exist first)
    unless index_exists?(:sales, [:tenant_id, :sale_date])
      add_index :sales, [:tenant_id, :sale_date]
    end

    unless index_exists?(:sales, [:tenant_id, :customer_id])
      add_index :sales, [:tenant_id, :customer_id]
    end

    unless index_exists?(:sales, [:tenant_id, :staff_member_id])
      add_index :sales, [:tenant_id, :staff_member_id]
    end

    unless index_exists?(:sales, [:tenant_id, :sale_status])
      add_index :sales, [:tenant_id, :sale_status]
    end

    unless index_exists?(:sales, [:tenant_id, :payment_status])
      add_index :sales, [:tenant_id, :payment_status]
    end

    unless index_exists?(:sales, :sale_number)
      add_index :sales, [:sale_number], unique: true
    end

    unless index_exists?(:sales, :appointment_id)
      add_index :sales, [:appointment_id], unique: true, where: "appointment_id IS NOT NULL"
    end

    unless index_exists?(:sales, [:customer_email, :customer_phone])
      add_index :sales, [:customer_email, :customer_phone]
    end
  end
end
