class CreateExpenses < ActiveRecord::Migration[7.1]
  def change
    # Create expense categories table
    create_table :expense_categories do |t|
      t.references :tenant, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.string :color, default: '#3b82f6' # Default blue color
      t.boolean :active, default: true, null: false
      t.integer :sort_order, default: 0
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :expense_categories, [:tenant_id, :name], unique: true
    add_index :expense_categories, [:tenant_id, :active, :sort_order]

    # Create expenses table
    create_table :expenses do |t|
      t.references :tenant, null: false, foreign_key: true, index: true
      t.references :studio_location, null: false, foreign_key: true, index: true
      t.references :expense_category, null: false, foreign_key: true, index: true
      t.references :staff_member, null: true, foreign_key: true, index: true # Who recorded the expense

      # Basic expense information
      t.string :title, null: false
      t.text :description
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: 'USD', null: false
      t.date :expense_date, null: false

      # Vendor/Supplier information
      t.string :vendor_name
      t.string :vendor_contact
      t.string :invoice_number
      t.string :receipt_number

      # Payment information
      t.integer :payment_method, default: 0, null: false # enum
      t.string :payment_reference # Check number, transaction ID, etc.
      t.date :payment_date
      t.integer :payment_status, default: 0, null: false # enum

      # Categorization and tracking
      t.boolean :recurring, default: false, null: false
      t.string :recurring_frequency # monthly, quarterly, yearly
      t.date :next_due_date
      t.boolean :tax_deductible, default: true, null: false
      t.text :notes

      # Approval workflow
      t.integer :approval_status, default: 0, null: false # enum
      t.references :approved_by, null: true, foreign_key: { to_table: :staff_members }
      t.datetime :approved_at
      t.text :approval_notes

      # Metadata and tracking
      t.json :metadata, default: {}
      t.json :tags, default: []

      t.timestamps
    end

    # Add indexes for better performance
    add_index :expenses, [:tenant_id, :studio_location_id]
    add_index :expenses, [:tenant_id, :expense_category_id]
    add_index :expenses, [:tenant_id, :expense_date]
    add_index :expenses, [:tenant_id, :payment_status]
    add_index :expenses, [:tenant_id, :approval_status]
    add_index :expenses, [:studio_location_id, :expense_date]
    add_index :expenses, [:expense_category_id, :expense_date]
    add_index :expenses, [:recurring, :next_due_date], where: "recurring = true"

    # Create expense attachments table for receipts/invoices
    create_table :expense_attachments do |t|
      t.references :expense, null: false, foreign_key: true, index: true
      t.string :attachment_type, null: false # receipt, invoice, contract, etc.
      t.string :filename, null: false
      t.string :content_type
      t.bigint :file_size
      t.text :description
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :expense_attachments, [:expense_id, :attachment_type]
  end
end
