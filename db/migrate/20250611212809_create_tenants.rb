class CreateTenants < ActiveRecord::Migration[7.1]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :email, null: false
      t.integer :plan_type, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.string :verification_token
      t.datetime :verified_at
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :tenants, :subdomain, unique: true
    add_index :tenants, :email, unique: true
    add_index :tenants, :verification_token, unique: true
  end
end
