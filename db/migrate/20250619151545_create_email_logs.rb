# db/migrate/xxx_create_email_logs.rb
class CreateEmailLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :email_logs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true
      t.string :email_type, null: false # confirmation, reminder, feedback_request, status_update
      t.string :recipient_email, null: false
      t.datetime :sent_at
      t.datetime :failed_at
      t.text :error_message
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :email_logs, [:tenant_id, :email_type]
    add_index :email_logs, [:appointment_id, :email_type]
    add_index :email_logs, :sent_at
    add_index :email_logs, :failed_at
  end
end
