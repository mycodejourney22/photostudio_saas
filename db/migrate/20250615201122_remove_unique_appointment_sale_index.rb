# db/migrate/[timestamp]_remove_unique_appointment_sale_index.rb
class RemoveUniqueAppointmentSaleIndex < ActiveRecord::Migration[7.1]
  def up
    # Remove the unique index on appointment_id since we now allow multiple sales per appointment
    if index_exists?(:sales, :appointment_id, unique: true)
      remove_index :sales, name: "index_sales_on_appointment_id"
    end

    # Add a regular (non-unique) index for performance
    unless index_exists?(:sales, :appointment_id)
      add_index :sales, :appointment_id
    end

    # Add composite index for appointment + sale_type for better query performance
    unless index_exists?(:sales, [:appointment_id, :sale_type])
      add_index :sales, [:appointment_id, :sale_type]
    end

    # Add index for finding additional sales
    unless index_exists?(:sales, [:appointment_id, :sale_type, :created_at])
      add_index :sales, [:appointment_id, :sale_type, :created_at]
    end
  end

  def down
    # Remove the indexes we added
    remove_index :sales, :appointment_id if index_exists?(:sales, :appointment_id)
    remove_index :sales, [:appointment_id, :sale_type] if index_exists?(:sales, [:appointment_id, :sale_type])
    remove_index :sales, [:appointment_id, :sale_type, :created_at] if index_exists?(:sales, [:appointment_id, :sale_type, :created_at])

    # Add back the unique index (this will fail if there are multiple sales per appointment)
    add_index :sales, [:appointment_id], unique: true, where: "appointment_id IS NOT NULL"
  end
end
