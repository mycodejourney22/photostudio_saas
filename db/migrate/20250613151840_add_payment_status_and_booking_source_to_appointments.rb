class AddPaymentStatusAndBookingSourceToAppointments < ActiveRecord::Migration[7.1]
  def change
    # Core payment and booking fields
    add_column :appointments, :payment_status, :integer, default: 0, null: false
    add_column :appointments, :booking_source, :integer, default: 0, null: false

    # Payment tracking
    add_column :appointments, :paid_amount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :appointments, :deposit_amount, :decimal, precision: 10, scale: 2

    # Payment system integration
    add_column :appointments, :payment_reference, :string
    add_column :appointments, :payment_method, :string
    add_column :appointments, :payment_received_at, :datetime

    # # JSON metadata for flexible data storage
    # add_column :appointments, :metadata, :json, default: {}

    # Performance indexes
    add_index :appointments, [:tenant_id, :payment_status], name: 'idx_appointments_tenant_payment_status'
    add_index :appointments, [:tenant_id, :booking_source], name: 'idx_appointments_tenant_booking_source'
    add_index :appointments, [:payment_status, :scheduled_at], name: 'idx_appointments_payment_scheduled'
    add_index :appointments, [:payment_reference], name: 'idx_appointments_payment_reference',
              unique: true, where: 'payment_reference IS NOT NULL'
    add_index :appointments, [:tenant_id, :status, :payment_status], name: 'idx_appointments_tenant_status_payment'
  end
end
