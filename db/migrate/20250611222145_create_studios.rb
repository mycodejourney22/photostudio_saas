class CreateStudios < ActiveRecord::Migration[7.1]
  def change
    create_table :studios do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :location
      t.text :description
      t.integer :capacity, default: 1
      t.text :equipment
      t.boolean :active, default: true, null: false
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :studios, [:tenant_id, :active]
  end
end
