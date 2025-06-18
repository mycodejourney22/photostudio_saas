class AddStudioLocationToStaffMembers < ActiveRecord::Migration[7.0]
  def change
    add_reference :staff_members, :studio_location, null: true, foreign_key: true
    add_index :staff_members, [:tenant_id, :studio_location_id]
  end
end
