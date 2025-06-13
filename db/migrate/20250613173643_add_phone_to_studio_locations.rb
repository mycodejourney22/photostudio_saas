class AddPhoneToStudioLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :studio_locations, :phone, :string
  end
end
