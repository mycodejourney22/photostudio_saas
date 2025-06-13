# db/migrate/xxx_create_staff_members.rb
class CreateStaffMembers < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_members do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true # nullable for non-login staff

      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.string :role, null: false # customer_service, photographer, editor, etc.

      t.boolean :active, default: true
      t.boolean :has_login, default: false # whether they can login to the system

      t.decimal :hourly_rate, precision: 8, scale: 2 # for tracking costs/payments
      t.date :hire_date
      t.text :notes
      t.json :skills, default: [] # ["portrait", "wedding", "newborn"] for photographers
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :staff_members, [:tenant_id, :role, :active]
    add_index :staff_members, [:tenant_id, :user_id], unique: true, where: "user_id IS NOT NULL"
  end
end
