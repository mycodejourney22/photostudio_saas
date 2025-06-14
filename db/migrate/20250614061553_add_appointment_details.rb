# db/migrate/xxx_add_appointment_details.rb
class AddAppointmentDetails < ActiveRecord::Migration[7.1]
  def change
    # Check if columns already exist before adding them
    unless column_exists?(:appointments, :assigned_photographer_id)
      add_reference :appointments, :assigned_photographer, null: true, foreign_key: { to_table: :staff_members }
    end

    unless column_exists?(:appointments, :assigned_editor_id)
      add_reference :appointments, :assigned_editor, null: true, foreign_key: { to_table: :staff_members }
    end

    # Add production details columns (check if they exist first)
    unless column_exists?(:appointments, :shoot_completed_at)
      add_column :appointments, :shoot_completed_at, :datetime
    end

    unless column_exists?(:appointments, :editing_completed_at)
      add_column :appointments, :editing_completed_at, :datetime
    end

    unless column_exists?(:appointments, :delivery_date)
      add_column :appointments, :delivery_date, :date
    end

    unless column_exists?(:appointments, :equipment_used)
      add_column :appointments, :equipment_used, :text
    end

    unless column_exists?(:appointments, :production_notes)
      add_column :appointments, :production_notes, :text
    end

    # Add indexes for performance (check if they exist first)
    unless index_exists?(:appointments, :assigned_photographer_id)
      add_index :appointments, :assigned_photographer_id
    end

    unless index_exists?(:appointments, :assigned_editor_id)
      add_index :appointments, :assigned_editor_id
    end

    unless index_exists?(:appointments, :shoot_completed_at)
      add_index :appointments, :shoot_completed_at
    end

    unless index_exists?(:appointments, :editing_completed_at)
      add_index :appointments, :editing_completed_at
    end
  end
end
