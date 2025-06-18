class AddStudioLocationToSales < ActiveRecord::Migration[7.0]
  def change
    add_reference :sales, :studio_location, null: true, foreign_key: true
    add_index :sales, [:tenant_id, :studio_location_id]
    add_index :sales, [:studio_location_id, :sale_date]
  end
end
