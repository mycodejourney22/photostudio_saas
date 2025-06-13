class AddServiceTierToAppointments < ActiveRecord::Migration[7.1]
  def change
    add_reference :appointments, :service_tier, null: false, foreign_key: true
  end
end
