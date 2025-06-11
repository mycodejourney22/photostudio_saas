class CreateTenantUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :tenant_users do |t|

      t.timestamps
    end
  end
end
