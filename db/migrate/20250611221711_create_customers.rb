class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone
      t.text :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :country
      t.date :date_of_birth
      t.text :notes
      t.text :preferences
      t.boolean :active
      t.json :metadata

      t.timestamps
    end
  end
end
