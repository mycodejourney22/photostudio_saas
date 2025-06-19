# db/migrate/xxx_add_smtp_settings_to_tenants.rb
class AddSmtpSettingsToTenants < ActiveRecord::Migration[7.1]
  def change
    add_column :tenants, :smtp_settings, :json, default: {}
    add_column :tenants, :email_settings, :json, default: {}
    add_column :tenants, :mailer_enabled, :boolean, default: false

    add_index :tenants, :mailer_enabled
  end
end
