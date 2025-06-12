# db/migrate/*_create_brandings.rb
class CreateBrandings < ActiveRecord::Migration[7.1]
  def change
    create_table :brandings do |t|
      t.references :tenant, null: false, foreign_key: true, index: { unique: true }
      t.string :primary_color, default: '#667eea'
      t.string :secondary_color
      t.string :font_family, default: 'Inter'
      t.string :custom_domain
      t.text :welcome_message
      t.json :settings, default: {}

      t.timestamps
    end

    # Only add the custom domain index since tenant_id index is already created above
    add_index :brandings, :custom_domain, unique: true
  end
end
