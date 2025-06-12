# db/migrate/*_create_appointments.rb
class CreateAppointments < ActiveRecord::Migration[7.1]
  def change
    create_table :appointments do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.bigint :studio_id, null: true  # Don't add foreign key yet since studios table doesn't exist

      t.datetime :scheduled_at, null: false
      t.integer :duration_minutes, null: false, default: 60
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :session_type, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.text :notes
      t.text :special_requirements
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :appointments, [:tenant_id, :scheduled_at]
    add_index :appointments, [:customer_id, :status]
    add_index :appointments, [:user_id, :scheduled_at]
    add_index :appointments, :studio_id
  end
end
