class CreateTenantUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :tenant_users do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :role
      t.boolean :active
      t.string :invitation_token

      t.timestamps
    end
  end
end
