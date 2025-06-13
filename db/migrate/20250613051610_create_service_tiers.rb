# db/migrate/xxx_create_service_tiers.rb
class CreateServiceTiers < ActiveRecord::Migration[7.1]
  def change
    create_table :service_tiers do |t|
      t.references :service_package, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :duration_minutes, null: false
      t.boolean :active, default: true
      t.integer :sort_order, default: 0
      t.json :features, default: [] # ["1 outfit", "10 edited photos", "online gallery"]
      t.json :metadata, default: {}
      t.timestamps
    end

    add_index :service_tiers, [:service_package_id, :active, :sort_order]
  end
end
