# db/migrate/xxx_create_service_package_studio_locations.rb
class CreateServicePackageStudioLocations < ActiveRecord::Migration[7.1]
  def change
    # Junction table for which packages are available at which locations
    create_table :service_package_studio_locations do |t|
      t.references :service_package, null: false, foreign_key: true
      t.references :studio_location, null: false, foreign_key: true
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :service_package_studio_locations,
              [:service_package_id, :studio_location_id],
              unique: true,
              name: 'index_package_locations_on_package_and_location'
  end
end
