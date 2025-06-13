# db/migrate/xxx_create_service_packages.rb
class CreateServicePackages < ActiveRecord::Migration[7.1]
  def change
    create_table :service_packages do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :category # 'portrait', 'wedding', 'family', 'commercial', etc.
      t.boolean :active, default: true
      t.integer :sort_order, default: 0
      t.json :metadata, default: {}
      t.timestamps
    end

    add_index :service_packages, [:tenant_id, :slug], unique: true
    add_index :service_packages, [:tenant_id, :active, :sort_order]
    add_index :service_packages, [:tenant_id, :category]
  end
end
