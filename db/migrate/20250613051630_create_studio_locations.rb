# db/migrate/xxx_create_studio_locations.rb
class CreateStudioLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :studio_locations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.text :address
      t.string :city
      t.string :state
      t.string :postal_code
      t.text :description
      t.boolean :active, default: true
      t.integer :sort_order, default: 0

      # Booking configuration (metadata-driven)
      t.integer :default_slot_duration, default: 60 # minutes
      t.json :operating_hours, default: {} # {"monday": {"start": "09:00", "end": "17:00"}, ...}
      t.json :booking_settings, default: {} # buffer_time, advance_booking_days, etc.
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :studio_locations, [:tenant_id, :active, :sort_order]
  end
end
