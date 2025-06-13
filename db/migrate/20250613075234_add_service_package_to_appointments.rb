class AddServicePackageToAppointments < ActiveRecord::Migration[7.1]
  def change
    add_reference :appointments, :service_package, null: false, foreign_key: true
  end
end
